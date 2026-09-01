// Background Service Worker for LinkCrypta Extension
// Real Firebase Auth + Firestore Sync + E2EE

importScripts('../shared/crypto.js');

const LINKCRYPTA_CONFIG = {
  FIREBASE_API_KEY: 'AIzaSyBTNuUpu41PKYBsbPTUGGKzHVhPNw9-Pmc',
  FIREBASE_PROJECT_ID: 'linkcrypta-61258',
  FIRESTORE_BASE: 'https://firestore.googleapis.com/v1/projects/linkcrypta-61258/databases/(default)/documents',
  AUTH_BASE: 'https://identitytoolkit.googleapis.com/v1',
  TOKEN_URL: 'https://securetoken.googleapis.com/v1/token',
  EXTENSION: {
    AUTO_LOCK_TIMEOUT: 15 * 60 * 1000,
    SYNC_INTERVAL: 60 * 1000
  },
  AUTOFILL: { CONFIDENCE_THRESHOLD: 0.7, MAX_SUGGESTIONS: 5 },
  STORAGE_KEYS: {
    SYNC_TIMESTAMP: 'lastSyncTime',
    USER_DATA: 'userData',
    AUTH_STATE: 'authState'
  }
};

class BackgroundService {
  constructor() {
    this.isInitialized = false;
    this.initPromise = null;
    this.autoLockTimer = null;
    this.syncInterval = null;
    this.currentUser = null;
    this.isAuthenticated = false;
    this.idToken = null;
    this.refreshToken = null;
    this.tokenExpiry = 0;
    
    // E2EE
    this.crypto = new CryptoUtils();
    this.sessionKey = null; // Ephemeral key stored in memory
  }

  async initialize() {
    if (this.isInitialized) return;
    if (this.initPromise) return this.initPromise;
    this.initPromise = this._doInitialize();
    return this.initPromise;
  }

  async _doInitialize() {
    try {
      console.log('🔧 Initializing background service...');
      await this.loadAuthState();
      this.setupContextMenus();
      this.setupMessageListeners();
      this.setupAutoLock();
      this.setupPeriodicSync();
      this.setupCommandListeners();
      this.isInitialized = true;
      console.log('✅ Background service initialized');
    } catch (error) {
      console.error('❌ Init failed:', error);
    }
  }

  // ─── E2EE VAULT UNLOCK ──────────────────────────────────────────
  
  async isVaultUnlocked() {
    return this.sessionKey !== null;
  }
  
  async unlockVault(masterPassword) {
    if (!this.isAuthenticated || !this.currentUser) {
      throw new Error('You must sign in before unlocking the vault.');
    }
    
    const token = await this.ensureValidToken();
    const uid = this.currentUser.uid;
    const url = `${LINKCRYPTA_CONFIG.FIRESTORE_BASE}/users/${uid}/settings/crypto`;
    
    try {
      const response = await fetch(url, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (!response.ok) {
        throw new Error('Vault not initialized. Please set up Master Password in the mobile app first.');
      }
      
      const data = await response.json();
      const base64Salt = data.fields?.salt?.stringValue;
      const keyCheckPayload = data.fields?.keyCheck?.mapValue?.fields;
      
      if (!base64Salt) {
        throw new Error('Corrupt vault settings. No salt found.');
      }
      
      const saltBytes = new Uint8Array(this.crypto._base64ToArrayBuffer(base64Salt));
      const key = await this.crypto.deriveKey(masterPassword, saltBytes);
      
      // Verify key if keyCheck exists
      if (keyCheckPayload) {
        const payload = {
          v: parseInt(keyCheckPayload.v?.integerValue || '1'),
          n: keyCheckPayload.n?.stringValue || '',
          c: keyCheckPayload.c?.stringValue || ''
        };
        try {
          const decryptedCheck = await this.crypto.decryptRecord(payload, key);
          if (decryptedCheck.check !== 'VALID') throw new Error('Invalid Check Payload');
        } catch(e) {
          throw new Error('Incorrect Master Password. (Detail: ' + e.message + ')');
        }
      }
      
      this.sessionKey = key;
      this.resetAutoLock();
      
      // Sync immediately on unlock
      this.performSync().catch(e => console.error('Post-unlock sync failed:', e));
      
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
  
  lockVault() {
    this.sessionKey = null;
    chrome.storage.local.remove(['passwords']);
    console.log('🔒 Vault locked and local cache cleared.');
    return { success: true };
  }

  // ─── FIREBASE AUTH ───────────────────────────────────────────────

  async authenticateUser() {
    try {
      console.log('🔐 Starting authentication...');
      let accessToken;
      try {
        accessToken = await this.getGoogleToken();
      } catch (tokenError) {
        accessToken = await this.getGoogleTokenViaWebFlow();
      }
      if (!accessToken) throw new Error('No access token received');

      const firebaseResponse = await fetch(
        `${LINKCRYPTA_CONFIG.AUTH_BASE}/accounts:signInWithIdp?key=${LINKCRYPTA_CONFIG.FIREBASE_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            postBody: `access_token=${accessToken}&providerId=google.com`,
            requestUri: 'https://linkcrypta-61258.firebaseapp.com/__/auth/handler',
            returnIdpCredential: true,
            returnSecureToken: true
          })
        }
      );

      if (!firebaseResponse.ok) {
        const err = await firebaseResponse.json();
        throw new Error(err.error?.message || 'Firebase auth failed');
      }

      const firebaseData = await firebaseResponse.json();
      this.idToken = firebaseData.idToken;
      this.refreshToken = firebaseData.refreshToken;
      this.tokenExpiry = Date.now() + (parseInt(firebaseData.expiresIn) * 1000);

      this.currentUser = {
        uid: firebaseData.localId,
        email: firebaseData.email,
        displayName: firebaseData.displayName || firebaseData.email.split('@')[0],
        photoURL: firebaseData.photoUrl || ''
      };
      this.isAuthenticated = true;

      await chrome.storage.local.set({
        isAuthenticated: true,
        currentUser: this.currentUser,
        idToken: this.idToken,
        refreshToken: this.refreshToken,
        tokenExpiry: this.tokenExpiry
      });

      return { success: true, user: this.currentUser };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async getGoogleToken() {
    return new Promise((resolve, reject) => {
      chrome.identity.getAuthToken({ interactive: true }, (token) => {
        if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
        else if (!token) reject(new Error('No token returned'));
        else resolve(token);
      });
    });
  }

  async getGoogleTokenViaWebFlow() {
    const clientId = await this.getOAuthClientId();
    const redirectUrl = chrome.identity.getRedirectURL();
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&response_type=token&redirect_uri=${encodeURIComponent(redirectUrl)}&scope=email%20profile%20openid`;

    const responseUrl = await new Promise((resolve, reject) => {
      chrome.identity.launchWebAuthFlow({ url: authUrl, interactive: true }, (url) => {
        if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
        else resolve(url);
      });
    });
    const params = new URLSearchParams(responseUrl.replace(/.*[#?]/, ''));
    const token = params.get('access_token');
    if (!token) throw new Error('No access token in redirect URL');
    return token;
  }

  async getOAuthClientId() {
    try {
      const manifest = chrome.runtime.getManifest();
      if (manifest.oauth2?.client_id) return manifest.oauth2.client_id;
    } catch (e) { }
    return '795878816417-a5jab510h6c0nolcpcsvumt3nljao4bb.apps.googleusercontent.com';
  }

  async ensureValidToken() {
    if (!this.idToken || Date.now() >= this.tokenExpiry - 60000) {
      await this.refreshFirebaseToken();
    }
    return this.idToken;
  }

  async refreshFirebaseToken() {
    if (!this.refreshToken) throw new Error('No refresh token');
    try {
      const response = await fetch(
        `${LINKCRYPTA_CONFIG.TOKEN_URL}?key=${LINKCRYPTA_CONFIG.FIREBASE_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: `grant_type=refresh_token&refresh_token=${this.refreshToken}`
        }
      );
      if (!response.ok) throw new Error('Token refresh failed');
      const data = await response.json();
      this.idToken = data.id_token;
      this.refreshToken = data.refresh_token;
      this.tokenExpiry = Date.now() + (parseInt(data.expires_in) * 1000);

      await chrome.storage.local.set({
        idToken: this.idToken,
        refreshToken: this.refreshToken,
        tokenExpiry: this.tokenExpiry
      });
    } catch (error) {
      this.isAuthenticated = false;
      throw error;
    }
  }

  async signOutUser() {
    try {
      try {
        const result = await chrome.storage.local.get(['idToken']);
        if (result.idToken) await fetch(`https://accounts.google.com/o/oauth2/revoke?token=${result.idToken}`).catch(() => {});
      } catch (e) {}

      this.currentUser = null;
      this.isAuthenticated = false;
      this.idToken = null;
      this.refreshToken = null;
      this.tokenExpiry = 0;
      this.sessionKey = null;

      await chrome.storage.local.clear();
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async loadAuthState() {
    try {
      const result = await chrome.storage.local.get([
        'isAuthenticated', 'currentUser', 'idToken', 'refreshToken', 'tokenExpiry'
      ]);
      this.isAuthenticated = result.isAuthenticated || false;
      this.currentUser = result.currentUser || null;
      this.idToken = result.idToken || null;
      this.refreshToken = result.refreshToken || null;
      this.tokenExpiry = result.tokenExpiry || 0;
    } catch (error) {
      this.isAuthenticated = false;
    }
  }

  // ─── FIRESTORE CRUD (E2EE) ──────────────────────────────────────

  async getStoredPasswords() {
    if (!this.isAuthenticated || !this.currentUser) return [];
    if (!this.sessionKey) {
      throw new Error('Vault is locked. Master Password required.');
    }

    try {
      const token = await this.ensureValidToken();
      const uid = this.currentUser.uid;
      const url = `${LINKCRYPTA_CONFIG.FIRESTORE_BASE}/users/${uid}/passwords`;

      const response = await fetch(url, { headers: { 'Authorization': `Bearer ${token}` } });
      if (!response.ok) {
        const local = await chrome.storage.local.get(['passwords']);
        return local.passwords || [];
      }

      const data = await response.json();
      const passwords = [];
      
      for (const doc of (data.documents || [])) {
        try {
          const f = doc.fields || {};
          if (!f.c) continue; // Skip non-encrypted legacy records if any
          
          const payload = {
            v: parseInt(f.v?.integerValue || '1'),
            n: f.n?.stringValue || '',
            c: f.c?.stringValue || ''
          };
          
          const passwordData = await this.crypto.decryptRecord(payload, this.sessionKey);
          
          passwords.push({
            id: doc.id,
            name: passwordData.name || passwordData.siteName || 'Unknown Site',
            siteName: passwordData.siteName || passwordData.name || 'Unknown Site',
            ...passwordData
          });
        } catch (e) {
          console.warn('Failed to decrypt password record:', e);
        }
      }

      await chrome.storage.local.set({ passwords });
      return passwords;
    } catch (error) {
      const local = await chrome.storage.local.get(['passwords']);
      return local.passwords || [];
    }
  }

  async savePassword(passwordData) {
    if (!this.sessionKey) return { success: false, error: 'Vault is locked' };
    
    try {
      const newPassword = {
        id: this.generateId(),
        siteName: passwordData.title || passwordData.siteName || passwordData.domain || 'Untitled',
        name: passwordData.title || passwordData.siteName || passwordData.domain || 'Untitled',
        username: passwordData.username,
        password: passwordData.password,
        url: passwordData.url || '',
        email: passwordData.email || '',
        notes: passwordData.notes || '',
        favicon: passwordData.favicon || '',
        domain: passwordData.domain || '',
        category: passwordData.category || 'General',
        isFavorite: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };

      const result = await chrome.storage.local.get(['passwords']);
      const passwords = result.passwords || [];
      passwords.push(newPassword);
      await chrome.storage.local.set({ passwords });

      if (this.isAuthenticated && this.currentUser) {
        await this.savePasswordToFirestore(newPassword);
      }

      chrome.runtime.sendMessage({ type: 'PASSWORD_SAVED', password: newPassword }).catch(() => {});
      return { success: true, message: 'Password saved successfully', password: newPassword };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  async savePasswordToFirestore(password) {
    if (!this.sessionKey) throw new Error('Vault is locked');
    
    const token = await this.ensureValidToken();
    const uid = this.currentUser.uid;
    const docId = password.id;
    const url = `${LINKCRYPTA_CONFIG.FIRESTORE_BASE}/users/${uid}/passwords/${docId}`;
    
    const encryptedPayload = await this.crypto.encryptRecord(password, this.sessionKey);

    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ 
        fields: {
          v: { integerValue: String(encryptedPayload.v) },
          n: { stringValue: encryptedPayload.n },
          c: { stringValue: encryptedPayload.c }
        }
      })
    });

    if (!response.ok) {
      throw new Error(`Firestore save failed`);
    }
    return true;
  }

  // ─── SYNC ────────────────────────────────────────────────────────

  async performSync() {
    if (!this.isAuthenticated || !this.currentUser) return { success: false, error: 'Not authenticated' };
    if (!this.sessionKey) return { success: false, error: 'Vault is locked' };

    try {
      const firestorePasswords = await this.getStoredPasswords();
      const localResult = await chrome.storage.local.get(['passwords']);
      const localPasswords = localResult.passwords || [];

      const firestoreIds = new Set(firestorePasswords.map(p => p.id));
      const localOnly = localPasswords.filter(p => !firestoreIds.has(p.id));

      for (const password of localOnly) {
        await this.savePasswordToFirestore(password).catch(e => console.error(e));
      }

      const mergedIds = new Set();
      const merged = [];
      for (const p of [...firestorePasswords, ...localOnly]) {
        if (!mergedIds.has(p.id)) {
          mergedIds.add(p.id);
          merged.push(p);
        }
      }
      
      await chrome.storage.local.set({
        passwords: merged,
        lastSyncTime: Date.now()
      });

      return { success: true, message: `Synced ${merged.length} passwords` };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }

  // ─── MESSAGE HANDLING ────────────────────────────────────────────

  setupMessageListeners() {
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
      this.handleMessage(request, sender, sendResponse);
      return true;
    });
  }

  async handleMessage(request, sender, sendResponse) {
    try {
      switch (request.type || request.action) {
        case 'authenticate':
          sendResponse(await this.authenticateUser());
          break;
        case 'checkVaultState':
          sendResponse({ isUnlocked: await this.isVaultUnlocked() });
          break;
        case 'unlockVault':
          sendResponse(await this.unlockVault(request.password));
          break;
        case 'lockVault':
          sendResponse(this.lockVault());
          break;
        case 'signOut':
          sendResponse(await this.signOutUser());
          break;
        case 'getPasswords':
          sendResponse({ success: true, passwords: await this.getStoredPasswords() });
          break;
        case 'SEARCH_PASSWORDS':
          sendResponse({ success: true, results: await this.getMatchingPasswords(request.url) });
          break;
        case 'addPassword':
          sendResponse(await this.savePassword(request.password));
          break;
        case 'syncData':
          sendResponse(await this.performSync());
          break;
        case 'CREDENTIALS_CAPTURED':
          if (request.showOnNextPage) {
            await chrome.storage.local.set({
              pendingCapture: {
                data: request.data,
                timestamp: Date.now()
              }
            });
          }
          sendResponse({ success: true });
          break;
        case 'logActivity':
          sendResponse({ success: true });
          break;
        default:
          sendResponse({ success: false, error: 'Unknown action' });
      }
    } catch (error) {
      sendResponse({ success: false, error: error.message });
    }
  }

  // ─── UTILS & BACKGROUND LOGIC ────────────────────────────────────

  generateId() {
    return 'xxxx-xxxx-xxxx'.replace(/[x]/g, () => (Math.random() * 16 | 0).toString(16));
  }

  resetAutoLock() {
    if (this.autoLockTimer) clearTimeout(this.autoLockTimer);
    this.autoLockTimer = setTimeout(() => {
      this.lockVault();
    }, LINKCRYPTA_CONFIG.EXTENSION.AUTO_LOCK_TIMEOUT);
  }

  setupAutoLock() {
    chrome.idle.setDetectionInterval(15 * 60);
    chrome.idle.onStateChanged.addListener((state) => {
      if (state === 'locked' || state === 'idle') {
        this.lockVault();
      }
    });
  }

  setupPeriodicSync() {
    setInterval(() => {
      if (this.isAuthenticated && this.sessionKey) {
        this.performSync();
      }
    }, LINKCRYPTA_CONFIG.EXTENSION.SYNC_INTERVAL);
  }

  setupContextMenus() {
    chrome.contextMenus.create({
      id: "saveToLinkCrypta",
      title: "Save to LinkCrypta",
      contexts: ["page", "selection"]
    }, () => chrome.runtime.lastError);
  }

  setupCommandListeners() {
    chrome.commands.onCommand.addListener((command) => {
      if (command === 'fill_password' && this.isAuthenticated && this.sessionKey) {
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
          if (tabs[0]) this.fillPasswordForTab(tabs[0]);
        });
      }
    });
  }

  async getMatchingPasswords(url) {
    if (!url || !this.sessionKey) return [];
    try {
      const hostname = new URL(url).hostname.replace('www.', '');
      const passwords = await this.getStoredPasswords();
      return passwords.filter(p => {
        if (p.url && p.url.includes(hostname)) return true;
        if (p.siteName && p.siteName.toLowerCase().includes(hostname.split('.')[0].toLowerCase())) return true;
        return false;
      });
    } catch (e) {
      return [];
    }
  }

  async fillPasswordForTab(tab) {
    try {
      const passwords = await this.getMatchingPasswords(tab.url);
      if (passwords.length === 0) return;
      if (passwords.length === 1) {
        chrome.tabs.sendMessage(tab.id, { action: 'fillPassword', password: passwords[0] }).catch(() => {});
      } else {
        chrome.tabs.sendMessage(tab.id, { action: 'showPasswordSelector', passwords }).catch(() => {});
      }
    } catch (e) {
      console.error(e);
    }
  }
}

const backgroundService = new BackgroundService();
backgroundService.initialize();
