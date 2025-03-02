import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/task_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final TaskRepository _taskRepository;

  late StreamSubscription<User?> _authSubscription;

  AuthBloc(
      {required AuthRepository authRepository,
      required TaskRepository taskRepository})
      : _authRepository = authRepository,
        _taskRepository = taskRepository,
        super(AuthState.initial()) {
    on<AppStarted>(_onAppStarted);
    on<EmailSignInRequested>(_onEmailSignInRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<AuthStateChanged>(_onAuthStateChanged);

    _authSubscription = _authRepository.authStateChanges.listen((user) {
      add(AuthStateChanged(
        isAuthenticated: user != null,
        userId: user?.uid,
      ));
    });
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final currentUser = _authRepository.currentUser;
    if (currentUser != null) {
      emit(AuthState.authenticated(currentUser.uid));
    } else {
      emit(AuthState.unauthenticated());
    }
  }

  Future<void> _onEmailSignInRequested(
      EmailSignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthState.loading());
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      if (user != null) {
        emit(AuthState.authenticated(user.uid));
      } else {
        emit(AuthState.error('Failed to sign in. Please try again.'));
      }
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(
      GoogleSignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthState.loading());
    try {
      final user = await _authRepository.signInWithGoogle();
      if (user != null) {
        emit(AuthState.authenticated(user.uid));
      } else {
        emit(AuthState.error(
            'Failed to sign in with Google. Please try again.'));
      }
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  Future<void> _onSignUpRequested(
      SignUpRequested event, Emitter<AuthState> emit) async {
    emit(AuthState.loading());
    try {
      final user = await _authRepository.signUpWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      if (user != null) {
        emit(AuthState.authenticated(user.uid));
      } else {
        emit(AuthState.error('Failed to create account. Please try again.'));
      }
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  void _onAuthStateChanged(
      AuthStateChanged event, Emitter<AuthState> emit) async {
    if (event.isAuthenticated && event.userId != null) {
      print('Auth state changed: User authenticated with ID ${event.userId}');

      _taskRepository.isSigningOut = false;

      emit(AuthState.authenticated(event.userId!));

      try {
        await _taskRepository.init(event.userId!);
        print('Task repository initialized on auth state change');
      } catch (e) {
        print('Error initializing task repository on auth state change: $e');
      }
    } else {
      print('Auth state changed: User not authenticated');
      emit(AuthState.unauthenticated());
    }
  }

  Future<void> _onSignOutRequested(
      SignOutRequested event, Emitter<AuthState> emit) async {
    print('Sign out requested');
    emit(AuthState.loading());

    try {
      await _authSubscription.cancel();
      print('Auth subscription cancelled');

      _taskRepository.isSigningOut = true;
      print('Task repository marked as signing out');

      print('Sign-out process: Resetting task repository...');
      try {
        await _taskRepository.reset();
        print('Sign-out process: Task repository reset complete');
      } catch (e) {
        print('Error during task repository reset: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      print('Sign-out process: Signing out from Firebase Auth...');
      await _authRepository.signOut();
      print('Sign-out process: Firebase Auth sign-out complete');

      _taskRepository.isSigningOut = false;
      print('Task repository signing out flag reset');

      emit(AuthState.unauthenticated());
      print('Auth state set to unauthenticated');

      _authSubscription = _authRepository.authStateChanges.listen((user) {
        add(AuthStateChanged(
          isAuthenticated: user != null,
          userId: user?.uid,
        ));
      });
      print('Auth subscription re-established');
    } catch (e) {
      print('Error during sign-out: $e');
      emit(AuthState.unauthenticated());

      _taskRepository.isSigningOut = false;
      print('Task repository signing out flag reset (after error)');

      try {
        _authSubscription = _authRepository.authStateChanges.listen((user) {
          add(AuthStateChanged(
            isAuthenticated: user != null,
            userId: user?.uid,
          ));
        });
        print('Auth subscription re-established (after error)');
      } catch (error) {
        print('Error re-establishing auth subscription: $error');
      }
    }
  }

  Future<void> _onResetPasswordRequested(
      ResetPasswordRequested event, Emitter<AuthState> emit) async {
    emit(AuthState.loading());
    try {
      await _authRepository.resetPassword(email: event.email);
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Password reset email sent. Please check your inbox.',
      ));
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
