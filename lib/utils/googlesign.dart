import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInService {
  static GoogleSignIn? _googleSignIn;
  static FirebaseAuth? _firebaseAuth;

  static Future<void> initialize() async {
    try {
      _firebaseAuth = FirebaseAuth.instance;
      
      // Configure Google Sign-In with your Firebase project's web client ID
      _googleSignIn = GoogleSignIn(
        serverClientId: '795878816417-a5jab510h6c0nolcpcsvumt3nljao4bb.apps.googleusercontent.com',
        scopes: [
          'email',
          'profile',
        ],
      );
      
      // GoogleSignInService initialized successfully
    } catch (e) {
      print('GoogleSignInService initialization failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      print('GoogleSignInService: Starting Google Sign-In...');
      
      // Check if Google Play Services are available
      final googleUser = await _googleSignIn?.signIn();
      if (googleUser == null) {
        print('GoogleSignInService: User cancelled the sign-in');
        return null;
      }

      print('GoogleSignInService: Got Google user: ${googleUser.email}');
      
      final googleAuth = await googleUser.authentication;
      print('GoogleSignInService: Got authentication tokens');

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        print('GoogleSignInService: Missing tokens - accessToken: $accessToken, idToken: $idToken');
        throw Exception('Missing Google authentication tokens');
      }

      print('GoogleSignInService: Authenticating with Firebase...');
      
      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _firebaseAuth!.signInWithCredential(credential);

      print('GoogleSignInService: Firebase authentication successful');
      
      return {
        'user': userCredential.user,
        'credential': userCredential,
      };
    } catch (e, stackTrace) {
      print('GoogleSignInService: Error during sign-in: $e');
      print('GoogleSignInService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      await _firebaseAuth?.signOut();
      print('GoogleSignInService: Successfully signed out');
    } catch (e) {
      print('GoogleSignInService: Error signing out: $e');
      rethrow;
    }
  }

  static Future<bool> isSignedIn() async {
    try {
      final googleUser = await _googleSignIn?.isSignedIn() ?? false;
      final firebaseUser = _firebaseAuth?.currentUser;
      return googleUser && firebaseUser != null;
    } catch (e) {
      print('GoogleSignInService: Error checking sign-in status: $e');
      return false;
    }
  }

  static User? getCurrentUser() {
    return _firebaseAuth?.currentUser;
  }
}
