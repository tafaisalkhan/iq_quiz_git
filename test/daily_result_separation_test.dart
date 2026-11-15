import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interview_prep/core/config/app_config.dart';
import 'package:interview_prep/core/services/daily_quiz_service.dart';
import 'package:interview_prep/features/dashboard/presentation/screens/detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final daily in [true, false]) {
    testWidgets(
      daily
          ? 'daily completion stays out of normal results'
          : 'normal completion enters normal results',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        AppConfig.setMockValues(
          enableLogin: false,
          enableSocialLogin: false,
          enableFirebaseDynamicAuth: false,
          enableFirebaseDatabase: false,
          enableAds: false,
        );
        final day = DateTime.now();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: DetailScreen(
                id: daily ? 'daily_quiz' : 'normal',
                title: daily ? 'Daily Quiz' : 'Normal Quiz',
                description: 'One question',
                icon: Icons.quiz,
                color: Colors.blue,
                isDailyChallenge: daily,
                onQuizCompleted: daily
                    ? (score, total) =>
                          DailyQuizService().saveResult(day, score, total)
                    : null,
                questions: const [
                  {
                    'questionText': 'Choose the right answer',
                    'options': ['Wrong', 'Right'],
                    'correctOptionIndex': 1,
                    'explanation': 'Right is correct.',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.text('Right'));
        await tester.tap(find.text('Right'));
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.text('Finish Quiz'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final prefs = await SharedPreferences.getInstance();
        final normalResults = prefs.getStringList('quiz_results') ?? [];
        final dailyResult = (await DailyQuizService().loadHistory()).resultFor(
          day,
        );
        expect(normalResults.length, daily ? 0 : 1);
        expect(dailyResult?.score, daily ? 1 : null);
      },
    );
  }
}
