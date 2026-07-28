import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interview_prep/core/config/app_config.dart';
import 'package:interview_prep/features/dashboard/presentation/screens/detail_screen.dart';
import 'package:interview_prep/features/splash/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen rendering test', (WidgetTester tester) async {
    AppConfig.setMockValues(
      enableLogin: true,
      enableSocialLogin: true,
      enableFirebaseDynamicAuth: false,
      enableFirebaseDatabase: false,
      enableAds: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SplashScreen(
            onToggleTheme: () {},
            isDarkMode: true,
          ),
        ),
      ),
    );

    // Verify title is rendered
    expect(find.text('Modular Base Template'), findsOneWidget);
    expect(find.text('Clean Architecture • Riverpod • Multi-Feature'), findsOneWidget);

    // Verify logo container icon is visible
    expect(find.byIcon(Icons.architecture_rounded), findsOneWidget);

    // Advance the test virtual clock to let the SplashScreen 2.8s transition Timer fire and clear.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('DetailScreen rendering test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DetailScreen(
          id: 'test_module',
          title: 'Test Module Title',
          description: 'Test Module Description content.',
          icon: Icons.ac_unit_rounded,
          color: Colors.blue,
        ),
      ),
    );

    // Verify title and description are rendered
    expect(find.text('Test Module Title'), findsOneWidget);
    expect(find.text('Test Module Description content.'), findsOneWidget);

    // Verify telemetry table contains diagnostics labels
    expect(find.text('Operational Status'), findsOneWidget);
    expect(find.text('Healthy'), findsOneWidget);
  });
}
