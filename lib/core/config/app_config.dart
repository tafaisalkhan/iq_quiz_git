import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._();

  static bool _enableLogin = true;
  static bool _enableSocialLogin = true;
  static bool _enableFirebaseDynamicAuth = false;
  static bool _enableFirebaseDatabase = false;
  static bool _enableAds = true;
  static bool _isInitialized = false;

  /// Whether user authentication is required at startup.
  static bool get enableLogin => _enableLogin;

  /// Whether social logins (Google, Apple) are shown on the LoginScreen.
  static bool get enableSocialLogin => _enableSocialLogin;

  /// Whether to use real Firebase Auth services.
  static bool get enableFirebaseDynamicAuth => _enableFirebaseDynamicAuth;

  /// Whether to use real Firebase Firestore/Realtime Database services.
  static bool get enableFirebaseDatabase => _enableFirebaseDatabase;

  /// Whether to enable advertisements globally across all screens.
  static bool get enableAds => _enableAds;

  /// Check if the configuration has been loaded.
  static bool get isInitialized => _isInitialized;

  /// Loads configuration from the JSON properties asset file and runs validation.
  static Future<void> initialize() async {
    try {
      final jsonString = await rootBundle.loadString('assets/config/app_properties.json');
      final Map<String, dynamic> config = json.decode(jsonString);

      _enableLogin = config['enableLogin'] ?? true;
      _enableSocialLogin = config['enableSocialLogin'] ?? true;
      _enableFirebaseDynamicAuth = config['enableFirebaseDynamicAuth'] ?? false;
      _enableFirebaseDatabase = config['enableFirebaseDatabase'] ?? false;
      _enableAds = config['enableAds'] ?? true;
      _isInitialized = true;

      _validate();
      print('=== AppConfig Initialized successfully ===');
      print('enableLogin: $_enableLogin');
      print('enableSocialLogin: $_enableSocialLogin');
      print('enableFirebaseDynamicAuth: $_enableFirebaseDynamicAuth');
      print('enableFirebaseDatabase: $_enableFirebaseDatabase');
      print('enableAds: $_enableAds');
      print('==========================================');
    } catch (e) {
      print('Error initializing AppConfig: $e. Falling back to default values.');
      _isInitialized = true;
      _validate();
    }
  }

  /// Manually override values (especially useful for unit testing)
  static void setMockValues({
    required bool enableLogin,
    required bool enableSocialLogin,
    required bool enableFirebaseDynamicAuth,
    required bool enableFirebaseDatabase,
    required bool enableAds,
  }) {
    _enableLogin = enableLogin;
    _enableSocialLogin = enableSocialLogin;
    _enableFirebaseDynamicAuth = enableFirebaseDynamicAuth;
    _enableFirebaseDatabase = enableFirebaseDatabase;
    _enableAds = enableAds;
    _isInitialized = true;
    _validate();
  }

  /// Validates application properties on startup to prevent illogical configurations.
  static void _validate() {
    // Validation Rule 1: If social login is enabled, login require must also be enabled.
    if (_enableSocialLogin && !_enableLogin) {
      print('AppConfig Validation Warning: enableSocialLogin is active but enableLogin is disabled. Social login will be bypassed.');
      _enableSocialLogin = false;
    }

    // Validation Rule 2: If Firebase Auth is enabled, login must also be enabled.
    if (_enableFirebaseDynamicAuth && !_enableLogin) {
      print('AppConfig Validation Warning: enableFirebaseDynamicAuth is active but enableLogin is disabled. Firebase Auth will be bypassed.');
      _enableFirebaseDynamicAuth = false;
    }
  }
}
