import 'package:firebase_auth/firebase_auth.dart';

import '../services/storage/firebase_auth_service.dart';
import '../repositories/user_repository.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final FirebaseAuthService _authService;
  final UserRepository _userRepository;

  AuthRepository({
    required FirebaseAuthService authService,
    required UserRepository userRepository,
  })  : _authService = authService,
        _userRepository = userRepository;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  User? get currentUser => _authService.currentUser;

  bool get isSignedIn => currentUser != null;

  String? get userId => currentUser?.uid;

  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (user != null) {
      await _createOrGetUserProfile(user);
    }

    return user;
  }

  Future<User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = await _authService.signUpWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (user != null) {
      await _createOrGetUserProfile(user);
    }

    return user;
  }

  Future<User?> signInWithGoogle() async {
    final user = await _authService.signInWithGoogle();

    if (user != null) {
      await _createOrGetUserProfile(user);
    }

    return user;
  }

  Future<void> signOut() async {
    print('FirebaseAuthService: Starting sign-out process...');
    try {
      await FirebaseAuth.instance.signOut();
      print('FirebaseAuthService: Successfully signed out from Firebase Auth');
    } catch (e) {
      print('FirebaseAuthService: Error during sign-out: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> resetPassword({required String email}) async {
    await _authService.resetPassword(email: email);
  }

  Future<UserProfile?> _createOrGetUserProfile(User user) async {
    UserProfile? profile = await _userRepository.getCurrentUserProfile();

    if (profile == null) {
      profile = UserProfile.create(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? user.email?.split('@')[0] ?? 'User',
        photoUrl: user.photoURL,
      );

      await _userRepository.saveUserProfile(profile);
    }

    return profile;
  }
}
