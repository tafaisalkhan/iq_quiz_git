import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interview_prep/features/dashboard/presentation/screens/detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final selected in ['Wrong choice', 'Right choice']) {
    testWidgets('review shows both answers after selecting $selected', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DetailScreen(
              id: 'test',
              title: 'Test',
              description: 'Test question',
              icon: Icons.quiz,
              color: Colors.blue,
              questions: const [
                {
                  'questionText': 'Which choice is correct?',
                  'options': ['Wrong choice', 'Right choice'],
                  'correctOptionIndex': 1,
                  'explanation': 'The right choice follows the stated rule.',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text(selected));
      await tester.tap(find.text(selected));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('YOUR ANSWER'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('YOUR ANSWER'), findsOneWidget);
      expect(find.text('CORRECT ANSWER'), findsOneWidget);
      expect(
        find.text('The right choice follows the stated rule.'),
        findsOneWidget,
      );
      if (selected == 'Wrong choice') {
        expect(find.text('WHY YOUR ANSWER IS INCORRECT'), findsOneWidget);
      }
    });
  }
}
