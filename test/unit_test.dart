import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_prep/core/config/app_config.dart';
import 'package:interview_prep/features/auth/presentation/providers/auth_provider.dart';
import 'package:interview_prep/features/settings/presentation/providers/ad_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    AppConfig.setMockValues(
      enableLogin: true,
      enableSocialLogin: true,
      enableFirebaseDynamicAuth: false,
      enableFirebaseDatabase: false,
      enableAds: true,
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthNotifier Base Template Unit Tests', () {
    test('initial state should be unauthenticated and idle', () {
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.email, isNull);
      expect(state.displayName, isNull);
      expect(state.errorMessage, isNull);
    });

    test('loginWithEmail handles success and updates AuthState data', () async {
      final notifier = container.read(authProvider.notifier);

      final loginFuture = notifier.loginWithEmail('dev@example.com', 'password123');

      // Verify that it went into loading state immediately
      expect(container.read(authProvider).isLoading, isTrue);

      await loginFuture;

      final state = container.read(authProvider);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isTrue);
      expect(state.email, equals('dev@example.com'));
      expect(state.displayName, equals('DEV'));
      expect(state.errorMessage, isNull);
    });

    test('loginWithEmail validates credentials and reports error on weak passwords', () async {
      final notifier = container.read(authProvider.notifier);

      await notifier.loginWithEmail('dev@example.com', '123'); // short password

      final state = container.read(authProvider);
      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.errorMessage, contains('must be at least 6 characters'));
    });

    test('logout clears credentials and resets state', () async {
      final notifier = container.read(authProvider.notifier);

      // Perform a successful login first
      await notifier.loginWithEmail('dev@example.com', 'password123');
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Perform logout
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.email, isNull);
      expect(state.displayName, isNull);
    });
  });

  group('AdNotifier Boilerplate Unit Tests', () {
    test('initial state should have ads enabled and zero coins', () {
      final state = container.read(adProvider);
      expect(state.isAdFreePurchased, isFalse);
      expect(state.userCoins, equals(0));
    });

    test('purchaseAdFree updates purchase flag state', () {
      final notifier = container.read(adProvider.notifier);

      notifier.purchaseAdFree(true);
      expect(container.read(adProvider).isAdFreePurchased, isTrue);

      notifier.purchaseAdFree(false);
      expect(container.read(adProvider).isAdFreePurchased, isFalse);
    });

    test('rewardUser increments coin balance correctly', () {
      final notifier = container.read(adProvider.notifier);

      notifier.rewardUser(50);
      expect(container.read(adProvider).userCoins, equals(50));

      notifier.rewardUser(25);
      expect(container.read(adProvider).userCoins, equals(75));
    });
  });

  group('AppConfig Boilerplate Unit Tests', () {
    test('validation corrects invalid state when social login is active but login is disabled', () {
      AppConfig.setMockValues(
        enableLogin: false,
        enableSocialLogin: true, // Invalid configuration combo
        enableFirebaseDynamicAuth: false,
        enableFirebaseDatabase: false,
        enableAds: true,
      );

      expect(AppConfig.enableLogin, isFalse);
      expect(AppConfig.enableSocialLogin, isFalse); // Auto-corrected by validate()!
    });

    test('validation corrects invalid state when Firebase Auth is active but login is disabled', () {
      AppConfig.setMockValues(
        enableLogin: false,
        enableSocialLogin: false,
        enableFirebaseDynamicAuth: true, // Invalid configuration combo
        enableFirebaseDatabase: false,
        enableAds: true,
      );

      expect(AppConfig.enableLogin, isFalse);
      expect(AppConfig.enableFirebaseDynamicAuth, isFalse); // Auto-corrected by validate()!
    });
  });
}
