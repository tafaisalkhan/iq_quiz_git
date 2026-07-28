import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState {
  final int questionTimerSeconds;
  final int quizQuestionCount;

  const AppSettingsState({
    required this.questionTimerSeconds,
    required this.quizQuestionCount,
  });

  factory AppSettingsState.initial() {
    return const AppSettingsState(
      questionTimerSeconds: 30,
      quizQuestionCount: 5,
    );
  }

  AppSettingsState copyWith({
    int? questionTimerSeconds,
    int? quizQuestionCount,
  }) {
    return AppSettingsState(
      questionTimerSeconds: questionTimerSeconds ?? this.questionTimerSeconds,
      quizQuestionCount: quizQuestionCount ?? this.quizQuestionCount,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() {
    _loadFromPrefs();
    return AppSettingsState.initial();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timerSecs = prefs.getInt('question_timer_seconds') ?? 30;
      final qCount = prefs.getInt('quiz_question_count') ?? 5;
      state = AppSettingsState(
        questionTimerSeconds: timerSecs,
        quizQuestionCount: qCount,
      );
    } catch (_) {}
  }

  Future<void> setQuestionTimerSeconds(int seconds) async {
    state = state.copyWith(questionTimerSeconds: seconds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('question_timer_seconds', seconds);
    } catch (_) {}
  }

  Future<void> setQuizQuestionCount(int count) async {
    state = state.copyWith(quizQuestionCount: count);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quiz_question_count', count);
    } catch (_) {}
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(AppSettingsNotifier.new);
