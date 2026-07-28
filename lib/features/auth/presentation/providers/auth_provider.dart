import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    this.errorMessage,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: false,
      errorMessage: null,
      email: null,
      displayName: null,
      photoUrl: null,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // can clear by passing null
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    if (!AppConfig.enableLogin) {
      return const AuthState(
        isAuthenticated: true,
        isLoading: false,
        email: 'guest@example.com',
        displayName: 'Guest User',
        photoUrl: null,
      );
    }
    return AuthState.initial();
  }

  Future<void> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (AppConfig.enableFirebaseDynamicAuth) {
        // Firebase Auth sign-in integration placeholder
      } else {
        await Future.delayed(const Duration(milliseconds: 1200));

        if (email.contains('@') && password.length >= 6) {
          state = state.copyWith(
            isAuthenticated: true,
            isLoading: false,
            email: email,
            displayName: email.split('@')[0].toUpperCase(),
          );
        } else {
          throw Exception('Invalid credentials. Password must be at least 6 characters.');
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loginWithGoogle() async {
    if (!AppConfig.enableSocialLogin) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (AppConfig.enableFirebaseDynamicAuth) {
        // Firebase Google Sign-In integration placeholder
      } else {
        await Future.delayed(const Duration(milliseconds: 1500));
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          email: 'google.dev@example.com',
          displayName: 'Google Developer',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loginWithApple() async {
    if (!AppConfig.enableSocialLogin) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (AppConfig.enableFirebaseDynamicAuth) {
        // Firebase Apple Sign-In integration placeholder
      } else {
        await Future.delayed(const Duration(milliseconds: 1500));
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          email: 'apple.dev@example.com',
          displayName: 'Apple Developer',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      if (AppConfig.enableFirebaseDynamicAuth) {
        // Firebase Sign-out integration placeholder
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      state = AuthState.initial();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
