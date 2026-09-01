import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/googlesign.dart';
import 'sync_service.dart';

class FirebaseAuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Storage keys
  static const String _userSignedInKey = 'user_signed_in';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';

  // Get current user
  static User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // Initialize and check auth state
  static Future<void> initialize() async {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Save user info to secure storage
        await _saveUserData(user);
      } else {
        // Clear user data from storage
        await _clearUserData();
      }
    });
  }

  // Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      print('FirebaseAuthService: Starting Google Sign-In...');
      
      final result = await GoogleSignInService.signInWithGoogle();
      
      if (result != null) {
        final user = result['user'] as User?;
        if (user != null) {
          await _saveUserData(user);
          print('FirebaseAuthService: Sign-in successful for ${user.email}');
          
          return AuthResult(
            success: true,
            user: user,
            message: 'Successfully signed in with Google',
          );
        }
      }
      
      return AuthResult(
        success: false,
        message: 'Google Sign-In was cancelled or failed',
      );
    } catch (e) {
      print('FirebaseAuthService: Error during Google Sign-In: $e');
      return AuthResult(
        success: false,
        message: 'Error signing in: ${e.toString()}',
      );
    }
  }

  // Sign out
  static Future<AuthResult> signOut() async {
    try {
      // Backup user data before signing out
      final currentUser = _auth.currentUser;
      if (currentUser?.email != null) {
        await SyncService.backupUserData(currentUser!.email!);
      }
      
      await GoogleSignInService.signOut();
      await _clearUserData();
      
      return AuthResult(
        success: true,
        message: 'Successfully signed out',
      );
    } catch (e) {
      print('FirebaseAuthService: Error during sign out: $e');
      return AuthResult(
        success: false,
        message: 'Error signing out: ${e.toString()}',
      );
    }
  }

  // Get stored user data
  static Future<Map<String, String?>> getStoredUserData() async {
    return {
      'email': await _storage.read(key: _userEmailKey),
      'name': await _storage.read(key: _userNameKey),
      'id': await _storage.read(key: _userIdKey),
    };
  }

  // Save user data to secure storage
  static Future<void> _saveUserData(User user) async {
    await _storage.write(key: _userSignedInKey, value: 'true');
    await _storage.write(key: _userEmailKey, value: user.email ?? '');
    await _storage.write(key: _userNameKey, value: user.displayName ?? '');
    await _storage.write(key: _userIdKey, value: user.uid);
  }

  // Clear user data from storage
  static Future<void> _clearUserData() async {
    await SyncService.clearAllData();
    await _storage.delete(key: _userSignedInKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userIdKey);
  }

  // Check if user data exists in storage (for offline check)
  static Future<bool> hasStoredUserData() async {
    final signedIn = await _storage.read(key: _userSignedInKey);
    return signedIn == 'true';
  }

  // Check if returning user has backup data
  static Future<Map<String, dynamic>?> checkBackupData(String email) async {
    try {
      final hasBackup = await SyncService.hasBackupData(email);
      if (hasBackup) {
        return await SyncService.getBackupSummary(email);
      }
      return null;
    } catch (e) {
      print('FirebaseAuthService: Error checking backup data: $e');
      return null;
    }
  }

  // Restore user data from backup
  static Future<bool> restoreUserData(String email) async {
    try {
      return await SyncService.restoreUserData(email);
    } catch (e) {
      print('FirebaseAuthService: Error restoring user data: $e');
      return false;
    }
  }
}

// Result class for auth operations
class AuthResult {
  final bool success;
  final User? user;
  final String message;

  AuthResult({
    required this.success,
    this.user,
    required this.message,
  });
}
