import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto_async;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:encrypt/encrypt.dart' as encrypt_pkg;

class EncryptionService {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyName = 'linkcrypta_e2ee_key';
  
  static encrypt_pkg.Key? _derivedKeySync;
  static bool _initialized = false;
  
  static final _pbkdf2 = crypto_async.Pbkdf2(
    macAlgorithm: crypto_async.Hmac.sha256(),
    iterations: 210000,
    bits: 256, // 32 bytes
  );

  // Private constructor
  EncryptionService._();

  /// Check if we have a locally cached derived key
  static Future<bool> hasCachedKey() async {
    return await _storage.containsKey(key: _keyName);
  }

  /// Initialize from cached key (if available)
  static Future<bool> initializeFromCache() async {
    try {
      final keyString = await _storage.read(key: _keyName);
      if (keyString != null) {
        final keyBytes = base64Decode(keyString);
        _derivedKeySync = encrypt_pkg.Key(Uint8List.fromList(keyBytes));
        _initialized = true;
        return true;
      }
    } catch (e) {
      print('Failed to read cached key: $e');
    }
    return false;
  }

  /// Generate a random 16-byte salt
  static List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  /// Derive key from Master Password and salt, and cache it locally
  static Future<void> deriveAndCacheKey(String masterPassword, List<int> saltBytes) async {
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: masterPassword,
      nonce: saltBytes,
    );
    
    final keyBytes = await secretKey.extractBytes();
    _derivedKeySync = encrypt_pkg.Key(Uint8List.fromList(keyBytes));
    _initialized = true;

    // Cache the derived key securely on the device
    await _storage.write(key: _keyName, value: base64Encode(keyBytes));
  }
  
  /// Encrypt a full record using AES-256-GCM (Synchronous)
  /// Returns JSON structure: { "v": 1, "n": "base64_nonce", "c": "base64_ciphertext_with_mac" }
  static Map<String, dynamic> encryptRecordSync(Map<String, dynamic> record) {
    if (!_initialized || _derivedKeySync == null) {
      throw Exception('EncryptionService not initialized with Master Password.');
    }
    
    final jsonString = jsonEncode(record);
    
    // Generate secure 12-byte random nonce
    final random = Random.secure();
    final nonceBytes = Uint8List.fromList(List<int>.generate(12, (_) => random.nextInt(256)));
    final iv = encrypt_pkg.IV(nonceBytes);
    
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_derivedKeySync!, mode: encrypt_pkg.AESMode.gcm));
    
    // The encrypt package uses PointyCastle GCMBlockCipher which automatically appends the 16-byte MAC tag to the output.
    final encrypted = encrypter.encrypt(jsonString, iv: iv);
    
    return {
      'v': 1,
      'n': base64Encode(nonceBytes),
      'c': base64Encode(encrypted.bytes),
    };
  }

  /// Decrypt a record encrypted with AES-256-GCM (Synchronous)
  static Map<String, dynamic> decryptRecordSync(Map<String, dynamic> encryptedPayload) {
    if (!_initialized || _derivedKeySync == null) {
      throw Exception('EncryptionService not initialized with Master Password.');
    }
    
    if (encryptedPayload['v'] != 1) {
      throw Exception('Unsupported encryption version: ${encryptedPayload['v']}');
    }
    
    final nonceBytes = base64Decode(encryptedPayload['n']);
    final iv = encrypt_pkg.IV(Uint8List.fromList(nonceBytes));
    
    final cipherTextWithMac = base64Decode(encryptedPayload['c']);
    
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(_derivedKeySync!, mode: encrypt_pkg.AESMode.gcm));
    final encrypted = encrypt_pkg.Encrypted(Uint8List.fromList(cipherTextWithMac));
    
    try {
      final jsonString = encrypter.decrypt(encrypted, iv: iv);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Decryption failed (Invalid Master Password or Tampered Data): $e');
    }
  }

  /// Encrypt a single string synchronously
  static String encryptString(String plaintext) {
    final payload = encryptRecordSync({'data': plaintext});
    return jsonEncode(payload);
  }

  /// Decrypt a single string synchronously
  static String decryptString(String encryptedJsonString) {
    if (!encryptedJsonString.startsWith('{')) {
      throw Exception('Cannot decrypt legacy format with new Master Password key.');
    }
    final payload = jsonDecode(encryptedJsonString) as Map<String, dynamic>;
    final decryptedRecord = decryptRecordSync(payload);
    return decryptedRecord['data'] as String;
  }

  /// Clear the cached key
  static Future<void> clearEncryptionKeys() async {
    await _storage.delete(key: _keyName);
    _derivedKeySync = null;
    _initialized = false;
  }

  /// Legacy decryption for migration purposes (AES-CBC)
  static String? legacyDecrypt(String encryptedData, String base64LegacyKey, String base64LegacyIv) {
    try {
      final keyBytes = base64Decode(base64LegacyKey);
      final ivBytes = base64Decode(base64LegacyIv);
      
      final key = encrypt_pkg.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt_pkg.IV(Uint8List.fromList(ivBytes));
      final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));
      
      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      print('Legacy decryption failed: $e');
      return null;
    }
  }

  /// Generate a strong random password (Utility)
  static String generateStrongPassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
  }) {
    const String uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const String numbers = '0123456789';
    const String symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String chars = '';
    if (includeUppercase) chars += uppercase;
    if (includeLowercase) chars += lowercase;
    if (includeNumbers) chars += numbers;
    if (includeSymbols) chars += symbols;

    if (chars.isEmpty) chars = lowercase + numbers;

    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Utility hash
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return crypto_pkg.sha256.convert(bytes).toString();
  }
}
