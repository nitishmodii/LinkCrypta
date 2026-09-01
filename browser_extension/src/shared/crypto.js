// Cryptographic utilities for LinkCrypta Extension
class CryptoUtils {
  constructor() {
    this.encoder = new TextEncoder();
    this.decoder = new TextDecoder();
  }

  // Base64 Helpers
  _arrayBufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  _base64ToArrayBuffer(base64) {
    const binaryString = atob(base64);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
  }

  // Generate a random salt
  generateSalt(length = 16) {
    return crypto.getRandomValues(new Uint8Array(length));
  }

  // Generate a random IV
  generateIV(length = 12) {
    return crypto.getRandomValues(new Uint8Array(length));
  }

  // Derive encryption key from master password (210,000 iterations)
  async deriveKey(password, saltBytes, iterations = 210000) {
    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      this.encoder.encode(password),
      { name: 'PBKDF2' },
      false,
      ['deriveBits', 'deriveKey']
    );

    return crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: saltBytes,
        iterations: iterations,
        hash: 'SHA-256'
      },
      keyMaterial,
      { name: 'AES-GCM', length: 256 },
      true,
      ['encrypt', 'decrypt']
    );
  }

  // Encrypt full record using AES-GCM
  // Returns: { v: 1, n: "base64", c: "base64" }
  async encryptRecord(data, key) {
    const iv = this.generateIV();
    const encodedData = this.encoder.encode(JSON.stringify(data));

    const encrypted = await crypto.subtle.encrypt(
      {
        name: 'AES-GCM',
        iv: iv
      },
      key,
      encodedData
    );

    return {
      v: 1,
      n: this._arrayBufferToBase64(iv),
      c: this._arrayBufferToBase64(encrypted)
    };
  }

  // Decrypt record using AES-GCM
  async decryptRecord(encryptedPayload, key) {
    if (encryptedPayload.v !== 1) {
      throw new Error('Unsupported encryption version');
    }

    const iv = new Uint8Array(this._base64ToArrayBuffer(encryptedPayload.n));
    const ciphertext = new Uint8Array(this._base64ToArrayBuffer(encryptedPayload.c));

    const decrypted = await crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: iv
      },
      key,
      ciphertext
    );

    const decryptedText = this.decoder.decode(decrypted);
    return JSON.parse(decryptedText);
  }

  // Hash master password for legacy verification (Not used in new E2EE, keeping for compatibility)
  async hashPassword(password, salt) {
    const key = await this.deriveKey(password, salt, 10000);
    const exported = await crypto.subtle.exportKey('raw', key);
    return Array.from(new Uint8Array(exported));
  }

  // Generate secure random password
  generatePassword(options = {}) {
    const {
      length = 16,
      includeUppercase = true,
      includeLowercase = true,
      includeNumbers = true,
      includeSymbols = true,
      excludeSimilar = true
    } = options;

    let charset = '';
    
    if (includeLowercase) {
      charset += excludeSimilar ? 'abcdefghjkmnpqrstuvwxyz' : 'abcdefghijklmnopqrstuvwxyz';
    }
    if (includeUppercase) {
      charset += excludeSimilar ? 'ABCDEFGHJKMNPQRSTUVWXYZ' : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    }
    if (includeNumbers) {
      charset += excludeSimilar ? '23456789' : '0123456789';
    }
    if (includeSymbols) {
      charset += '!@#$%^&*()_+-=[]{}|;:,.<>?';
    }

    let password = '';
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);

    for (let i = 0; i < length; i++) {
      password += charset[array[i] % charset.length];
    }

    return password;
  }

  calculatePasswordStrength(password) {
    let score = 0;
    let feedback = [];
    if (password.length >= 12) score += 25;
    else if (password.length >= 8) score += 15;
    else feedback.push('Use at least 8 characters');
    if (/[a-z]/.test(password)) score += 15;
    else feedback.push('Add lowercase letters');
    if (/[A-Z]/.test(password)) score += 15;
    else feedback.push('Add uppercase letters');
    if (/[0-9]/.test(password)) score += 15;
    else feedback.push('Add numbers');
    if (/[^A-Za-z0-9]/.test(password)) score += 15;
    else feedback.push('Add symbols');
    if (password.length >= 16) score += 10;
    if (password.length >= 20) score += 5;
    if (/(.)\1{2,}/.test(password)) score -= 10;
    if (/123|abc|qwe/i.test(password)) score -= 15;
    score = Math.max(0, Math.min(100, score));
    let strength = 'Very Weak';
    if (score >= 80) strength = 'Very Strong';
    else if (score >= 60) strength = 'Strong';
    else if (score >= 40) strength = 'Fair';
    else if (score >= 20) strength = 'Weak';
    return { score, strength, feedback };
  }

  clearSensitiveData(obj) {
    if (typeof obj === 'string') return '';
    else if (obj instanceof Uint8Array) obj.fill(0);
    else if (typeof obj === 'object' && obj !== null) {
      for (const key in obj) {
        if (obj.hasOwnProperty(key)) obj[key] = null;
      }
    }
  }
}

if (typeof window !== 'undefined') {
  window.CryptoUtils = CryptoUtils;
} else if (typeof global !== 'undefined') {
  global.CryptoUtils = CryptoUtils;
}
