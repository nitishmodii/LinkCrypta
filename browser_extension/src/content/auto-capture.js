// Auto-Capture Service for LinkCrypta Extension
class AutoCaptureService {
  constructor() {
    this.detectedForms = new Map();
    this.observing = false;
    this.observer = null;
    this.pendingCaptures = new Map();
    this.formSubmissionHandlers = new Map();
    this.registrationDetector = null;
    this.lastCaptureTime = 0;
    this.captureDelay = 30000; // Prevent duplicate captures within 30 seconds
    this.capturedData = new Map(); // Track captured data to prevent duplicates
  }

  // Initialize auto-capture service
  async initialize() {
    try {
      // Check if auto-capture is enabled in settings
      const settings = await this.getSettings();
      this.isEnabled = settings.autoCaptureEnabled !== false;

      if (!this.isEnabled) {
        console.log('Auto-capture is disabled');
        return;
      }

      // Setup form submission listeners
      this.setupFormSubmissionListeners();
      
      // Setup registration detection
      this.setupRegistrationDetection();
      
      // NOTE: Input change listeners removed — capture only on form submit,
      // button click, or Enter key to avoid spamming the user with popups.

      // Check for pending captures from previous page (form submissions navigate away)
      await this.checkPendingCaptures();

      console.log('Auto-capture service initialized');
    } catch (error) {
      console.error('Failed to initialize auto-capture service:', error);
    }
  }

  // Check for pending captures from a previous page (e.g., form submission that navigated away)
  async checkPendingCaptures() {
    try {
      const result = await chrome.storage.local.get(['pendingCapture']);
      const pendingCapture = result.pendingCapture;
      
      if (pendingCapture && pendingCapture.data) {
        // Clear the pending capture immediately so it doesn't show again
        await chrome.storage.local.remove(['pendingCapture']);
        
        // Check if this capture is recent (within last 30 seconds)
        const age = Date.now() - (pendingCapture.timestamp || 0);
        if (age < 30000) {
          console.log('🔐 Showing pending capture from previous page:', pendingCapture.data.domain);
          
          // Show the "Save Password?" notification on this page
          this.showCaptureNotification(pendingCapture.data);
        }
      }
    } catch (error) {
      // Silently ignore — extension context might be invalidated
      if (!error.message?.includes('Extension context invalidated')) {
        console.error('Error checking pending captures:', error);
      }
    }
  }

  // Get extension settings
  async getSettings() {
    return new Promise((resolve) => {
      chrome.storage.sync.get(['autoCaptureEnabled', 'autoCaptureNotifications'], (result) => {
        resolve({
          autoCaptureEnabled: result.autoCaptureEnabled !== false,
          autoCaptureNotifications: result.autoCaptureNotifications !== false
        });
      });
    });
  }

  // Setup form submission listeners
  setupFormSubmissionListeners() {
    // Listen for form submissions
    document.addEventListener('submit', this.handleFormSubmission.bind(this), true);
    
    // Listen for button clicks that might trigger AJAX submissions
    document.addEventListener('click', this.handleButtonClick.bind(this), true);
    
    // Listen for Enter key in password fields
    document.addEventListener('keydown', this.handleKeyDown.bind(this), true);
    
    // Listen for navigation changes (SPA applications)
    this.setupNavigationListeners();
  }

  // Setup registration detection
  setupRegistrationDetection() {
    // Look for registration forms
    this.detectRegistrationForms();
    
    // Setup mutation observer for dynamic registration forms
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.addedNodes.length > 0) {
          setTimeout(() => this.detectRegistrationForms(), 100);
        }
      });
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  // Setup input change listeners for real-time capture
  setupInputChangeListeners() {
    document.addEventListener('input', (event) => {
      const field = event.target;
      
      // Only monitor password and username fields
      if (this.isCredentialField(field)) {
        this.scheduleCapture(field);
      }
    }, true);

    document.addEventListener('change', (event) => {
      const field = event.target;
      
      if (this.isCredentialField(field)) {
        this.scheduleCapture(field);
      }
    }, true);
  }

  // Setup navigation listeners for SPA applications
  setupNavigationListeners() {
    // Listen for pushState/replaceState changes
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;

    history.pushState = (...args) => {
      originalPushState.apply(history, args);
      setTimeout(() => this.handleNavigationChange(), 500);
    };

    history.replaceState = (...args) => {
      originalReplaceState.apply(history, args);
      setTimeout(() => this.handleNavigationChange(), 500);
    };

    // Listen for popstate events
    window.addEventListener('popstate', () => {
      setTimeout(() => this.handleNavigationChange(), 500);
    });
  }

  // Handle form submission
  handleFormSubmission(event) {
    if (!this.isEnabled) return;

    const form = event.target;
    if (!form || form.tagName !== 'FORM') return;

    try {
      // Extract credentials SYNCHRONOUSLY before page navigates away
      const usernameField = this.findUsernameField(form);
      const passwordField = this.findPasswordField(form);
      const emailField = this.findEmailField(form);

      if (!passwordField || !passwordField.value.trim()) return;

      const username = usernameField?.value.trim() || emailField?.value.trim() || '';
      const password = passwordField.value.trim();

      if (!username || !password) return;

      const captureData = {
        username,
        password,
        email: emailField?.value.trim() || (username.includes('@') ? username : ''),
        title: this.generateTitle(window.location.hostname, username),
        url: window.location.href,
        domain: window.location.hostname,
        favicon: this.getFavicon(),
        captureType: 'form_submission',
        timestamp: Date.now(),
        formAction: form.action || window.location.href,
        isRegistration: this.isRegistrationForm(form)
      };

      // Fire-and-forget: send to background before page navigates
      // Don't await — the page will navigate away
      chrome.runtime.sendMessage({
        type: 'CREDENTIALS_CAPTURED',
        data: captureData,
        showOnNextPage: true  // Tell background to show popup on next page
      }).catch(() => {});

      console.log('🔐 Credentials sent to background before navigation');
    } catch (error) {
      console.error('Error handling form submission:', error);
    }
  }

  // Handle button clicks for AJAX submissions and formless logins
  handleButtonClick(event) {
    if (!this.isEnabled) return;

    const button = event.target.closest('button, input[type="submit"], [role="button"], a');
    if (!button || !this.isSubmitButton(button)) return;

    try {
      // Extract credentials IMMEDIATELY before page might navigate
      const passwordFields = document.querySelectorAll('input[type="password"]');
      if (passwordFields.length === 0) return;

      const passwordField = passwordFields[0];
      const password = passwordField.value.trim();
      if (!password) return;

      // Find username/email field
      const allInputs = document.querySelectorAll('input[type="text"], input[type="email"], input[name*="user" i], input[name*="email" i], input[id*="user" i], input[id*="email" i]');
      let username = '';
      for (const input of allInputs) {
        if (input.value.trim() && input.type !== 'password') {
          username = input.value.trim();
          break;
        }
      }

      if (!username) return;

      const captureData = {
        username,
        password,
        email: username.includes('@') ? username : '',
        title: this.generateTitle(window.location.hostname, username),
        url: window.location.href,
        domain: window.location.hostname,
        favicon: this.getFavicon(),
        captureType: 'button_click',
        timestamp: Date.now(),
        isRegistration: this.isRegistrationContext()
      };

      // Fire-and-forget: send to background before page navigates
      chrome.runtime.sendMessage({
        type: 'CREDENTIALS_CAPTURED',
        data: captureData,
        showOnNextPage: true
      }).catch(() => {});

      console.log('🔐 Credentials captured on button click:', captureData.domain);
    } catch (error) {
      console.error('Error handling button click:', error);
    }
  }

  // Handle Enter key in password fields
  handleKeyDown(event) {
    if (!this.isEnabled || event.key !== 'Enter') return;

    const field = event.target;
    if (!this.isPasswordField(field)) return;

    try {
      const password = field.value.trim();
      if (!password) return;

      // Find username/email field
      const allInputs = document.querySelectorAll('input[type="text"], input[type="email"], input[name*="user" i], input[name*="email" i], input[id*="user" i], input[id*="email" i]');
      let username = '';
      for (const input of allInputs) {
        if (input.value.trim() && input.type !== 'password') {
          username = input.value.trim();
          break;
        }
      }

      if (!username) return;

      const captureData = {
        username,
        password,
        email: username.includes('@') ? username : '',
        title: this.generateTitle(window.location.hostname, username),
        url: window.location.href,
        domain: window.location.hostname,
        favicon: this.getFavicon(),
        captureType: 'enter_key',
        timestamp: Date.now(),
        isRegistration: this.isRegistrationContext()
      };

      // Fire-and-forget: send to background before page navigates
      chrome.runtime.sendMessage({
        type: 'CREDENTIALS_CAPTURED',
        data: captureData,
        showOnNextPage: true
      }).catch(() => {});

      console.log('🔐 Credentials captured on Enter key:', captureData.domain);
    } catch (error) {
      console.error('Error handling Enter key:', error);
    }
  }

  // Handle navigation changes in SPAs
  handleNavigationChange() {
    // Clear previous captures for new page
    this.capturedData.clear();
    
    // Re-detect forms on new page
    setTimeout(() => {
      this.detectRegistrationForms();
    }, 1000);
  }

  // Schedule credential capture with debouncing
  scheduleCapture(field) {
    const fieldId = this.getFieldId(field);
    
    // Initialize pendingCaptures as Map if not already
    if (!this.pendingCaptures) {
      this.pendingCaptures = new Map();
    }
    
    // Clear existing timeout for this field
    if (this.pendingCaptures.has(fieldId)) {
      clearTimeout(this.pendingCaptures.get(fieldId));
    }

    // Schedule new capture
    const timeoutId = setTimeout(async () => {
      try {
        const form = this.findParentForm(field) || this.findNearbyCredentialFields(field);
        
        if (form) {
          const credentials = await this.extractCredentialsFromElement(form);
          
          if (credentials && this.isValidCredentials(credentials)) {
            const captureData = {
              ...credentials,
              captureType: 'input_change',
              timestamp: Date.now(),
              url: window.location.href,
              domain: window.location.hostname,
              isRegistration: this.isRegistrationContext()
            };

            await this.captureCredentials(captureData);
          }
        }
      } catch (error) {
        console.error('Error in scheduled capture:', error);
      } finally {
        this.pendingCaptures.delete(fieldId);
      }
    }, 2000); // Wait 2 seconds after user stops typing

    this.pendingCaptures.set(fieldId, timeoutId);
  }

  // Extract credentials from form element
  async extractCredentialsFromForm(form) {
    const usernameField = this.findUsernameField(form);
    const passwordField = this.findPasswordField(form);
    const emailField = this.findEmailField(form);

    if (!passwordField || !passwordField.value.trim()) {
      return null;
    }

    const username = usernameField?.value.trim() || emailField?.value.trim() || '';
    const password = passwordField.value.trim();

    if (!username || !password) {
      return null;
    }

    return {
      username,
      password,
      email: emailField?.value.trim() || (username.includes('@') ? username : ''),
      title: this.generateTitle(window.location.hostname, username),
      url: window.location.href,
      domain: window.location.hostname,
      favicon: this.getFavicon()
    };
  }

  // Extract credentials from any element (for formless detection)
  async extractCredentialsFromElement(element) {
    const container = element.tagName === 'FORM' ? element : document.body;
    
    const usernameField = this.findUsernameField(container);
    const passwordField = this.findPasswordField(container);
    const emailField = this.findEmailField(container);

    if (!passwordField || !passwordField.value.trim()) {
      return null;
    }

    const username = usernameField?.value.trim() || emailField?.value.trim() || '';
    const password = passwordField.value.trim();

    if (!username || !password) {
      return null;
    }

    return {
      username,
      password,
      email: emailField?.value.trim() || (username.includes('@') ? username : ''),
      title: this.generateTitle(window.location.hostname, username),
      url: window.location.href,
      domain: window.location.hostname,
      favicon: this.getFavicon()
    };
  }

  // Capture credentials and send to Flutter app
  async captureCredentials(captureData) {
    // Prevent duplicate captures
    const captureKey = `${captureData.domain}-${captureData.username}-${captureData.password}`;
    const now = Date.now();
    
    if (this.capturedData.has(captureKey) && 
        (now - this.capturedData.get(captureKey)) < this.captureDelay) {
      return;
    }

    this.capturedData.set(captureKey, now);

    try {
      console.log('🔐 Credentials detected:', {
        domain: captureData.domain,
        username: captureData.username,
        type: captureData.captureType,
        isRegistration: captureData.isRegistration
      });

      // Only show notification on actual form submissions, not on input changes
      const isSubmissionCapture = ['form_submission', 'button_click', 'enter_key', 'registration', 'formless_registration'].includes(captureData.captureType);
      if (isSubmissionCapture) {
        const settings = await this.getSettings();
        if (settings.autoCaptureNotifications !== false) {
          this.showCaptureNotification(captureData);
        }
      }

      // Store in temporary capture queue (for history/analytics)
      await this.storeTempCapture(captureData);
      
      // Send to background script for logging
      chrome.runtime.sendMessage({
        type: 'CREDENTIALS_CAPTURED',
        data: captureData
      }).catch((error) => {
        console.log('Background script not available:', error);
      });

    } catch (error) {
      console.error('Error capturing credentials:', error);
    }
  }

  // Store temporary capture (not saved passwords, just detection history)
  async storeTempCapture(captureData) {
    return new Promise((resolve) => {
      chrome.storage.local.get(['captureHistory'], (result) => {
        const history = result.captureHistory || [];
        
        // Add new capture to history
        history.push({
          ...captureData,
          id: this.generateId(),
          detected: true,
          saved: false // Will be updated when user clicks "Save"
        });

        // Keep only last 50 captures
        if (history.length > 50) {
          history.splice(0, history.length - 50);
        }

        chrome.storage.local.set({ captureHistory: history }, resolve);
      });
    });
  }

  // Store capture in extension storage
  async storeCapture(captureData) {
    return new Promise((resolve) => {
      chrome.storage.local.get(['capturedCredentials'], (result) => {
        const captures = result.capturedCredentials || [];
        
        // Add new capture
        captures.push({
          ...captureData,
          id: this.generateId(),
          synced: false
        });

        // Keep only last 100 captures
        if (captures.length > 100) {
          captures.splice(0, captures.length - 100);
        }

        chrome.storage.local.set({ capturedCredentials: captures }, resolve);
      });
    });
  }

  // Show capture notification
  showCaptureNotification(captureData) {
    // Remove any existing notification
    const existing = document.querySelector('.linkcrypta-capture-notification');
    if (existing) {
      existing.remove();
    }

    const notification = document.createElement('div');
    notification.className = 'linkcrypta-capture-notification';
    notification.innerHTML = `
      <div class="linkcrypta-notification-content">
        <div class="linkcrypta-notification-icon">🔐</div>
        <div class="linkcrypta-notification-text">
          <strong>Save Password?</strong>
          <br><small>${captureData.domain}</small>
        </div>
        <div class="linkcrypta-notification-actions">
          <button class="linkcrypta-save-btn" data-action="save">Save</button>
          <button class="linkcrypta-cancel-btn" data-action="cancel">×</button>
        </div>
      </div>
    `;

    // Add styles
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: white;
      color: #333;
      padding: 16px;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.2);
      z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 14px;
      max-width: 320px;
      min-width: 280px;
      animation: slideInRight 0.3s ease-out;
      border: 2px solid #6C63FF;
    `;

    // Add animation and button styles
    const style = document.createElement('style');
    style.textContent = `
      @keyframes slideInRight {
        from { transform: translateX(400px); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
      }
      @keyframes slideOutRight {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(400px); opacity: 0; }
      }
      .linkcrypta-notification-content {
        display: flex;
        align-items: center;
        gap: 12px;
      }
      .linkcrypta-notification-icon {
        font-size: 24px;
        flex-shrink: 0;
      }
      .linkcrypta-notification-text {
        flex: 1;
        line-height: 1.4;
      }
      .linkcrypta-notification-text strong {
        color: #1a1a1a;
        font-size: 15px;
      }
      .linkcrypta-notification-text small {
        color: #666;
        font-size: 12px;
      }
      .linkcrypta-notification-actions {
        display: flex;
        gap: 8px;
        align-items: center;
        flex-shrink: 0;
      }
      .linkcrypta-save-btn {
        background: #6C63FF;
        color: white;
        border: none;
        padding: 8px 16px;
        border-radius: 6px;
        cursor: pointer;
        font-size: 13px;
        font-weight: 600;
        transition: background 0.2s;
      }
      .linkcrypta-save-btn:hover {
        background: #5a52d5;
      }
      .linkcrypta-save-btn:active {
        background: #4a42c5;
      }
      .linkcrypta-cancel-btn {
        background: none;
        border: none;
        color: #999;
        font-size: 24px;
        cursor: pointer;
        padding: 0;
        width: 28px;
        height: 28px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 4px;
        transition: background 0.2s;
      }
      .linkcrypta-cancel-btn:hover {
        background: #f0f0f0;
        color: #666;
      }
      .linkcrypta-notification-saving {
        pointer-events: none;
        opacity: 0.6;
      }
      .linkcrypta-notification-success {
        border-color: #10b981;
      }
      .linkcrypta-notification-error {
        border-color: #ef4444;
      }
    `;
    
    // Check if style already exists
    if (!document.getElementById('linkcrypta-notification-styles')) {
      style.id = 'linkcrypta-notification-styles';
      document.head.appendChild(style);
    }

    document.body.appendChild(notification);

    // Store the capture data on the notification element
    notification.captureData = captureData;

    // Save button handler
    notification.querySelector('.linkcrypta-save-btn').addEventListener('click', async (e) => {
      e.stopPropagation();
      await this.handleSaveCredentials(notification);
    });

    // Cancel button handler
    notification.querySelector('.linkcrypta-cancel-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      this.removeNotification(notification);
    });

    // Auto-remove after 15 seconds if no action taken
    setTimeout(() => {
      if (notification.parentNode) {
        this.removeNotification(notification);
      }
    }, 15000);
  }

  // Handle save credentials button click
  async handleSaveCredentials(notification) {
    const saveBtn = notification.querySelector('.linkcrypta-save-btn');
    const captureData = notification.captureData;
    
    if (!captureData) {
      console.error('No capture data found');
      this.showErrorNotification(notification, 'Failed to save');
      return;
    }

    try {
      // Show saving state
      notification.classList.add('linkcrypta-notification-saving');
      saveBtn.textContent = 'Saving...';
      
      console.log('💾 Saving credentials:', captureData);

      // Send message to background script to save
      const response = await new Promise((resolve, reject) => {
        chrome.runtime.sendMessage({
          action: 'addPassword',
          password: {
            name: captureData.title,
            title: captureData.title,
            siteName: captureData.title,
            username: captureData.username,
            password: captureData.password,
            url: captureData.url,
            domain: captureData.domain,
            email: captureData.email || '',
            favicon: captureData.favicon || '',
            notes: `Auto-captured on ${new Date().toLocaleDateString()}`
          }
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

      console.log('💾 Save response:', response);

      if (response && response.success) {
        // Show success state
        this.showSuccessNotification(notification, 'Saved!');
        
        // Remove notification after short delay
        setTimeout(() => {
          this.removeNotification(notification);
        }, 2000);
      } else {
        throw new Error(response?.error || 'Failed to save password');
      }
      
    } catch (error) {
      console.error('❌ Error saving credentials:', error);
      this.showErrorNotification(notification, 'Failed to save');
      
      // Re-enable the button after error
      notification.classList.remove('linkcrypta-notification-saving');
      saveBtn.textContent = 'Save';
    }
  }

  // Show success notification
  showSuccessNotification(notification, message) {
    notification.classList.remove('linkcrypta-notification-saving');
    notification.classList.add('linkcrypta-notification-success');
    
    const textDiv = notification.querySelector('.linkcrypta-notification-text');
    if (textDiv) {
      textDiv.innerHTML = `
        <strong style="color: #10b981;">✓ ${message}</strong>
        <br><small>Password saved successfully</small>
      `;
    }
    
    const saveBtn = notification.querySelector('.linkcrypta-save-btn');
    if (saveBtn) {
      saveBtn.style.background = '#10b981';
      saveBtn.textContent = 'Saved!';
    }
  }

  // Show error notification
  showErrorNotification(notification, message) {
    notification.classList.remove('linkcrypta-notification-saving');
    notification.classList.add('linkcrypta-notification-error');
    
    const textDiv = notification.querySelector('.linkcrypta-notification-text');
    if (textDiv) {
      textDiv.innerHTML = `
        <strong style="color: #ef4444;">✗ ${message}</strong>
        <br><small>Please try again</small>
      `;
    }
    
    const saveBtn = notification.querySelector('.linkcrypta-save-btn');
    if (saveBtn) {
      saveBtn.style.background = '#ef4444';
    }
    
    // Auto-remove after 3 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        this.removeNotification(notification);
      }
    }, 3000);
  }

  // Remove notification with animation
  removeNotification(notification) {
    notification.style.animation = 'slideOutRight 0.3s ease-in';
    setTimeout(() => {
      if (notification.parentNode) {
        notification.remove();
      }
    }, 300);
  }

  // Detect registration forms
  detectRegistrationForms() {
    const forms = document.querySelectorAll('form');
    
    forms.forEach(form => {
      if (this.isRegistrationForm(form)) {
        this.setupRegistrationFormListener(form);
      }
    });

    // Also check for formless registration
    this.detectFormlessRegistration();
  }

  // Setup listener for registration form
  setupRegistrationFormListener(form) {
    if (form.hasAttribute('data-linkcrypta-registration-listener')) return;
    
    form.setAttribute('data-linkcrypta-registration-listener', 'true');
    
    form.addEventListener('submit', async (event) => {
      const credentials = await this.extractCredentialsFromForm(form);
      
      if (credentials && this.isValidCredentials(credentials)) {
        const captureData = {
          ...credentials,
          captureType: 'registration',
          timestamp: Date.now(),
          url: window.location.href,
          domain: window.location.hostname,
          isRegistration: true
        };

        await this.captureCredentials(captureData);
      }
    });
  }

  // Detect formless registration
  detectFormlessRegistration() {
    const passwordFields = document.querySelectorAll('input[type="password"]');
    
    passwordFields.forEach(passwordField => {
      if (this.isInRegistrationContext(passwordField)) {
        this.setupFormlessRegistrationListener(passwordField);
      }
    });
  }

  // Setup listener for formless registration
  setupFormlessRegistrationListener(passwordField) {
    if (passwordField.hasAttribute('data-linkcrypta-registration-listener')) return;
    
    passwordField.setAttribute('data-linkcrypta-registration-listener', 'true');
    
    // Listen for changes and nearby button clicks
    const container = passwordField.closest('div, section, main') || document.body;
    
    container.addEventListener('click', async (event) => {
      if (this.isSubmitButton(event.target)) {
        setTimeout(async () => {
          const credentials = await this.extractCredentialsFromElement(container);
          
          if (credentials && this.isValidCredentials(credentials)) {
            const captureData = {
              ...credentials,
              captureType: 'formless_registration',
              timestamp: Date.now(),
              url: window.location.href,
              domain: window.location.hostname,
              isRegistration: true
            };

            await this.captureCredentials(captureData);
          }
        }, 1000);
      }
    });
  }

  // Helper methods for field detection
  findUsernameField(container) {
    const selectors = [
      'input[name*="username" i]',
      'input[name*="user" i]',
      'input[name*="login" i]',
      'input[id*="username" i]',
      'input[id*="user" i]',
      'input[id*="login" i]',
      'input[autocomplete="username"]',
      'input[type="text"]',
      'input[type="email"]'
    ];

    for (const selector of selectors) {
      const field = container.querySelector(selector);
      if (field && this.isVisibleField(field) && field.value.trim()) {
        return field;
      }
    }

    return null;
  }

  findPasswordField(container) {
    const passwordFields = container.querySelectorAll('input[type="password"]');
    
    for (const field of passwordFields) {
      if (this.isVisibleField(field) && field.value.trim()) {
        return field;
      }
    }

    return null;
  }

  findEmailField(container) {
    const selectors = [
      'input[type="email"]',
      'input[name*="email" i]',
      'input[id*="email" i]',
      'input[autocomplete="email"]'
    ];

    for (const selector of selectors) {
      const field = container.querySelector(selector);
      if (field && this.isVisibleField(field) && field.value.trim()) {
        return field;
      }
    }

    return null;
  }

  // Helper methods for form analysis
  isRegistrationForm(form) {
    const text = (form.textContent || '').toLowerCase();
    const action = (form.action || '').toLowerCase();
    const className = (form.className || '').toLowerCase();
    const id = (form.id || '').toLowerCase();

    const registrationKeywords = /sign.?up|register|create.?account|join|signup/i;
    
    return registrationKeywords.test(text) || 
           registrationKeywords.test(action) || 
           registrationKeywords.test(className) || 
           registrationKeywords.test(id);
  }

  isRegistrationContext() {
    const url = window.location.href.toLowerCase();
    const title = document.title.toLowerCase();
    const body = document.body.textContent.toLowerCase();

    const registrationKeywords = /sign.?up|register|create.?account|join|signup/i;
    
    return registrationKeywords.test(url) || 
           registrationKeywords.test(title) || 
           registrationKeywords.test(body);
  }

  isInRegistrationContext(element) {
    const container = element.closest('form, div, section') || document.body;
    const text = (container.textContent || '').toLowerCase();
    
    const registrationKeywords = /sign.?up|register|create.?account|join|signup/i;
    
    return registrationKeywords.test(text) || this.isRegistrationContext();
  }

  isSubmitButton(element) {
    if (!element) return false;
    
    const tagName = element.tagName.toLowerCase();
    const type = (element.type || '').toLowerCase();
    const text = (element.textContent || '').toLowerCase();
    
    if (tagName === 'input' && type === 'submit') return true;
    if (tagName === 'button' && (type === 'submit' || type === '')) return true;
    
    const submitKeywords = /sign.?in|log.?in|sign.?up|register|submit|continue|next|create|join/i;
    return submitKeywords.test(text);
  }

  isCredentialField(field) {
    if (!field || !field.tagName) return false;
    
    const type = (field.type || '').toLowerCase();
    const name = (field.name || '').toLowerCase();
    const id = (field.id || '').toLowerCase();
    
    if (type === 'password') return true;
    if (type === 'email') return true;
    
    const credentialKeywords = /username|user|login|email|password/i;
    return credentialKeywords.test(name) || credentialKeywords.test(id);
  }

  isPasswordField(field) {
    return field && field.type === 'password';
  }

  isVisibleField(field) {
    if (!field) return false;
    
    const style = window.getComputedStyle(field);
    return style.display !== 'none' && 
           style.visibility !== 'hidden' && 
           style.opacity !== '0' &&
           field.offsetWidth > 0 && 
           field.offsetHeight > 0;
  }

  isValidCredentials(credentials) {
    return credentials && 
           credentials.username && 
           credentials.password && 
           credentials.username.length > 0 && 
           credentials.password.length > 2;
  }

  // Helper methods
  findParentForm(element) {
    return element.closest('form');
  }

  findNearbyCredentialFields(element) {
    const container = element.closest('div, section, main, body');
    const hasCredentialFields = container.querySelector('input[type="password"]') || 
                               container.querySelector('input[type="email"]') ||
                               container.querySelector('input[name*="username" i]');
    
    return hasCredentialFields ? container : null;
  }

  getFieldId(field) {
    return field.id || field.name || field.type + '_' + Array.from(document.querySelectorAll(field.tagName)).indexOf(field);
  }

  generateTitle(domain, username) {
    const cleanDomain = domain.replace(/^www\./, '');
    return `${cleanDomain} - ${username}`;
  }

  getFavicon() {
    const favicon = document.querySelector('link[rel*="icon"]');
    return favicon ? favicon.href : `https://${window.location.hostname}/favicon.ico`;
  }

  generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }

  // Public methods for controlling auto-capture
  enable() {
    this.isEnabled = true;
    chrome.storage.sync.set({ autoCaptureEnabled: true });
  }

  disable() {
    this.isEnabled = false;
    chrome.storage.sync.set({ autoCaptureEnabled: false });
  }

  isEnabled() {
    return this.isEnabled;
  }

  // Get captured credentials
  async getCapturedCredentials() {
    return new Promise((resolve) => {
      chrome.storage.local.get(['capturedCredentials'], (result) => {
        resolve(result.capturedCredentials || []);
      });
    });
  }

  // Clear captured credentials
  async clearCapturedCredentials() {
    return new Promise((resolve) => {
      chrome.storage.local.set({ capturedCredentials: [] }, resolve);
    });
  }
}

// Make AutoCaptureService available globally
if (typeof window !== 'undefined') {
  window.AutoCaptureService = AutoCaptureService;
}
