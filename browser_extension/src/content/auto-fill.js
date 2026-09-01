// Auto-fill functionality for LinkCrypta Extension
class AutoFillManager {
  constructor() {
    this.formDetector = new FormDetector();
    this.isEnabled = true;
    this.fillDelay = 100; // Delay between field fills
    this.currentCredentialSelector = null;
  }

  // Initialize auto-fill manager
  initialize() {
    this.formDetector.startObserving();
    this.setupEventListeners();
  }

  // Setup event listeners
  setupEventListeners() {
    // Listen for form submissions to potentially save credentials
    document.addEventListener('submit', async (event) => {
      // Check if auto-save is enabled and site is not in never-save list
      const currentUrl = window.location.href;
      const isNeverSave = await this.isInNeverSaveList(currentUrl);
      
      if (!isNeverSave) {
        this.handleFormSubmit(event);
      }
    });

    // Listen for focus on username and password fields to show suggestions
    document.addEventListener('focus', (event) => {
      if (this.isPasswordField(event.target) || this.isUsernameField(event.target)) {
        this.handleFieldFocus(event.target);
      }
    }, true);

    // Listen for input changes to update suggestions
    document.addEventListener('input', (event) => {
      if (this.isUsernameField(event.target)) {
        this.handleUsernameInput(event.target);
      }
    });

    // Hide suggestions when clicking outside
    document.addEventListener('click', (event) => {
      if (this.currentCredentialSelector && !this.currentCredentialSelector.contains(event.target)) {
        // Don't hide if clicking on a field that will just re-trigger it
        if (!this.isPasswordField(event.target) && !this.isUsernameField(event.target)) {
          this.hideSuggestions();
        }
      }
    });
  }

  // Handle form submission
  handleFormSubmit(event) {
    const form = event.target;
    const formData = this.formDetector.getFormData(form);
    
    if (formData && formData.isLoginForm) {
      // Extract credentials from form
      const credentials = this.extractCredentialsFromForm(formData);
      
      if (credentials.username && credentials.password) {
        // Ask user if they want to save
        this.promptToSaveCredentials(credentials);
      }
    }
  }

  // Extract credentials from form data matching VaultMate structure
  extractCredentialsFromForm(formData) {
    const currentUrl = window.location.href;
    const siteName = this.extractSiteName(currentUrl);
    const hostname = new URL(currentUrl).hostname;
    
    return {
      id: this.generateId(),
      title: siteName,
      siteName: siteName,
      username: formData.username || formData.email || '',
      password: formData.password || '',
      email: formData.email || '',
      url: currentUrl,
      domain: hostname,
      favicon: `https://www.google.com/s2/favicons?domain=${hostname}&sz=32`,
      notes: `Auto-saved from ${siteName} on ${new Date().toLocaleDateString()}`,
      category: 'General',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      isFavorite: false
    };
  }

  // Extract site name from URL
  extractSiteName(url) {
    try {
      const hostname = new URL(url).hostname;
      return hostname.replace('www.', '').split('.')[0];
    } catch {
      return 'Unknown Site';
    }
  }

  // Generate unique ID
  generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }

  // Prompt user to save credentials
  promptToSaveCredentials(credentials) {
    // Create save prompt overlay
    const overlay = this.createSavePrompt(credentials);
    document.body.appendChild(overlay);
    
    // Auto-hide after 10 seconds
    setTimeout(() => {
      if (overlay.parentNode) {
        overlay.parentNode.removeChild(overlay);
      }
    }, 10000);
  }

  // Create save prompt UI
  createSavePrompt(credentials) {
    const overlay = document.createElement('div');
    overlay.className = 'linkcrypta-save-prompt';
    overlay.innerHTML = `
      <div class="linkcrypta-prompt-content">
        <div class="linkcrypta-prompt-header">
          <img src="${chrome.runtime.getURL('icons/icon-32.png')}" alt="LinkCrypta">
          <h3>Save Password?</h3>
          <button class="linkcrypta-close-btn" data-action="close">×</button>
        </div>
        <div class="linkcrypta-prompt-body">
          <p><strong>${credentials.name}</strong></p>
          <p>Username: ${credentials.username}</p>
          <p>Save this password to LinkCrypta?</p>
        </div>
        <div class="linkcrypta-prompt-actions">
          <button class="linkcrypta-btn linkcrypta-btn-secondary" data-action="never">Never for this site</button>
          <button class="linkcrypta-btn linkcrypta-btn-secondary" data-action="not-now">Not now</button>
          <button class="linkcrypta-btn linkcrypta-btn-primary" data-action="save">Save Password</button>
        </div>
      </div>
    `;

    // Add styles
    this.addPromptStyles();

    // Add event listeners
    overlay.addEventListener('click', (e) => {
      const action = e.target.dataset.action;
      if (action) {
        this.handlePromptAction(action, credentials, overlay);
      }
    });

    return overlay;
  }

  // Handle prompt actions
  async handlePromptAction(action, credentials, overlay) {
    try {
      switch (action) {
        case 'save':
          // Update button to show saving state
          const saveBtn = overlay.querySelector('[data-action="save"]');
          if (saveBtn) {
            saveBtn.textContent = 'Saving...';
            saveBtn.disabled = true;
          }
          
          await this.saveCredentialsToApp(credentials);
          this.showNotification('Password saved to LinkCrypta!', 'success');
          break;
        case 'never':
          this.addToNeverSaveList(credentials.url);
          this.showNotification('Site added to never save list', 'info');
          break;
        case 'not-now':
        case 'close':
          // Just close
          break;
      }
    } catch (error) {
      console.error('❌ Error handling prompt action:', error);
      this.showNotification('Failed to save password', 'error');
      
      // Re-enable button on error
      const saveBtn = overlay.querySelector('[data-action="save"]');
      if (saveBtn) {
        saveBtn.textContent = 'Save Password';
        saveBtn.disabled = false;
      }
      
      // Don't close overlay on error so user can retry
      return;
    }
    
    if (overlay.parentNode) {
      overlay.parentNode.removeChild(overlay);
    }
  }

  // Save credentials to VaultMate app structure
  async saveCredentialsToApp(credentials) {
    try {
      console.log('💾 Saving credentials to app:', credentials);
      
      // Send to background script to save using VaultMate structure
      const response = await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({
          action: 'addPassword',
          password: credentials
        }, (response) => {
          // Check for Chrome runtime errors
          if (chrome.runtime.lastError) {
            console.error('❌ Chrome runtime error:', chrome.runtime.lastError);
            reject(new Error(chrome.runtime.lastError.message));
            return;
          }
          
          console.log('📨 Response received:', response);
          resolve(response);
        });
      });
      
      if (!response || !response.success) {
        throw new Error(response?.error || 'Failed to save password');
      }
      
      console.log('✅ Credentials saved successfully!');
      
      // Log activity
      chrome.runtime.sendMessage({
        action: 'logActivity',
        activity: {
          type: 'password_auto_saved',
          siteName: credentials.name,
          url: credentials.url,
          timestamp: Date.now()
        }
      }).catch(err => console.log('Activity log error:', err));
      
    } catch (error) {
      console.error('❌ Failed to save credentials:', error);
      this.showNotification('Failed to save password: ' + error.message, 'error');
      throw error; // Re-throw so the calling function knows it failed
    }
  }

  // Add to never save list
  addToNeverSaveList(url) {
    const domain = new URL(url).hostname;
    chrome.storage.local.get(['neverSaveList'], (result) => {
      const neverSaveList = result.neverSaveList || [];
      if (!neverSaveList.includes(domain)) {
        neverSaveList.push(domain);
        chrome.storage.local.set({ neverSaveList });
      }
    });
  }

  // Check if site is in never save list
  async isInNeverSaveList(url) {
    const domain = new URL(url).hostname;
    const result = await chrome.storage.local.get(['neverSaveList']);
    const neverSaveList = result.neverSaveList || [];
    return neverSaveList.includes(domain);
  }

  // Show notification
  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `linkcrypta-notification linkcrypta-notification-${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    // Animate in
    setTimeout(() => notification.classList.add('show'), 100);
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.classList.remove('show');
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }, 3000);
  }

  // Add prompt styles
  addPromptStyles() {
    if (document.getElementById('linkcrypta-styles')) return;
    
    const styles = document.createElement('style');
    styles.id = 'linkcrypta-styles';
    styles.textContent = `
      .linkcrypta-save-prompt {
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 10000;
        background: white;
        border-radius: 12px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.2);
        width: 320px;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        animation: slideIn 0.3s ease-out;
      }
      
      @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
      }
      
      .linkcrypta-prompt-content {
        padding: 0;
      }
      
      .linkcrypta-prompt-header {
        display: flex;
        align-items: center;
        padding: 16px;
        border-bottom: 1px solid #e5e7eb;
        gap: 12px;
      }
      
      .linkcrypta-prompt-header img {
        width: 24px;
        height: 24px;
      }
      
      .linkcrypta-prompt-header h3 {
        margin: 0;
        flex: 1;
        font-size: 16px;
        font-weight: 600;
        color: #111827;
      }
      
      .linkcrypta-close-btn {
        background: none;
        border: none;
        font-size: 20px;
        cursor: pointer;
        color: #6b7280;
        padding: 4px;
        line-height: 1;
      }
      
      .linkcrypta-prompt-body {
        padding: 16px;
      }
      
      .linkcrypta-prompt-body p {
        margin: 0 0 8px 0;
        font-size: 14px;
        color: #374151;
      }
      
      .linkcrypta-prompt-body p:last-child {
        margin-bottom: 0;
        margin-top: 12px;
      }
      
      .linkcrypta-prompt-actions {
        display: flex;
        gap: 8px;
        padding: 16px;
        border-top: 1px solid #e5e7eb;
      }
      
      .linkcrypta-btn {
        padding: 8px 12px;
        border: none;
        border-radius: 6px;
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s;
      }
      
      .linkcrypta-btn-primary {
        background: #2563eb;
        color: white;
        flex: 1;
      }
      
      .linkcrypta-btn-primary:hover {
        background: #1d4ed8;
      }
      
      .linkcrypta-btn-secondary {
        background: #f3f4f6;
        color: #374151;
        font-size: 12px;
        padding: 6px 10px;
      }
      
      .linkcrypta-btn-secondary:hover {
        background: #e5e7eb;
      }
      
      .linkcrypta-notification {
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 10001;
        padding: 12px 16px;
        border-radius: 8px;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 14px;
        font-weight: 500;
        color: white;
        transform: translateX(100%);
        transition: transform 0.3s ease;
      }
      
      .linkcrypta-notification.show {
        transform: translateX(0);
      }
      
      .linkcrypta-notification-success {
        background: #10b981;
      }
      
      .linkcrypta-notification-error {
        background: #ef4444;
      }
      
      .linkcrypta-notification-info {
        background: #3b82f6;
      }
    `;
    
    document.head.appendChild(styles);
  }

  // Handle field focus (username or password)
  async handleFieldFocus(targetField) {
    if (!this.isEnabled || this.isFilling) return;

    try {
      const formData = this.getFormDataForField(targetField);
      if (!formData) return;

      // Get matching credentials
      const credentials = await this.getMatchingCredentials(window.location.href);
      
      if (credentials.length > 0) {
        this.showCredentialSuggestions(targetField, credentials);
      }
    } catch (error) {
      // Silently ignore "Extension context invalidated" — happens after extension reload
      if (!error.message?.includes('Extension context invalidated')) {
        console.error('Error handling password field focus:', error);
      }
    }
  }

  // Handle username input
  async handleUsernameInput(usernameField) {
    if (!this.isEnabled || this.isFilling) return;
    
    const value = usernameField.value.toLowerCase();
    if (value.length < 2) return;

    try {
      const credentials = await this.getMatchingCredentials(window.location.href, value);
      
      if (credentials.length > 0) {
        this.showUsernameSuggestions(usernameField, credentials);
      }
    } catch (error) {
      if (!error.message?.includes('Extension context invalidated')) {
        console.error('Error handling username input:', error);
      }
    }
  }

  // Fill credentials into form
  async fillCredentials(credentials, formData = null) {
    if (!credentials || !this.isEnabled) return;

    this.isFilling = true;
    try {
      let targetForm = formData;
      
      if (!targetForm) {
        // Find best matching form
        targetForm = this.findBestMatchingForm();
      }
      
      if (!targetForm) {
        throw new Error('No suitable form found');
      }

      // Fill username field
      if (targetForm.usernameField && credentials.username) {
        await this.fillField(targetForm.usernameField, credentials.username);
      }

      // Fill password field
      if (targetForm.passwordField && credentials.password) {
        await this.fillField(targetForm.passwordField, credentials.password);
      }

      // Hide any open suggestion popups
      this.hideSuggestions();

      // Show success indication
      this.showFillSuccess();

      // Log the auto-fill event
      this.logAutoFillEvent(credentials, targetForm);

    } catch (error) {
      console.error('Error filling credentials:', error);
      this.showFillError(error.message);
    } finally {
      this.isFilling = false;
    }
  }

  // Fill a single field with animation
  async fillField(field, value) {
    if (!field || !value) return;

    // Clear existing value
    field.value = '';
    
    // Focus the field
    field.focus();
    
    // Trigger input event to notify any listeners
    field.dispatchEvent(new Event('input', { bubbles: true }));
    
    // Fill character by character for more natural feel
    for (let i = 0; i <= value.length; i++) {
      field.value = value.substring(0, i);
      field.dispatchEvent(new Event('input', { bubbles: true }));
      await this.delay(10); // Small delay between characters
    }
    
    // Trigger change event
    field.dispatchEvent(new Event('change', { bubbles: true }));
    
    // Blur the field
    field.blur();
  }

  // Show credential suggestions popup
  showCredentialSuggestions(targetField, credentials) {
    // Remove existing suggestions
    this.hideSuggestions();

    const popup = this.createSuggestionPopup(credentials, 'credentials');
    this.positionPopup(popup, targetField);
    
    document.body.appendChild(popup);
    this.currentCredentialSelector = popup;
  }

  // Show username suggestions
  showUsernameSuggestions(targetField, credentials) {
    this.hideSuggestions();

    const popup = this.createSuggestionPopup(credentials, 'usernames');
    this.positionPopup(popup, targetField);
    
    document.body.appendChild(popup);
    this.currentCredentialSelector = popup;
  }

  // Create suggestion popup
  createSuggestionPopup(credentials, type) {
    const popup = document.createElement('div');
    popup.className = 'linkcrypta-suggestions';
    popup.innerHTML = `
      <div class="linkcrypta-suggestions-header">
        <img src="${chrome.runtime.getURL('icons/icon-16.png')}" alt="LinkCrypta">
        <span>LinkCrypta Suggestions</span>
      </div>
      <div class="linkcrypta-suggestions-list">
        ${credentials.map((cred, index) => 
          this.createSuggestionItem(cred, index, type)
        ).join('')}
      </div>
      <div class="linkcrypta-suggestions-footer">
        <button class="linkcrypta-generate-btn">Generate Password</button>
        <button class="linkcrypta-open-app-btn">Open LinkCrypta</button>
      </div>
    `;

    // Add event listeners
    popup.addEventListener('click', (e) => {
      this.handleSuggestionClick(e, credentials);
    });

    return popup;
  }

  // Create suggestion item
  createSuggestionItem(credential, index, type) {
    const displayName = credential.name || credential.url || 'Unknown';
    const displayUsername = credential.username || 'No username';
    
    return `
      <div class="linkcrypta-suggestion-item" data-index="${index}">
        <div class="linkcrypta-suggestion-icon">
          <div class="linkcrypta-favicon" style="background-image: url('https://www.google.com/s2/favicons?domain=${credential.url}&sz=16')"></div>
        </div>
        <div class="linkcrypta-suggestion-content">
          <div class="linkcrypta-suggestion-name">${this.escapeHtml(displayName)}</div>
          <div class="linkcrypta-suggestion-username">${this.escapeHtml(displayUsername)}</div>
        </div>
        <div class="linkcrypta-suggestion-actions">
          <button class="linkcrypta-fill-btn" data-action="fill" data-index="${index}">Fill</button>
          <button class="linkcrypta-copy-btn" data-action="copy" data-index="${index}">Copy</button>
        </div>
      </div>
    `;
  }

  // Handle suggestion popup clicks
  async handleSuggestionClick(event, credentials) {
    const actionBtn = event.target.closest('[data-action]');
    const item = event.target.closest('.linkcrypta-suggestion-item');
    
    let action = null;
    let index = -1;

    if (actionBtn) {
      action = actionBtn.dataset.action;
      index = parseInt(actionBtn.dataset.index);
    } else if (item) {
      // Treat clicking the entire row as a fill action
      action = 'fill';
      index = parseInt(item.dataset.index);
    }

    try {
      if (action === 'fill' && credentials[index]) {
        await this.fillCredentials(credentials[index]);
      } else if (action === 'copy' && credentials[index]) {
        await this.copyToClipboard(credentials[index].password);
        this.showCopySuccess();
      } else if (event.target.closest('.linkcrypta-generate-btn')) {
        await this.generateAndFillPassword();
      } else if (event.target.closest('.linkcrypta-open-app-btn')) {
        this.openLinkCryptaApp();
      }
    } finally {
      // Always hide the suggestions after any interaction
      this.hideSuggestions();
    }
  }

  // Position popup relative to target field
  positionPopup(popup, targetField) {
    const rect = targetField.getBoundingClientRect();
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;

    popup.style.cssText = `
      position: absolute;
      top: ${rect.bottom + scrollTop + 5}px;
      left: ${rect.left + scrollLeft}px;
      min-width: ${Math.max(rect.width, 300)}px;
      z-index: 2147483647;
    `;
  }

  // Hide suggestion popups
  hideSuggestions() {
    if (this.currentCredentialSelector) {
      this.currentCredentialSelector.remove();
      this.currentCredentialSelector = null;
    }
  }

  // Get matching credentials from background
  async getMatchingCredentials(url, query = '') {
    return new Promise((resolve) => {
      try {
        chrome.runtime.sendMessage({
          type: 'SEARCH_PASSWORDS',
          url: url,
          query: query
        }, (response) => {
          // Handle extension context invalidated
          if (chrome.runtime.lastError) {
            resolve([]);
            return;
          }
          if (response && response.success) {
            resolve(response.results || []);
          } else {
            resolve([]);
          }
        });
      } catch (error) {
        // Extension context invalidated — return empty
        resolve([]);
      }
    });
  }

  // Extract credentials from form
  extractCredentialsFromForm(formData) {
    const username = formData.usernameField?.value || '';
    const password = formData.passwordField?.value || '';
    
    return {
      name: this.generateCredentialName(window.location.href),
      username: username,
      password: password,
      url: window.location.href,
      domain: window.location.hostname,
      notes: `Auto-saved from ${window.location.hostname}`
    };
  }

  // Generate credential name from URL
  generateCredentialName(url) {
    try {
      const hostname = new URL(url).hostname;
      return hostname.replace('www.', '').split('.')[0];
    } catch {
      return 'Unknown Site';
    }
  }

  // Prompt user to save credentials
  promptToSaveCredentials(credentials) {
    // Create save prompt
    const prompt = document.createElement('div');
    prompt.className = 'linkcrypta-save-prompt';
    prompt.innerHTML = `
      <div class="linkcrypta-save-content">
        <div class="linkcrypta-save-header">
          <img src="${chrome.runtime.getURL('icons/icon-16.png')}" alt="LinkCrypta">
          <span>Save password to LinkCrypta?</span>
        </div>
        <div class="linkcrypta-save-details">
          <div>Site: ${this.escapeHtml(credentials.name)}</div>
          <div>Username: ${this.escapeHtml(credentials.username)}</div>
        </div>
        <div class="linkcrypta-save-actions">
          <button class="linkcrypta-save-yes">Save</button>
          <button class="linkcrypta-save-no">Not now</button>
          <button class="linkcrypta-save-never">Never for this site</button>
        </div>
      </div>
    `;

    // Position at top of page
    prompt.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 2147483647;
    `;

    // Add event listeners
    prompt.querySelector('.linkcrypta-save-yes').addEventListener('click', () => {
      this.saveCredentials(credentials);
      prompt.remove();
    });

    prompt.querySelector('.linkcrypta-save-no').addEventListener('click', () => {
      prompt.remove();
    });

    prompt.querySelector('.linkcrypta-save-never').addEventListener('click', () => {
      this.addToNeverSaveList(window.location.hostname);
      prompt.remove();
    });

    document.body.appendChild(prompt);

    // Auto-hide after 10 seconds
    setTimeout(() => {
      if (prompt.parentNode) {
        prompt.remove();
      }
    }, 10000);
  }

  // Save credentials
  async saveCredentials(credentials) {
    try {
      const response = await this.sendMessage({
        type: 'SAVE_PASSWORD',
        passwordData: credentials
      });

      if (response.success) {
        this.showSaveSuccess();
      } else {
        this.showSaveError(response.message);
      }
    } catch (error) {
      console.error('Error saving credentials:', error);
      this.showSaveError('Failed to save credentials');
    }
  }

  // Generate and fill password
  async generateAndFillPassword() {
    try {
      const response = await this.sendMessage({
        type: 'GENERATE_PASSWORD',
        options: {
          length: 16,
          includeUppercase: true,
          includeLowercase: true,
          includeNumbers: true,
          includeSymbols: true
        }
      });

      if (response.success) {
        const formData = this.findBestMatchingForm();
        if (formData?.passwordField) {
          await this.fillField(formData.passwordField, response.password);
          this.showGenerateSuccess(response.strength);
        }
      }
    } catch (error) {
      console.error('Error generating password:', error);
    }
  }

  // Copy to clipboard
  async copyToClipboard(text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch (error) {
      // Fallback for older browsers
      const textarea = document.createElement('textarea');
      textarea.value = text;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
    }
  }

  // Utility functions
  isPasswordField(field) {
    return field.type === 'password' || field.name?.toLowerCase().includes('password');
  }

  isUsernameField(field) {
    const name = (field.name || '').toLowerCase();
    const id = (field.id || '').toLowerCase();
    return field.type === 'email' || 
           name.includes('user') || 
           name.includes('email') ||
           id.includes('user') ||
           id.includes('email');
  }

  getFormDataForField(field) {
    const form = field.closest('form');
    if (form) {
      return this.formDetector.getFormData(form);
    }
    
    // Check for formless credentials
    const detectedForms = this.formDetector.getDetectedForms();
    return detectedForms.find(formData => 
      formData.passwordField === field || formData.usernameField === field
    );
  }

  findBestMatchingForm() {
    const forms = this.formDetector.getDetectedForms();
    return forms.sort((a, b) => b.confidence - a.confidence)[0] || null;
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  sendMessage(message) {
    return new Promise((resolve) => {
      chrome.runtime.sendMessage(message, resolve);
    });
  }

  // Success/Error notifications
  showFillSuccess() {
    this.showNotification('Credentials filled successfully', 'success');
  }

  showFillError(message) {
    this.showNotification(`Fill error: ${message}`, 'error');
  }

  showSaveSuccess() {
    this.showNotification('Password saved to LinkCrypta', 'success');
  }

  showSaveError(message) {
    this.showNotification(`Save error: ${message}`, 'error');
  }

  showCopySuccess() {
    this.showNotification('Password copied to clipboard', 'success');
  }

  showGenerateSuccess(strength) {
    this.showNotification(`Password generated (${strength.strength})`, 'success');
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `linkcrypta-notification linkcrypta-notification-${type}`;
    notification.textContent = message;
    
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 2147483647;
      padding: 12px 16px;
      border-radius: 4px;
      color: white;
      font-family: system-ui, -apple-system, sans-serif;
      font-size: 14px;
      max-width: 300px;
      background: ${type === 'success' ? '#28a745' : type === 'error' ? '#dc3545' : '#007bff'};
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
      if (notification.parentNode) {
        notification.remove();
      }
    }, 3000);
  }

  // Open LinkCrypta app
  openLinkCryptaApp() {
    // Open extension popup
    chrome.runtime.sendMessage({ type: 'OPEN_POPUP' });
  }

  // Add to never save list
  addToNeverSaveList(hostname) {
    chrome.runtime.sendMessage({
      type: 'ADD_TO_NEVER_SAVE_LIST',
      hostname: hostname
    });
  }

  // Log auto-fill event
  logAutoFillEvent(credentials, formData) {
    chrome.runtime.sendMessage({
      type: 'LOG_AUTOFILL_EVENT',
      data: {
        url: window.location.href,
        credentialId: credentials.id,
        timestamp: Date.now()
      }
    });
  }
}

// Make AutoFillManager available globally
if (typeof window !== 'undefined') {
  window.AutoFillManager = AutoFillManager;
}
