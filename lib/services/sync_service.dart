import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/password_entry.dart';
import '../models/link_entry.dart';
import 'storage_service.dart';
import 'encryption_service.dart';

/// Sync service that stores data locally in Hive
/// Future cloud sync features can be added when Firebase storage is implemented
class SyncService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _lastUserEmailKey = 'last_user_email';
  static const String _userDataBackupPrefix = 'user_data_backup_';
  
  static bool get _isUserAuthenticated => FirebaseAuth.instance.currentUser != null;

  static Future<void> initialize() async {
    // Initialize Hive for local storage
    await StorageService.initialize();
    // Local storage initialized
    
    // Check if user is authenticated for future cloud sync features
    if (_isUserAuthenticated) {
      // User authenticated - ready for future cloud sync features
    } else {
      print('SyncService: No authenticated user - using local storage only');
    }
  }

  // LOCAL STORAGE METHODS

  /// Add a password to local storage
  static Future<bool> addPassword(PasswordEntry password) async {
    try {
      await StorageService.addPassword(
        name: password.name,
        username: password.username,
        password: password.password,
        url: password.url,
        notes: password.notes,
        category: password.category,
      );
      print('SyncService: Password "${password.name}" added to local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to add password to local storage: $e');
      return false;
    }
  }

  /// Update a password in local storage
  static Future<bool> updatePassword(PasswordEntry password) async {
    try {
      await StorageService.updatePassword(password);
      print('SyncService: Password "${password.name}" updated in local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to update password in local storage: $e');
      return false;
    }
  }

  /// Delete a password from local storage by entry object
  static Future<bool> deletePassword(PasswordEntry password) async {
    try {
      await StorageService.deletePassword(password);
      print('SyncService: Password deleted from local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to delete password from local storage: $e');
      return false;
    }
  }

  /// Delete a password from local storage by ID
  static Future<bool> deletePasswordById(String id) async {
    try {
      final passwords = await getAllPasswords();
      final password = passwords.firstWhere((p) => p.id == id);
      await StorageService.deletePassword(password);
      print('SyncService: Password with ID $id deleted from local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to delete password by ID from local storage: $e');
      return false;
    }
  }

  /// Add a link to local storage
  static Future<bool> addLink(LinkEntry link) async {
    try {
      await StorageService.addLink(
        title: link.title,
        description: link.description,
        url: link.url,
        category: link.category,
      );
      print('SyncService: Link "${link.title}" added to local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to add link to local storage: $e');
      return false;
    }
  }

  /// Update a link in local storage
  static Future<bool> updateLink(LinkEntry link) async {
    try {
      await StorageService.updateLink(link);
      print('SyncService: Link "${link.title}" updated in local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to update link in local storage: $e');
      return false;
    }
  }

  /// Delete a link from local storage by entry object
  static Future<bool> deleteLink(LinkEntry link) async {
    try {
      await StorageService.deleteLink(link);
      print('SyncService: Link deleted from local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to delete link from local storage: $e');
      return false;
    }
  }

  /// Delete a link from local storage by ID
  static Future<bool> deleteLinkById(String id) async {
    try {
      final links = await getAllLinks();
      final link = links.firstWhere((l) => l.id == id);
      await StorageService.deleteLink(link);
      print('SyncService: Link with ID $id deleted from local storage');
      return true;
    } catch (e) {
      print('SyncService: Failed to delete link by ID from local storage: $e');
      return false;
    }
  }

  /// Get all passwords from local storage
  static Future<List<PasswordEntry>> getAllPasswords() async {
    try {
      return StorageService.getAllPasswords();
    } catch (e) {
      print('SyncService: Failed to get passwords from local storage: $e');
      return [];
    }
  }

  /// Get all links from local storage
  static Future<List<LinkEntry>> getAllLinks() async {
    try {
      return StorageService.getAllLinks();
    } catch (e) {
      print('SyncService: Failed to get links from local storage: $e');
      return [];
    }
  }

  /// Export data from local storage
  static Future<Map<String, dynamic>> exportData() async {
    try {
      final passwords = StorageService.getAllPasswords();
      final links = StorageService.getAllLinks();
      
      return {
        'passwords': passwords.map((p) => p.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
        'exportedAt': DateTime.now().toIso8601String(),
        'user': _isUserAuthenticated ? FirebaseAuth.instance.currentUser?.email : 'local_user',
      };
    } catch (e) {
      print('SyncService: Failed to export data: $e');
      return {};
    }
  }

  /// Import data to local storage
  static Future<bool> importData(Map<String, dynamic> data) async {
    try {
      await StorageService.importData(data);
      print('SyncService: Data imported successfully');
      return true;
    } catch (e) {
      print('SyncService: Failed to import data: $e');
      return false;
    }
  }

  /// Get sync status (for future cloud sync features)
  static Future<Map<String, dynamic>> getSyncStatus() async {
    return {
      'isAuthenticated': _isUserAuthenticated,
      'user': _isUserAuthenticated ? FirebaseAuth.instance.currentUser?.email : null,
      'lastSync': null, // Will be implemented with cloud sync
      'cloudSyncEnabled': false, // Will be implemented with cloud sync
      'localDataCount': {
        'passwords': (await getAllPasswords()).length,
        'links': (await getAllLinks()).length,
      },
    };
  }

  /// Clear all local data
  static Future<bool> clearAllData() async {
    try {
      await StorageService.clearAllData();
      print('SyncService: All local data cleared');
      return true;
    } catch (e) {
      print('SyncService: Failed to clear local data: $e');
      return false;
    }
  }

  // COMPATIBILITY METHODS FOR DATA PROVIDER
  // These methods provide compatibility with the existing DataProvider expectations

  /// Sync password to Firebase - stores password details in Firestore
  static Future<bool> syncPasswordToFirebase(PasswordEntry password) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('SyncService: Cannot sync password - user not authenticated');
      throw Exception('User not authenticated. Please sign in first.');
    }

    try {
      final userId = currentUser.uid;
      final firestore = FirebaseFirestore.instance;
      
      
      // Decrypt the local password to plaintext for the unified E2EE payload
      final Map<String, dynamic> plaintextJson = password.toJson();
      plaintextJson['password'] = StorageService.decryptPassword(password.password);
      
      // Encrypt full record
      final encryptedPayload = EncryptionService.encryptRecordSync(plaintextJson);
      
      // Store password in Firebase under user's collection
      await firestore
          .collection('users')
          .doc(userId)
          .collection('passwords')
          .doc(password.id)
          .set(encryptedPayload);
      
      return true;
    } catch (e) {
      
      // Provide more specific error messages
      if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Cloud Firestore API not enabled. Please enable it in Firebase Console.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Sync failed: ${e.toString()}');
      }
    }
  }

  /// Sync link to Firebase - stores link details in Firestore
  static Future<bool> syncLinkToFirebase(LinkEntry link) async {
    if (!_isUserAuthenticated) {
      print('SyncService: Cannot sync link - user not authenticated');
      return false;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Encrypt full record
      final Map<String, dynamic> plaintextJson = link.toJson();
      final encryptedPayload = EncryptionService.encryptRecordSync(plaintextJson);
      
      // Store link in Firebase under user's collection
      await firestore
          .collection('users')
          .doc(userId)
          .collection('links')
          .doc(link.id)
          .set(encryptedPayload);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sync all data to Firebase - uploads all passwords and links to Firestore
  static Future<bool> syncAllToFirebase() async {
    if (!_isUserAuthenticated) {
      print('SyncService: Cannot sync all data - user not authenticated');
      return false;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      // Get all local data
      final passwords = await getAllPasswords();
      final links = await getAllLinks();
      
      
      // Sync all passwords
      for (final password in passwords) {
        final Map<String, dynamic> plaintextJson = password.toJson();
        plaintextJson['password'] = StorageService.decryptPassword(password.password);
        final encryptedPayload = EncryptionService.encryptRecordSync(plaintextJson);
        
        await firestore
            .collection('users')
            .doc(userId)
            .collection('passwords')
            .doc(password.id)
            .set(encryptedPayload);
      }
      
      // Sync all links
      for (final link in links) {
        final Map<String, dynamic> plaintextJson = link.toJson();
        final encryptedPayload = EncryptionService.encryptRecordSync(plaintextJson);
        
        await firestore
            .collection('users')
            .doc(userId)
            .collection('links')
            .doc(link.id)
            .set(encryptedPayload);
      }
      
      return true;
    } catch (e) {
      
      // Provide more specific error messages
      if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Cloud Firestore API not enabled. Please enable it in Firebase Console.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Sync failed: ${e.toString()}');
      }
    }
  }

  /// Sync from Firebase - downloads all data from Firestore and merges with local data
  static Future<bool> syncFromFirebase() async {
    if (!_isUserAuthenticated) {
      return false;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;
      
      
      // Get Firebase data
      final passwordsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('passwords')
          .get();
          
      final linksSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('links')
          .get();
      
      // Get local data for comparison
      final localPasswords = await getAllPasswords();
      final localLinks = await getAllLinks();
      
      // Process Firebase passwords
      for (final doc in passwordsSnapshot.docs) {
        try {
          final encryptedPayload = doc.data();
          // Skip if it doesn't look like our new encrypted format
          if (!encryptedPayload.containsKey('c')) continue;
          
          final plaintextJson = EncryptionService.decryptRecordSync(encryptedPayload);
          final firebasePassword = PasswordEntry.fromJson(plaintextJson);
          
          // Check if password already exists locally
          final exists = localPasswords.any((local) => local.id == firebasePassword.id);
          
          if (!exists) {
            await StorageService.addPassword(
              id: firebasePassword.id,
              name: firebasePassword.name,
              username: firebasePassword.username,
              password: firebasePassword.password,
              url: firebasePassword.url,
              notes: firebasePassword.notes,
              category: firebasePassword.category,
            );
          }
        } catch (e) {
          print('Failed to decrypt and sync password from Firebase: $e');
        }
      }
      
      // Process Firebase links
      for (final doc in linksSnapshot.docs) {
        try {
          final encryptedPayload = doc.data();
          if (!encryptedPayload.containsKey('c')) continue; // Skip non-encrypted legacy records
          
          final plaintextJson = EncryptionService.decryptRecordSync(encryptedPayload);
          final firebaseLink = LinkEntry.fromJson(plaintextJson);
          
          // Check if link already exists locally
          final exists = localLinks.any((local) => local.id == firebaseLink.id);
          
          if (!exists) {
            await StorageService.addLink(
              id: firebaseLink.id,
              title: firebaseLink.title,
              description: firebaseLink.description,
              url: firebaseLink.url,
              category: firebaseLink.category,
            );
          }
        } catch (e) {
          print('Failed to decrypt and sync link from Firebase: $e');
        }
      }
      
      return true;
    } catch (e) {
      
      // Provide more specific error messages
      if (e.toString().contains('PERMISSION_DENIED')) {
        throw Exception('Cloud Firestore API not enabled. Please enable it in Firebase Console.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Sync failed: ${e.toString()}');
      }
    }
  }

  /// Check if sync is possible (returns true if user is authenticated)
  static bool canSync() {
    return _isUserAuthenticated;
  }

  /// Get current user email
  static String? getCurrentUserEmail() {
    return _isUserAuthenticated ? FirebaseAuth.instance.currentUser?.email : null;
  }

  // USER DATA BACKUP AND RESTORATION METHODS

  /// Backup current user's data before logout (both local and cloud)
  static Future<bool> backupUserData(String userEmail) async {
    try {
      final passwords = await getAllPasswords();
      final links = await getAllLinks();
      
      if (passwords.isEmpty && links.isEmpty) {
        print('SyncService: No data to backup for user $userEmail');
        return true;
      }

      final backupData = {
        'passwords': passwords.map((p) => p.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
        'backupDate': DateTime.now().toIso8601String(),
        'userEmail': userEmail,
        'deviceInfo': 'flutter_app', // Can be enhanced with actual device info
      };

      // 1. Save to local storage (fallback)
      final backupKey = '$_userDataBackupPrefix$userEmail';
      await _storage.write(key: backupKey, value: jsonEncode(backupData));
      await _storage.write(key: _lastUserEmailKey, value: userEmail);
      
      // 2. Save to Firestore (cloud sync)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          final encryptedBackup = EncryptionService.encryptRecordSync(backupData);
          await firestore
              .collection('user_backups')
              .doc(currentUser.uid)
              .set(encryptedBackup);
          
          print('SyncService: Data backed up to cloud for user $userEmail');
        } catch (e) {
          print('SyncService: Cloud backup failed, local backup successful: $e');
          // Continue with local backup even if cloud fails
        }
      }
      
      print('SyncService: Backed up ${passwords.length} passwords and ${links.length} links for user $userEmail');
      return true;
    } catch (e) {
      print('SyncService: Failed to backup user data: $e');
      return false;
    }
  }

  /// Check if backup data exists for a user email (cloud first, then local)
  static Future<bool> hasBackupData(String userEmail) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // 1. Check cloud backup first (works across devices)
      if (currentUser != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          final cloudBackup = await firestore
              .collection('user_backups')
              .doc(currentUser.uid)
              .get();
          
          if (cloudBackup.exists && cloudBackup.data() != null) {
            print('SyncService: Found cloud backup for user $userEmail');
            return true;
          }
        } catch (e) {
          print('SyncService: Cloud backup check failed: $e');
          // Fall back to local check
        }
      }
      
      // 2. Check local backup (same device only)
      final backupKey = '$_userDataBackupPrefix$userEmail';
      final backupData = await _storage.read(key: backupKey);
      final hasLocal = backupData != null && backupData.isNotEmpty;
      
      if (hasLocal) {
        print('SyncService: Found local backup for user $userEmail');
      }
      
      return hasLocal;
    } catch (e) {
      print('SyncService: Error checking backup data: $e');
      return false;
    }
  }

  /// Get backup data summary for a user (cloud first, then local)
  static Future<Map<String, dynamic>?> getBackupSummary(String userEmail) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? backupData;
      String backupSource = 'unknown';
      
      // 1. Try cloud backup first
      if (currentUser != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          final cloudBackup = await firestore
              .collection('user_backups')
              .doc(currentUser.uid)
              .get();
          
          if (cloudBackup.exists && cloudBackup.data() != null) {
            backupData = cloudBackup.data();
            backupSource = 'cloud';
            print('SyncService: Using cloud backup for summary');
          }
        } catch (e) {
          print('SyncService: Cloud backup summary failed: $e');
        }
      }
      
      // 2. Fall back to local backup
      if (backupData == null) {
        final backupKey = '$_userDataBackupPrefix$userEmail';
        final backupDataString = await _storage.read(key: backupKey);
        
        if (backupDataString != null) {
          backupData = jsonDecode(backupDataString) as Map<String, dynamic>;
          backupSource = 'local';
          print('SyncService: Using local backup for summary');
        }
      }
      
      if (backupData == null) return null;

      final passwords = backupData['passwords'] as List? ?? [];
      final links = backupData['links'] as List? ?? [];
      final backupDate = backupData['backupDate'] as String?;

      return {
        'passwordCount': passwords.length,
        'linkCount': links.length,
        'backupDate': backupDate,
        'userEmail': userEmail,
        'backupSource': backupSource, // 'cloud' or 'local'
      };
    } catch (e) {
      print('SyncService: Error getting backup summary: $e');
      return null;
    }
  }

  /// Restore user data from backup (cloud first, then local)
  static Future<bool> restoreUserData(String userEmail) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? backupData;
      String restoredFrom = 'unknown';
      
      // 1. Try cloud restore first
      if (currentUser != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          final cloudBackup = await firestore
              .collection('user_backups')
              .doc(currentUser.uid)
              .get();
          
          if (cloudBackup.exists && cloudBackup.data() != null) {
            final encryptedData = cloudBackup.data()!;
            if (encryptedData.containsKey('c')) {
              backupData = EncryptionService.decryptRecordSync(encryptedData);
            } else {
              backupData = encryptedData; // Fallback for legacy plaintext backups
            }
            restoredFrom = 'cloud';
            print('SyncService: Restoring from cloud backup');
          }
        } catch (e) {
          print('SyncService: Cloud restore failed: $e');
        }
      }
      
      // 2. Fall back to local restore
      if (backupData == null) {
        final backupKey = '$_userDataBackupPrefix$userEmail';
        final backupDataString = await _storage.read(key: backupKey);
        
        if (backupDataString != null) {
          backupData = jsonDecode(backupDataString) as Map<String, dynamic>;
          restoredFrom = 'local';
          print('SyncService: Restoring from local backup');
        }
      }
      
      if (backupData == null) {
        print('SyncService: No backup data found for user $userEmail');
        return false;
      }

      // Clear current data before restoring
      await StorageService.clearAllData();

      // Restore passwords
      if (backupData.containsKey('passwords')) {
        final passwords = (backupData['passwords'] as List)
            .map((p) => PasswordEntry.fromJson(p))
            .toList();
        
        for (final password in passwords) {
          await StorageService.addPassword(
            name: password.name,
            username: password.username,
            password: password.password,
            url: password.url,
            notes: password.notes,
            category: password.category,
          );
        }
      }

      // Restore links
      if (backupData.containsKey('links')) {
        final links = (backupData['links'] as List)
            .map((l) => LinkEntry.fromJson(l))
            .toList();
        
        for (final link in links) {
          await StorageService.addLink(
            title: link.title,
            description: link.description,
            url: link.url,
            category: link.category,
          );
        }
      }

      print('SyncService: Successfully restored data from $restoredFrom for user $userEmail');
      return true;
    } catch (e) {
      print('SyncService: Failed to restore user data: $e');
      return false;
    }
  }

  /// Delete backup data for a user
  static Future<bool> deleteBackupData(String userEmail) async {
    try {
      final backupKey = '$_userDataBackupPrefix$userEmail';
      await _storage.delete(key: backupKey);
      print('SyncService: Deleted backup data for user $userEmail');
      return true;
    } catch (e) {
      print('SyncService: Failed to delete backup data: $e');
      return false;
    }
  }

  /// Get the last user email that was signed in
  static Future<String?> getLastUserEmail() async {
    try {
      return await _storage.read(key: _lastUserEmailKey);
    } catch (e) {
      print('SyncService: Error getting last user email: $e');
      return null;
    }
  }

  /// Check if current user is returning (same email as last login)
  static Future<bool> isReturningUser(String currentEmail) async {
    try {
      final lastEmail = await getLastUserEmail();
      return lastEmail != null && lastEmail == currentEmail;
    } catch (e) {
      print('SyncService: Error checking if returning user: $e');
      return false;
    }
  }

  /// Sync current local data to cloud (called after sign-in)
  static Future<bool> syncLocalDataToCloud() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('SyncService: Cannot sync to cloud - user not authenticated');
        return false;
      }

      final passwords = await getAllPasswords();
      final links = await getAllLinks();
      
      // Only sync if there's local data
      if (passwords.isEmpty && links.isEmpty) {
        print('SyncService: No local data to sync to cloud');
        return true;
      }

      final syncData = {
        'passwords': passwords.map((p) => p.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
        'lastSyncDate': DateTime.now().toIso8601String(),
        'userEmail': currentUser.email,
        'deviceInfo': 'flutter_app',
      };

      final firestore = FirebaseFirestore.instance;
      final encryptedSyncData = EncryptionService.encryptRecordSync(syncData);
      await firestore
          .collection('user_backups')
          .doc(currentUser.uid)
          .set(encryptedSyncData);

      print('SyncService: Successfully synced ${passwords.length} passwords and ${links.length} links to cloud');
      return true;
    } catch (e) {
      print('SyncService: Failed to sync local data to cloud: $e');
      return false;
    }
  }

  /// Download and merge cloud data with local data (called during sign-in)
  static Future<bool> mergeCloudDataWithLocal() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('SyncService: Cannot merge cloud data - user not authenticated');
        return false;
      }

      final firestore = FirebaseFirestore.instance;
      final cloudBackup = await firestore
          .collection('user_backups')
          .doc(currentUser.uid)
          .get();

      if (!cloudBackup.exists || cloudBackup.data() == null) {
        print('SyncService: No cloud data to merge');
        return true;
      }

      final rawData = cloudBackup.data()!;
      final cloudData = rawData.containsKey('c') ? EncryptionService.decryptRecordSync(rawData) : rawData;
      final localPasswords = await getAllPasswords();
      final localLinks = await getAllLinks();

      // Get cloud data
      final cloudPasswords = (cloudData['passwords'] as List? ?? [])
          .map((p) => PasswordEntry.fromJson(p))
          .toList();
      final cloudLinks = (cloudData['links'] as List? ?? [])
          .map((l) => LinkEntry.fromJson(l))
          .toList();

      // Merge logic: Add cloud items that don't exist locally
      for (final cloudPassword in cloudPasswords) {
        final exists = localPasswords.any((local) => 
            local.name == cloudPassword.name && 
            local.username == cloudPassword.username);
        
        if (!exists) {
          await StorageService.addPassword(
            id: cloudPassword.id,
            name: cloudPassword.name,
            username: cloudPassword.username,
            password: cloudPassword.password,
            url: cloudPassword.url,
            notes: cloudPassword.notes,
            category: cloudPassword.category,
          );
        }
      }

      for (final cloudLink in cloudLinks) {
        final exists = localLinks.any((local) => 
            local.title == cloudLink.title && 
            local.url == cloudLink.url);
        
        if (!exists) {
          await StorageService.addLink(
            id: cloudLink.id,
            title: cloudLink.title,
            description: cloudLink.description,
            url: cloudLink.url,
            category: cloudLink.category,
          );
        }
      }

      print('SyncService: Successfully merged cloud data with local data');
      return true;
    } catch (e) {
      print('SyncService: Failed to merge cloud data: $e');
      return false;
    }
  }
}
