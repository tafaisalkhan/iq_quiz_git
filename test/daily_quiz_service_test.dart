import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interview_prep/core/services/daily_quiz_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('daily completion is saved once and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DailyQuizService();
    final day = DateTime.now();

    final before = await service.loadHistory();
    expect(before.resultFor(day), isNull);

    await service.saveResult(day, 4, 5);
    await service.saveResult(day, 1, 5);

    final after = await service.loadHistory();
    expect(after.resultFor(day)?.score, 4);
    expect(after.resultFor(day)?.total, 5);
    expect(DailyQuizService.dayKey(after.startDate), DailyQuizService.dayKey(day));
  });

  test('completed daily questions are tracked separately from regular quizzes', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DailyQuizService();
    final day = DateTime(2026, 10, 26);
    final questions = await service.questionsFor(day);
    expect(questions, isNotEmpty);
    final afterRestart = await DailyQuizService().questionsFor(day);
    expect(afterRestart.map((question) => question['questionText']),
        questions.map((question) => question['questionText']));

    await service.saveResult(day, 3, questions.length);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('daily_quiz_seen_questions')?.length, questions.length);
    expect(prefs.getKeys().where((key) => key.startsWith('q_seen_')), isEmpty);

    final nextQuestions = await service.questionsFor(day.add(const Duration(days: 1)));
    final firstTexts = questions.map((question) => question['questionText']).toSet();
    expect(nextQuestions.every((question) => !firstTexts.contains(question['questionText'])), isTrue);
  });
}
