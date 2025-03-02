import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    Logger? logger,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      return user;
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    } catch (e) {
      throw Exception(
          'An unexpected error occurred during sign in. Please try again.');
    }
  }

  Future<User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      return user;
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    } catch (e) {
      throw Exception(
          'An unexpected error occurred during sign up. Please try again.');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was canceled by user');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens from Google');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken!,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final User? user = userCredential.user;

      return user;
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    } catch (e) {
      throw Exception('Google sign in failed. Please try again later.');
    }
  }

  Future<void> signOut() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Error signing out of Google: $e');
      }

      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out. Please try again later.');
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred. Please try again later.');
    }
  }

  Exception _getAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return Exception('The email address is not valid.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'user-not-found':
        return Exception('No account found with this email.');
      case 'wrong-password':
        return Exception('Incorrect password. Please try again.');
      case 'email-already-in-use':
        return Exception('An account already exists with this email.');
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'operation-not-allowed':
        return Exception('This operation is not allowed.');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection.');
      case 'too-many-requests':
        return Exception(
            'Too many unsuccessful login attempts. Please try again later.');
      case 'account-exists-with-different-credential':
        return Exception(
            'An account already exists with the same email but different sign-in credentials.');
      case 'invalid-credential':
        return Exception('The provided credentials are invalid or expired.');
      default:
        return Exception(
            'An error occurred. Please try again later. (${e.code})');
    }
  }
}
