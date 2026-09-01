// LinkCrypta Extension Configuration
const CONFIG = {
  // Firebase configuration (matches your Flutter app — linkcrypta-61258)
  FIREBASE_CONFIG: {
    apiKey: "AIzaSyBTNuUpu41PKYBsbPTUGGKzHVhPNw9-Pmc",
    authDomain: "linkcrypta-61258.firebaseapp.com",
    projectId: "linkcrypta-61258",
    storageBucket: "linkcrypta-61258.firebasestorage.app",
    messagingSenderId: "795878816417",
    appId: "1:795878816417:web:your_web_app_id"
  },

  // Firestore REST API base URL
  FIRESTORE_BASE: "https://firestore.googleapis.com/v1/projects/linkcrypta-61258/databases/(default)/documents",

  // Firebase Auth REST API
  FIREBASE_AUTH_BASE: "https://identitytoolkit.googleapis.com/v1",
  FIREBASE_TOKEN_URL: "https://securetoken.googleapis.com/v1/token",

  // Extension settings
  EXTENSION: {
    NAME: "LinkCrypta",
    VERSION: "1.0.0",
    POPUP_WIDTH: 400,
    POPUP_HEIGHT: 600,
    AUTO_LOCK_TIMEOUT: 300000, // 5 minutes
    SYNC_INTERVAL: 60000 // 60 seconds
  },
  
  // Security settings
  SECURITY: {
    ENCRYPTION_ALGORITHM: "AES-GCM",
    KEY_LENGTH: 256,
    IV_LENGTH: 12,
    SALT_LENGTH: 16,
    ITERATIONS: 100000
  },
  
  // Auto-fill settings
  AUTOFILL: {
    CONFIDENCE_THRESHOLD: 0.7,
    MAX_SUGGESTIONS: 5,
    FORM_DETECTION_DELAY: 500,
    FILL_ANIMATION_DURATION: 300
  },
  
  // Storage keys
  STORAGE_KEYS: {
    USER_TOKEN: "linkcrypta_user_token",
    REFRESH_TOKEN: "linkcrypta_refresh_token",
    TOKEN_EXPIRY: "linkcrypta_token_expiry",
    FIREBASE_UID: "linkcrypta_firebase_uid",
    USER_EMAIL: "linkcrypta_user_email",
    USER_NAME: "linkcrypta_user_name",
    USER_PHOTO: "linkcrypta_user_photo",
    ENCRYPTED_DATA: "linkcrypta_encrypted_data",
    USER_SETTINGS: "linkcrypta_user_settings",
    SYNC_TIMESTAMP: "linkcrypta_sync_timestamp",
    MASTER_KEY_HASH: "linkcrypta_master_key_hash",
    CACHED_PASSWORDS: "linkcrypta_cached_passwords"
  },
  
  // Form field selectors for auto-detection
  FORM_SELECTORS: {
    USERNAME_FIELDS: [
      'input[type="email"]',
      'input[type="text"][name*="user"]',
      'input[type="text"][name*="email"]',
      'input[type="text"][id*="user"]',
      'input[type="text"][id*="email"]',
      'input[type="text"][placeholder*="email"]',
      'input[type="text"][placeholder*="username"]'
    ],
    PASSWORD_FIELDS: [
      'input[type="password"]',
      'input[name*="password"]',
      'input[id*="password"]',
      'input[placeholder*="password"]'
    ],
    LOGIN_FORMS: [
      'form[id*="login"]',
      'form[class*="login"]',
      'form[id*="signin"]',
      'form[class*="signin"]',
      'form[id*="auth"]',
      'form[class*="auth"]'
    ]
  }
};

// Make config available globally
if (typeof window !== 'undefined') {
  window.LINKCRYPTA_CONFIG = CONFIG;
} else if (typeof global !== 'undefined') {
  global.LINKCRYPTA_CONFIG = CONFIG;
}
