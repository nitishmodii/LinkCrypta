// LinkCrypta Browser Extension - Popup Script
class PopupManager {
  constructor() {
    this.currentScreen = 'loading';
    this.isAuthenticated = false;
    this.currentUser = null;
    this.passwords = [];
    this.filteredPasswords = [];
    this.currentTab = null;
    this.searchQuery = '';
    this.touchStartY = 0;
    this.touchStartX = 0;
    this.isScrolling = false;
    this.autoCaptureEnabled = true;
    this.captureStats = { today: 0, total: 0 };
    
    // Initialize
    this.init();
  }

  async init() {
    try {
      // Setup event listeners
      this.setupEventListeners();
      
      // Setup touch handlers for mobile
      this.setupTouchHandlers();
      
      // Get current tab info
      await this.getCurrentTab();
      
      // Check authentication status
      await this.checkAuthStatus();
      
      // Load auto-capture status
      await this.loadAutoCaptureStatus();
      
      // Load data if authenticated
      if (this.isAuthenticated) {
        const vaultState = await chrome.runtime.sendMessage({ action: 'checkVaultState' });
        if (vaultState && vaultState.isUnlocked) {
          await this.loadPasswords();
          this.showScreen('main');
        } else {
          this.showScreen('lock');
        }
      } else {
        this.showScreen('auth');
      }
    } catch (error) {
      console.error('Popup initialization failed:', error);
      this.showScreen('auth');
    }
  }

  setupEventListeners() {
    // Screen navigation
    document.getElementById('sign-in-btn')?.addEventListener('click', () => this.handleSignIn());
    document.getElementById('sign-out-btn')?.addEventListener('click', () => this.handleSignOut());
    document.getElementById('lock-btn')?.addEventListener('click', () => this.handleLock());
    
    // Vault Unlock
    document.getElementById('unlock-vault-btn')?.addEventListener('click', () => this.handleVaultUnlock());
    document.getElementById('master-password-input')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') this.handleVaultUnlock();
    });
    
    // Search functionality
    const searchInput = document.getElementById('search-input');
    searchInput?.addEventListener('input', (e) => this.handleSearch(e.target.value));
    searchInput?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        this.handleSearchEnter();
      }
    });
    
    // Quick actions
    document.getElementById('generate-password-btn')?.addEventListener('click', () => this.showPasswordGenerator());
    document.getElementById('open-app-btn')?.addEventListener('click', () => this.openMainApp());
    document.getElementById('add-btn')?.addEventListener('click', () => this.showAddPasswordModal());
    document.getElementById('empty-add-btn')?.addEventListener('click', () => this.showAddPasswordModal());
    
    // Settings and sync
    document.getElementById('settings-btn')?.addEventListener('click', () => this.openSettings());
    document.getElementById('sync-btn')?.addEventListener('click', () => this.handleSync());
    document.getElementById('refresh-page-btn')?.addEventListener('click', () => this.refreshPageInfo());
    
    // Auto-capture controls
    document.getElementById('toggle-capture-btn')?.addEventListener('click', () => this.toggleAutoCapture());
    document.getElementById('view-captures-btn')?.addEventListener('click', () => this.viewCapturedCredentials());
    
    // Password generator modal
    document.getElementById('close-generator-btn')?.addEventListener('click', () => this.hidePasswordGenerator());
    document.getElementById('copy-password-btn')?.addEventListener('click', () => this.copyGeneratedPassword());
    document.getElementById('regenerate-btn')?.addEventListener('click', () => this.generateNewPassword());
    document.getElementById('use-password-btn')?.addEventListener('click', () => this.useGeneratedPassword());
    
    // Generator options
    document.getElementById('length-slider')?.addEventListener('input', (e) => this.updatePasswordLength(e.target.value));
    document.querySelectorAll('#generator-modal input[type="checkbox"]').forEach(checkbox => {
      checkbox.addEventListener('change', () => this.generateNewPassword());
    });
    
    // Add password modal
    document.getElementById('close-add-btn')?.addEventListener('click', () => this.hideAddPasswordModal());
    document.getElementById('cancel-add-btn')?.addEventListener('click', () => this.hideAddPasswordModal());
    document.getElementById('add-password-form')?.addEventListener('submit', (e) => this.handleAddPassword(e));
    document.getElementById('toggle-password-btn')?.addEventListener('click', () => this.togglePasswordVisibility());
    document.getElementById('generate-for-add-btn')?.addEventListener('click', () => this.generatePasswordForAdd());
    
    // Modal backdrop clicks
    document.querySelectorAll('.modal').forEach(modal => {
      modal.addEventListener('click', (e) => {
        if (e.target === modal) {
          this.hideAllModals();
        }
      });
    });
    
    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => this.handleKeyboardShortcuts(e));
  }

  setupTouchHandlers() {
    // Add touch support for better mobile experience
    document.addEventListener('touchstart', (e) => {
      this.touchStartY = e.touches[0].clientY;
      this.touchStartX = e.touches[0].clientX;
      this.isScrolling = false;
    }, { passive: true });
    
    document.addEventListener('touchmove', (e) => {
      if (!this.touchStartY || !this.touchStartX) return;
      
      const touchY = e.touches[0].clientY;
      const touchX = e.touches[0].clientX;
      const diffY = this.touchStartY - touchY;
      const diffX = this.touchStartX - touchX;
      
      if (Math.abs(diffY) > Math.abs(diffX) && Math.abs(diffY) > 10) {
        this.isScrolling = true;
      }
    }, { passive: true });
    
    // Add haptic feedback for supported devices
    document.querySelectorAll('.btn, .icon-btn, .password-item').forEach(element => {
      element.addEventListener('touchstart', () => {
        if ('vibrate' in navigator) {
          navigator.vibrate(10);
        }
      }, { passive: true });
    });
  }

  async getCurrentTab() {
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      this.currentTab = tab;
      this.updatePageInfo();
    } catch (error) {
      console.error('Failed to get current tab:', error);
    }
  }

  async checkAuthStatus() {
    try {
      const result = await chrome.storage.local.get(['isAuthenticated', 'currentUser']);
      this.isAuthenticated = result.isAuthenticated || false;
      this.currentUser = result.currentUser || null;
      
      if (this.isAuthenticated && this.currentUser) {
        this.updateUserInfo();
      }
    } catch (error) {
      console.error('Failed to check auth status:', error);
      this.isAuthenticated = false;
    }
  }

  async handleSignIn() {
    try {
      this.showLoading('Signing in...');
      
      // Send message to background script to handle authentication
      const response = await chrome.runtime.sendMessage({
        action: 'authenticate',
        provider: 'google'
      });
      
      if (response.success) {
        this.isAuthenticated = true;
        this.currentUser = response.user;
        this.updateUserInfo();
        this.showNotification('Successfully signed in!', 'success');
        
        // Check vault state
        const vaultState = await chrome.runtime.sendMessage({ action: 'checkVaultState' });
        if (vaultState && vaultState.isUnlocked) {
          await this.loadPasswords();
          this.showScreen('main');
        } else {
          this.showScreen('lock');
        }
      } else {
        throw new Error(response.error || 'Authentication failed');
      }
    } catch (error) {
      console.error('Sign in failed:', error);
      this.showNotification('Sign in failed. Please try again.', 'error');
      this.showScreen('auth');
    }
  }

  async handleSignOut() {
    try {
      await chrome.runtime.sendMessage({ action: 'signOut' });
      this.isAuthenticated = false;
      this.currentUser = null;
      this.passwords = [];
      this.filteredPasswords = [];
      this.showScreen('auth');
      this.showNotification('Successfully signed out!', 'success');
    } catch (error) {
      console.error('Sign out failed:', error);
      this.showNotification('Sign out failed', 'error');
    }
  }

  handleLock() {
    chrome.runtime.sendMessage({ action: 'lockVault' });
    this.passwords = [];
    this.filteredPasswords = [];
    this.showScreen('lock');
    this.showNotification('Vault locked', 'info');
  }

  async handleVaultUnlock() {
    const pwInput = document.getElementById('master-password-input');
    const errorText = document.getElementById('unlock-error');
    const pwd = pwInput.value.trim();
    
    if (!pwd) {
      errorText.textContent = 'Please enter your Master Password.';
      errorText.style.display = 'block';
      return;
    }
    
    this.showLoading('Unlocking Vault...');
    errorText.style.display = 'none';
    
    try {
      const response = await chrome.runtime.sendMessage({ action: 'unlockVault', password: pwd });
      if (response.success) {
        pwInput.value = '';
        await this.loadPasswords();
        this.showScreen('main');
      } else {
        throw new Error(response.error || 'Incorrect Master Password');
      }
    } catch (error) {
      this.showScreen('lock');
      errorText.textContent = error.message;
      errorText.style.display = 'block';
    }
  }

  async loadPasswords() {
    try {
      this.showLoading('Loading passwords...');
      
      const response = await chrome.runtime.sendMessage({
        action: 'getPasswords',
        userId: this.currentUser?.uid
      });
      
      if (response && response.success) {
        this.passwords = response.passwords || [];
        this.filteredPasswords = [...this.passwords];
        this.updatePasswordsList();
        this.updatePasswordsCount();
      } else {
        console.warn('Load passwords response:', response);
        this.passwords = [];
        this.filteredPasswords = [];
        this.updatePasswordsList();
        this.updatePasswordsCount();
      }
    } catch (error) {
      console.error('Failed to load passwords:', error);
      this.passwords = [];
      this.filteredPasswords = [];
      this.updatePasswordsList();
      this.updatePasswordsCount();
      if (error.message && error.message.includes('locked')) {
        this.showScreen('lock');
        return;
      }
    } finally {
      // Switch back to main screen if not locked
      if (this.currentScreen === 'loading') {
         this.showScreen('main');
      }
    }
  }

  handleSearch(query) {
    this.searchQuery = query.toLowerCase();
    
    if (!query.trim()) {
      this.filteredPasswords = [...this.passwords];
    } else {
      this.filteredPasswords = this.passwords.filter(password => 
        password.siteName?.toLowerCase().includes(this.searchQuery) ||
        password.username?.toLowerCase().includes(this.searchQuery) ||
        password.url?.toLowerCase().includes(this.searchQuery)
      );
    }
    
    this.updatePasswordsList();
    this.updatePasswordsCount();
  }

  handleSearchEnter() {
    if (this.filteredPasswords.length === 1) {
      this.selectPassword(this.filteredPasswords[0]);
    }
  }

  updatePasswordsList() {
    const container = document.getElementById('passwords-content');
    const emptyState = document.getElementById('empty-state');
    
    if (!container) return;
    
    if (this.filteredPasswords.length === 0) {
      container.innerHTML = '';
      emptyState?.classList.remove('hidden');
      return;
    }
    
    emptyState?.classList.add('hidden');
    
    container.innerHTML = this.filteredPasswords.map(password => `
      <div class="password-item" data-id="${password.id}" onclick="popupManager.selectPassword('${password.id}')">
        <div class="password-icon">
          ${this.getPasswordIcon(password.siteName)}
        </div>
        <div class="password-details">
          <div class="password-name">${this.escapeHtml(password.name || password.siteName || 'Untitled')}</div>
          <div class="password-username">${this.escapeHtml(password.username || 'No username')}</div>
        </div>
        <div class="password-actions">
          <button class="icon-btn" onclick="event.stopPropagation(); popupManager.copyPassword('${password.id}')" title="Copy password">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
            </svg>
          </button>
          <button class="icon-btn" onclick="event.stopPropagation(); popupManager.fillPassword('${password.id}')" title="Auto-fill">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14,2 14,8 20,8"></polyline>
              <line x1="16" y1="13" x2="8" y2="13"></line>
              <line x1="16" y1="17" x2="8" y2="17"></line>
              <polyline points="10,9 9,9 8,9"></polyline>
            </svg>
          </button>
        </div>
      </div>
    `).join('');
  }

  updatePasswordsCount() {
    const countElement = document.getElementById('passwords-count');
    if (countElement) {
      countElement.textContent = this.filteredPasswords.length;
    }
  }

  getPasswordIcon(siteName) {
    if (!siteName) return '?';
    return siteName.charAt(0).toUpperCase();
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  async selectPassword(passwordId) {
    const password = this.passwords.find(p => p.id === passwordId);
    if (!password) return;
    
    try {
      // Auto-fill the password on the current page
      await this.fillPassword(passwordId);
      
      // Close popup after successful fill
      setTimeout(() => window.close(), 500);
    } catch (error) {
      console.error('Failed to select password:', error);
      this.showNotification('Failed to fill password', 'error');
    }
  }

  async copyPassword(passwordId) {
    const password = this.passwords.find(p => p.id === passwordId);
    if (!password) return;
    
    try {
      await navigator.clipboard.writeText(password.password);
      this.showNotification('Password copied to clipboard!', 'success');
      
      // Add haptic feedback
      if ('vibrate' in navigator) {
        navigator.vibrate(50);
      }
    } catch (error) {
      console.error('Failed to copy password:', error);
      this.showNotification('Failed to copy password', 'error');
    }
  }

  async fillPassword(passwordId) {
    const password = this.passwords.find(p => p.id === passwordId);
    if (!password || !this.currentTab) return;
    
    try {
      await chrome.tabs.sendMessage(this.currentTab.id, {
        action: 'fillPassword',
        password: password
      });
      
      this.showNotification('Password filled successfully!', 'success');
      
      // Log activity
      chrome.runtime.sendMessage({
        action: 'logActivity',
        activity: {
          type: 'password_filled',
          passwordId: passwordId,
          url: this.currentTab.url,
          timestamp: Date.now()
        }
      });
    } catch (error) {
      console.error('Failed to fill password:', error);
      this.showNotification('Failed to fill password', 'error');
    }
  }

  showPasswordGenerator() {
    const modal = document.getElementById('generator-modal');
    modal?.classList.add('active');
    this.generateNewPassword();
  }

  hidePasswordGenerator() {
    const modal = document.getElementById('generator-modal');
    modal?.classList.remove('active');
  }

  generateNewPassword() {
    const length = parseInt(document.getElementById('length-slider')?.value || '16');
    const uppercase = document.getElementById('uppercase-check')?.checked || false;
    const lowercase = document.getElementById('lowercase-check')?.checked || false;
    const numbers = document.getElementById('numbers-check')?.checked || false;
    const symbols = document.getElementById('symbols-check')?.checked || false;
    
    const password = this.generatePassword({
      length,
      uppercase,
      lowercase,
      numbers,
      symbols
    });
    
    const input = document.getElementById('generated-password-input');
    if (input) {
      input.value = password;
    }
    
    this.updatePasswordStrength(password);
  }

  generatePassword(options) {
    let charset = '';
    if (options.lowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
    if (options.uppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (options.numbers) charset += '0123456789';
    if (options.symbols) charset += '!@#$%^&*()_+-=[]{}|;:,.<>?';
    
    if (!charset) charset = 'abcdefghijklmnopqrstuvwxyz';
    
    let password = '';
    for (let i = 0; i < options.length; i++) {
      password += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    
    return password;
  }

  updatePasswordLength(length) {
    const valueElement = document.getElementById('length-value');
    if (valueElement) {
      valueElement.textContent = length;
    }
    this.generateNewPassword();
  }

  updatePasswordStrength(password) {
    const strength = this.calculatePasswordStrength(password);
    const indicator = document.getElementById('strength-indicator');
    const text = document.getElementById('strength-text');
    
    if (indicator && text) {
      indicator.className = `strength-fill ${strength.level}`;
      text.textContent = strength.label;
      text.className = `strength-text ${strength.level}`;
    }
  }

  calculatePasswordStrength(password) {
    let score = 0;
    
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (/[a-z]/.test(password)) score += 1;
    if (/[A-Z]/.test(password)) score += 1;
    if (/[0-9]/.test(password)) score += 1;
    if (/[^A-Za-z0-9]/.test(password)) score += 1;
    
    if (score < 3) return { level: 'weak', label: 'Weak' };
    if (score < 5) return { level: 'fair', label: 'Fair' };
    if (score < 6) return { level: 'good', label: 'Good' };
    return { level: 'strong', label: 'Strong' };
  }

  async copyGeneratedPassword() {
    const input = document.getElementById('generated-password-input');
    if (!input?.value) return;
    
    try {
      await navigator.clipboard.writeText(input.value);
      this.showNotification('Password copied to clipboard!', 'success');
    } catch (error) {
      console.error('Failed to copy password:', error);
      this.showNotification('Failed to copy password', 'error');
    }
  }

  async useGeneratedPassword() {
    const input = document.getElementById('generated-password-input');
    if (!input?.value || !this.currentTab) return;
    
    try {
      await chrome.tabs.sendMessage(this.currentTab.id, {
        action: 'fillGeneratedPassword',
        password: input.value
      });
      
      this.hidePasswordGenerator();
      this.showNotification('Password filled successfully!', 'success');
      setTimeout(() => window.close(), 500);
    } catch (error) {
      console.error('Failed to use generated password:', error);
      this.showNotification('Failed to fill password', 'error');
    }
  }

  showAddPasswordModal() {
    const modal = document.getElementById('add-password-modal');
    modal?.classList.add('active');
    
    // Pre-fill URL if available
    const urlInput = document.getElementById('site-url');
    if (urlInput && this.currentTab?.url) {
      urlInput.value = this.currentTab.url;
    }
    
    // Pre-fill site name from URL
    const siteNameInput = document.getElementById('site-name');
    if (siteNameInput && this.currentTab?.url) {
      try {
        const url = new URL(this.currentTab.url);
        siteNameInput.value = url.hostname.replace('www.', '');
      } catch (error) {
        // Invalid URL, ignore
      }
    }
  }

  hideAddPasswordModal() {
    const modal = document.getElementById('add-password-modal');
    modal?.classList.remove('active');
    
    // Reset form
    const form = document.getElementById('add-password-form');
    form?.reset();
  }

  async handleAddPassword(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const password = {
      siteName: formData.get('site-name'),
      url: formData.get('site-url'),
      username: formData.get('username'),
      password: formData.get('password'),
      notes: formData.get('notes'),
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    
    try {
      this.showLoading('Saving password...');
      
      const response = await chrome.runtime.sendMessage({
        action: 'addPassword',
        password: password,
        userId: this.currentUser?.uid
      });
      
      if (response.success) {
        this.hideAddPasswordModal();
        await this.loadPasswords();
        this.showNotification('Password saved successfully!', 'success');
      } else {
        throw new Error(response.error || 'Failed to save password');
      }
    } catch (error) {
      console.error('Failed to add password:', error);
      this.showNotification('Failed to save password', 'error');
    }
  }

  togglePasswordVisibility() {
    const input = document.getElementById('password');
    const button = document.getElementById('toggle-password-btn');
    
    if (input && button) {
      const isPassword = input.type === 'password';
      input.type = isPassword ? 'text' : 'password';
      
      button.innerHTML = isPassword ? 
        `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
          <line x1="1" y1="1" x2="23" y2="23"></line>
        </svg>` :
        `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
          <circle cx="12" cy="12" r="3"></circle>
        </svg>`;
    }
  }

  generatePasswordForAdd() {
    const password = this.generatePassword({
      length: 16,
      uppercase: true,
      lowercase: true,
      numbers: true,
      symbols: true
    });
    
    const input = document.getElementById('password');
    if (input) {
      input.value = password;
      input.type = 'text';
    }
  }

  hideAllModals() {
    document.querySelectorAll('.modal').forEach(modal => {
      modal.classList.remove('active');
    });
  }

  async handleSync() {
    try {
      this.showLoading('Syncing...');
      
      const response = await chrome.runtime.sendMessage({
        action: 'syncData',
        userId: this.currentUser?.uid
      });
      
      if (response && response.success) {
        await this.loadPasswords();
        this.showNotification('Sync completed successfully!', 'success');
      } else {
        this.showScreen('main');
        this.showNotification(response?.error || 'Sync failed', 'error');
      }
    } catch (error) {
      console.error('Sync failed:', error);
      this.showScreen('main');
      this.showNotification('Sync failed: ' + error.message, 'error');
    }
  }

  openMainApp() {
    chrome.tabs.create({ url: 'https://linkcrypta.app' });
  }

  openSettings() {
    chrome.runtime.openOptionsPage();
  }

  updatePageInfo() {
    const container = document.getElementById('page-details');
    if (!container || !this.currentTab) return;
    
    const url = new URL(this.currentTab.url || 'about:blank');
    const matchingPasswords = this.passwords.filter(p => 
      p.url && p.url.includes(url.hostname)
    );
    
    container.innerHTML = `
      <div class="page-detail">
        <span class="page-detail-label">Domain:</span>
        <span class="page-detail-value">${url.hostname}</span>
      </div>
      <div class="page-detail">
        <span class="page-detail-label">Matches:</span>
        <span class="page-detail-value">${matchingPasswords.length} password(s)</span>
      </div>
      <div class="page-detail">
        <span class="page-detail-label">Status:</span>
        <span class="page-detail-value">${url.protocol === 'https:' ? '🔒 Secure' : '⚠️ Not secure'}</span>
      </div>
    `;
  }

  refreshPageInfo() {
    this.getCurrentTab();
  }

  updateUserInfo() {
    const userInfo = document.getElementById('user-info');
    if (userInfo && this.currentUser) {
      userInfo.textContent = this.currentUser.email || this.currentUser.displayName || 'User';
    }
  }

  showScreen(screenName) {
    document.querySelectorAll('.screen').forEach(screen => {
      screen.classList.remove('active');
    });
    
    const targetScreen = document.getElementById(`${screenName}-screen`);
    if (targetScreen) {
      targetScreen.classList.add('active');
      targetScreen.classList.add('fade-in');
    }
    
    this.currentScreen = screenName;
  }

  showLoading(message = 'Loading...') {
    const loadingScreen = document.getElementById('loading-screen');
    const loadingText = loadingScreen?.querySelector('p');
    
    if (loadingText) {
      loadingText.textContent = message;
    }
    
    this.showScreen('loading');
  }

  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    
    // Style the notification
    Object.assign(notification.style, {
      position: 'fixed',
      top: '1rem',
      right: '1rem',
      padding: '0.75rem 1rem',
      borderRadius: '0.5rem',
      color: 'white',
      fontSize: '0.875rem',
      fontWeight: '500',
      zIndex: '9999',
      transform: 'translateX(100%)',
      transition: 'transform 0.3s ease-in-out',
      backgroundColor: type === 'success' ? '#10b981' : 
                      type === 'error' ? '#ef4444' : 
                      type === 'warning' ? '#f59e0b' : '#3b82f6'
    });
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => {
      notification.style.transform = 'translateX(0)';
    }, 100);
    
    // Remove after delay
    setTimeout(() => {
      notification.style.transform = 'translateX(100%)';
      setTimeout(() => {
        document.body.removeChild(notification);
      }, 300);
    }, 3000);
  }

  handleKeyboardShortcuts(event) {
    // Ctrl/Cmd + K for search focus
    if ((event.ctrlKey || event.metaKey) && event.key === 'k') {
      event.preventDefault();
      document.getElementById('search-input')?.focus();
    }
    
    // Escape to close modals
    if (event.key === 'Escape') {
      this.hideAllModals();
    }
    
    // Enter to select first password
    if (event.key === 'Enter' && event.target.id === 'search-input') {
      this.handleSearchEnter();
    }
  }

  // Auto-capture functionality
  async toggleAutoCapture() {
    try {
      this.autoCaptureEnabled = !this.autoCaptureEnabled;
      
      // Update UI
      this.updateAutoCaptureUI();
      
      // Send message to content script
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab) {
        await chrome.tabs.sendMessage(tab.id, {
          type: 'TOGGLE_AUTO_CAPTURE',
          enabled: this.autoCaptureEnabled
        });
      }
      
      // Save setting
      await chrome.storage.sync.set({ autoCaptureEnabled: this.autoCaptureEnabled });
      
      this.showNotification(
        `Auto-capture ${this.autoCaptureEnabled ? 'enabled' : 'disabled'}`,
        'success'
      );
      
    } catch (error) {
      console.error('Error toggling auto-capture:', error);
      this.showNotification('Failed to toggle auto-capture', 'error');
    }
  }

  async loadAutoCaptureStatus() {
    try {
      // Load settings
      const result = await chrome.storage.sync.get(['autoCaptureEnabled']);
      this.autoCaptureEnabled = result.autoCaptureEnabled !== false;
      
      // Load capture statistics
      await this.loadCaptureStats();
      
      // Update UI
      this.updateAutoCaptureUI();
      
    } catch (error) {
      console.error('Error loading auto-capture status:', error);
    }
  }

  async loadCaptureStats() {
    try {
      const result = await chrome.storage.local.get(['capturedCredentials']);
      const captures = result.capturedCredentials || [];
      
      // Calculate today's captures
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const todayCaptures = captures.filter(capture => {
        const captureDate = new Date(capture.timestamp);
        captureDate.setHours(0, 0, 0, 0);
        return captureDate.getTime() === today.getTime();
      });
      
      this.captureStats = {
        today: todayCaptures.length,
        total: captures.length
      };
      
    } catch (error) {
      console.error('Error loading capture stats:', error);
      this.captureStats = { today: 0, total: 0 };
    }
  }

  updateAutoCaptureUI() {
    const indicator = document.getElementById('capture-indicator');
    const toggleBtn = document.getElementById('toggle-capture-btn');
    const captureCount = document.getElementById('capture-count');
    
    if (indicator) {
      indicator.classList.toggle('active', this.autoCaptureEnabled);
    }
    
    if (toggleBtn) {
      toggleBtn.classList.toggle('active', this.autoCaptureEnabled);
      toggleBtn.title = `${this.autoCaptureEnabled ? 'Disable' : 'Enable'} auto-capture`;
    }
    
    if (captureCount) {
      const count = this.captureStats.today;
      captureCount.textContent = `${count} captured today`;
    }
  }

  async viewCapturedCredentials() {
    try {
      const result = await chrome.storage.local.get(['capturedCredentials']);
      const captures = result.capturedCredentials || [];
      
      if (captures.length === 0) {
        this.showNotification('No captured credentials found', 'info');
        return;
      }
      
      // Create and show captures modal
      this.showCapturesModal(captures);
      
    } catch (error) {
      console.error('Error viewing captured credentials:', error);
      this.showNotification('Failed to load captured credentials', 'error');
    }
  }

  showCapturesModal(captures) {
    // Create modal HTML
    const modal = document.createElement('div');
    modal.className = 'modal';
    modal.id = 'captures-modal';
    
    modal.innerHTML = `
      <div class="modal-content">
        <div class="modal-header">
          <h3>Captured Credentials (${captures.length})</h3>
          <button id="close-captures-btn" class="icon-btn">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
        <div class="modal-body">
          <div class="captures-list">
            ${captures.map(capture => `
              <div class="capture-item">
                <div class="capture-info">
                  <div class="capture-domain">${capture.domain}</div>
                  <div class="capture-username">${capture.username}</div>
                  <div class="capture-meta">
                    ${capture.isRegistration ? 'Registration' : 'Login'} • 
                    ${new Date(capture.timestamp).toLocaleDateString()}
                  </div>
                </div>
                <div class="capture-actions">
                  <button class="icon-btn" onclick="popupManager.copyCaptureData('${capture.domain}')">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                    </svg>
                  </button>
                </div>
              </div>
            `).join('')}
          </div>
          <div class="captures-actions">
            <button id="clear-captures-btn" class="btn btn-secondary">Clear All</button>
            <button id="sync-captures-btn" class="btn btn-primary">Sync to App</button>
          </div>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // Add event listeners
    document.getElementById('close-captures-btn').addEventListener('click', () => {
      document.body.removeChild(modal);
    });
    
    document.getElementById('clear-captures-btn').addEventListener('click', async () => {
      await this.clearCapturedCredentials();
      document.body.removeChild(modal);
    });
    
    document.getElementById('sync-captures-btn').addEventListener('click', async () => {
      await this.syncCapturesToApp();
      document.body.removeChild(modal);
    });
    
    // Show modal
    setTimeout(() => modal.classList.add('active'), 10);
  }

  async clearCapturedCredentials() {
    try {
      await chrome.storage.local.set({ capturedCredentials: [] });
      this.captureStats = { today: 0, total: 0 };
      this.updateAutoCaptureUI();
      this.showNotification('Captured credentials cleared', 'success');
    } catch (error) {
      console.error('Error clearing captured credentials:', error);
      this.showNotification('Failed to clear credentials', 'error');
    }
  }

  async syncCapturesToApp() {
    try {
      // Send sync message to background script
      const response = await chrome.runtime.sendMessage({
        type: 'SYNC_TO_FLUTTER_APP'
      });
      
      if (response.success) {
        this.showNotification(response.message || 'Sync completed', 'success');
      } else {
        this.showNotification(response.error || 'Sync failed', 'error');
      }
      
    } catch (error) {
      console.error('Error syncing to app:', error);
      this.showNotification('Failed to sync to app', 'error');
    }
  }

  copyCaptureData(domain) {
    navigator.clipboard.writeText(domain).then(() => {
      this.showNotification('Domain copied to clipboard', 'success');
    }).catch(() => {
      this.showNotification('Failed to copy domain', 'error');
    });
  }
}

// Initialize popup when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.popupManager = new PopupManager();
});

// Handle popup unload
window.addEventListener('beforeunload', () => {
  // Clean up any ongoing operations
  if (window.popupManager) {
    // Save any pending state
  }
});
