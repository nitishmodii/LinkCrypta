# 🔐 LinkCrypta - Secure Password & Link Manager

LinkCrypta is a comprehensive, end-to-end encrypted password and bookmark management ecosystem. It seamlessly integrates a powerful Flutter-based mobile application with a smart Chrome browser extension, ensuring that your credentials and secure links are safe, synced, and effortlessly accessible across all your devices.

LinkCrypta employs a strict **Zero-Knowledge Architecture**. Your data is encrypted locally on your device using a key derived from your Master Password before being synced to the cloud. The server never sees your plaintext data.

---

## 🌟 Key Features

### 📱 Mobile App (Flutter / Android / iOS)

#### **Core Vault & Security**
*   **Military-Grade Encryption:** Uses PBKDF2 for robust key derivation and AES-256-GCM for authenticated encryption of your vault.
*   **Zero-Knowledge Sync:** Your Master Password never leaves your device. Data stored in Firebase Firestore is fully encrypted (`{"v": 1, "n": "nonce", "c": "ciphertext"}`).
*   **Offline-First Architecture:** Built on top of Hive database, ensuring you have instant access to your vault even without an internet connection.
*   **Strict Biometric Authentication (View/Copy):** The app enforces strict security constraints. You **must** authenticate via Biometrics (Fingerprint / FaceID) or Device PIN every single time you attempt to view or copy a username or password.
*   **Vault Timeout & Auto-Lock:** Secure session management ensures your vault locks itself after a period of inactivity.

#### **Advanced Settings & Dashboards (Profile Tab)**
The **Profile / Settings Tab** provides a comprehensive control center for power users:
*   **Password Activity JSON Viewer:** Transparency at its core. View full, detailed logs of all your activities (exactly when a password was viewed, copied, or auto-filled) directly in JSON format.
*   **Autofill Service Configuration:** Easily manage and enable/disable LinkCrypta as your system-wide autofill provider directly from the app.
*   **Credential Importer:** Easily import credentials directly from the system autofill service into your secure vault.
*   **Security Settings:** Manage your PIN, toggle Biometric login requirements, and handle encryption preferences.
*   **Text Size & Accessibility:** Custom slider to adjust the app's text size for better readability across all screens.
*   **Advanced Features Hub:** Deep dive into Analytics Dashboards, Password Health analysis (weak, reused), and an Advanced Password Generator (passphrases, length, symbols).

#### **Smart Autofill Integration**
*   **Android Autofill Framework:** Deeply integrated with the Android OS. The native `AutofillService` suggests and auto-fills passwords in native apps and mobile browsers automatically.
*   **Smart AutoFill Matching:** Intelligently matches URLs and app domains to your saved credentials using fuzzy matching, Levenshtein distance, and subdomain analysis.

#### **Organization & Management**
*   **Secure Link Manager:** Not just for passwords! Save and organize end-to-end encrypted bookmarks and private links.
*   **Custom Categories:** Organize your credentials into intuitive categories (e.g., General, Work, Social, Finance) with visual filters.
*   **Favorites System:** Pin your most frequently used passwords and links for instant access.
*   **Modern UI/UX:** A beautifully crafted, responsive interface with smooth staggered animations, glassmorphism elements, and full Dark/Light mode support.

---

### 🌐 Browser Extension (Chrome)

#### **Intelligent Automation**
*   **Auto-Capture Credentials:** Smart `form-detector.js` intelligently detects when you successfully log into or sign up on a website and prompts you to save the new credentials to your vault.
*   **Smart Auto-Fill:** Automatically detects login forms on web pages and displays an inline suggestion popup to fill saved passwords securely.
*   **Race-Condition Safe:** Robust event handling and state management (`isFilling` flags) ensure the auto-fill process doesn't conflict with your manual typing or trigger infinite loops.

#### **Vault Access & Sync**
*   **Direct Cloud Sync:** Communicates directly with Firebase Firestore using the exact same PBKDF2/AES-256-GCM encryption algorithms as the mobile app.
*   **Quick Access Popup:** A polished extension popup to quickly search your vault, copy usernames/passwords, or generate strong new passwords without leaving your current tab.
*   **Keyboard Shortcuts:** Press `Ctrl+Shift+L` to open quick search or `Ctrl+Shift+F` to instantly trigger auto-fill on the current page.
*   **Capture Stats & Syncing:** Track your capture statistics in the extension popup. Credentials captured offline or locally can be manually pushed to the cloud with a dedicated "Sync to App" button.

---

## 🏗️ Architecture & Cryptography

Security is at the absolute heart of LinkCrypta. Here is how your data is protected:

1.  **Key Derivation (PBKDF2):** Your Master Password is run through the PBKDF2 algorithm with a unique salt and high iteration count to generate a strong 256-bit symmetric encryption key.
2.  **Encryption (AES-256-GCM):** All sensitive data (passwords, usernames, notes, URLs) is encrypted using AES-GCM, which provides both confidentiality and data authenticity (preventing tampering).
3.  **The Payload:** Data stored in Firebase is completely opaque. It looks like this: `{"v": 1, "n": "base64_nonce", "c": "base64_ciphertext"}`.
4.  **Local Caching:** Credentials are kept in Android `SharedPreferences` (for native autofill) and Hive (for the app) only in their encrypted state. They are decrypted strictly at runtime in memory when needed.

---

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (for the mobile app)
*   Google Chrome (for the browser extension)
*   Firebase Project (for Firestore Sync and Authentication)

### 1. Running the Mobile App
1.  Clone the repository:
    ```bash
    git clone https://github.com/nitishmodii/LinkCrypta.git
    ```
2.  Navigate to the project root and install dependencies:
    ```bash
    flutter pub get
    ```
3.  Set up Firebase:
    *   Add your `google-services.json` to `android/app/`.
    *   Add your `GoogleService-Info.plist` to `ios/Runner/`.
    *   Configure `lib/firebase_options.dart`.
4.  Connect your device or emulator and run:
    ```bash
    flutter run
    ```
5.  *To use Mobile Autofill:* Go to Android Settings -> System -> Passwords & Autofill -> Autofill Service -> Select **LinkCrypta**.

### 2. Installing the Browser Extension
1.  Open Google Chrome and navigate to `chrome://extensions/`.
2.  Enable **Developer mode** in the top right corner.
3.  Click **Load unpacked** and select the `browser_extension` folder from this repository.
4.  Pin the LinkCrypta extension to your toolbar.
5.  Log in with your Google account and enter your Master Password to sync your vault.

---

## 🛠️ Tech Stack

*   **Frontend Mobile:** Flutter, Dart, Provider (State Management)
*   **Frontend Extension:** Vanilla JavaScript, HTML5, CSS3, Chrome Extensions API (Manifest V3)
*   **Backend & Auth:** Firebase Firestore, Firebase Authentication, Google OAuth
*   **Local Storage:** Hive (Flutter), SharedPreferences (Android Native), `chrome.storage.local` (Extension)
*   **Native Integration:** Kotlin (Android AutofillService API, MethodChannels)
*   **Cryptography:** `pointycastle` (Dart), Web Crypto API (JavaScript)

---

## 🛡️ Privacy & Data Handling
LinkCrypta is designed so that you are the sole owner of your data.
*   **No Tracking:** No telemetry or tracking scripts are included.
*   **Encrypted Transit & Rest:** Passwords never leave the device in plaintext format.
*   **Zero-Knowledge:** We do not have access to your Master Password and cannot recover it or your data if lost.

---

*Built with ❤️ for secure and seamless password management.*