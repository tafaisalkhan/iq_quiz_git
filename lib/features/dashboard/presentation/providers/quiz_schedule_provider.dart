import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';

class QuizSchedule {
  final String id;
  final String categoryId;
  final String categoryTitle;
  final int questionsCount;
  final String timeOfDay; // Format "HH:MM" e.g., "14:30"

  QuizSchedule({
    required this.id,
    required this.categoryId,
    required this.categoryTitle,
    required this.questionsCount,
    required this.timeOfDay,
  });
}

class TestResult {
  final String id;
  final String categoryTitle;
  final int score;
  final int totalQuestions;
  final DateTime date;

  TestResult({
    required this.id,
    required this.categoryTitle,
    required this.score,
    required this.totalQuestions,
    required this.date,
  });
}

class QuizScheduleState {
  final List<QuizSchedule> schedules;
  final List<TestResult> results;
  final int remainingQuizzes;

  QuizScheduleState({
    this.schedules = const [],
    this.results = const [],
    this.remainingQuizzes = 2,
  });

  QuizScheduleState copyWith({
    List<QuizSchedule>? schedules,
    List<TestResult>? results,
    int? remainingQuizzes,
  }) {
    return QuizScheduleState(
      schedules: schedules ?? this.schedules,
      results: results ?? this.results,
      remainingQuizzes: remainingQuizzes ?? this.remainingQuizzes,
    );
  }
}

class QuizScheduleNotifier extends Notifier<QuizScheduleState> {
  Timer? _scheduleCheckerTimer;

  @override
  QuizScheduleState build() {
    _loadFromPrefs();
    ref.onDispose(() {
      _scheduleCheckerTimer?.cancel();
    });
    return QuizScheduleState(schedules: [], results: [], remainingQuizzes: 2);
  }

  void startScheduleChecker(BuildContext context) {
    _scheduleCheckerTimer?.cancel();
    _scheduleCheckerTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) async {
      final now = DateTime.now();
      final currentHHmm =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final todayStr = now.toIso8601String().split('T')[0];

      try {
        final prefs = await SharedPreferences.getInstance();
        for (final schedule in state.schedules) {
          if (schedule.timeOfDay == currentHHmm) {
            final fireKey = 'sched_fired_${schedule.id}_$todayStr';
            final alreadyFired = prefs.getBool(fireKey) ?? false;
            if (!alreadyFired) {
              await prefs.setBool(fireKey, true);

              // Trigger native Android status bar notification
              NotificationService().showImmediateNativeNotification(
                id: schedule.id.hashCode,
                title: 'Scheduled Quiz Ready! ⏰',
                body:
                    'It\'s time for your scheduled ${schedule.categoryTitle} quiz! (${schedule.questionsCount} questions)',
              );

              if (context.mounted) {
                NotificationService().showNotification(
                  context,
                  title: 'Scheduled Quiz Ready! ⏰',
                  message:
                      'It\'s time for your scheduled ${schedule.categoryTitle} quiz! (${schedule.questionsCount} questions)',
                  icon: Icons.alarm_on_rounded,
                  duration: const Duration(seconds: 8),
                );
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load schedules
      final schedulesJson = prefs.getStringList('quiz_schedules') ?? [];
      final loadedSchedules = schedulesJson.map((s) {
        final map = json.decode(s) as Map<String, dynamic>;
        return QuizSchedule(
          id: map['id'] as String,
          categoryId: map['categoryId'] as String,
          categoryTitle: map['categoryTitle'] as String,
          questionsCount: map['questionsCount'] as int,
          timeOfDay: map['timeOfDay'] as String,
        );
      }).toList();

      // Load results
      final resultsJson = prefs.getStringList('quiz_results') ?? [];
      final loadedResults = resultsJson
          .map((r) {
            final map = json.decode(r) as Map<String, dynamic>;
            return TestResult(
              id: map['id'] as String,
              categoryTitle: map['categoryTitle'] as String,
              score: map['score'] as int,
              totalQuestions: map['totalQuestions'] as int,
              date: DateTime.parse(map['date'] as String),
            );
          })
          .where((result) => result.categoryTitle != 'Daily Quiz')
          .toList();

      // Always reset to 2 free quizzes on app startup/restart
      state = QuizScheduleState(
        schedules: loadedSchedules,
        results: loadedResults,
        remainingQuizzes: 2,
      );
    } catch (_) {
      // Fallback
    }
  }

  Future<void> _saveSchedulesToPrefs(List<QuizSchedule> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = list
          .map(
            (s) => json.encode({
              'id': s.id,
              'categoryId': s.categoryId,
              'categoryTitle': s.categoryTitle,
              'questionsCount': s.questionsCount,
              'timeOfDay': s.timeOfDay,
            }),
          )
          .toList();
      await prefs.setStringList('quiz_schedules', stringList);
    } catch (_) {}
  }

  Future<void> _saveResultsToPrefs(List<TestResult> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = list
          .map(
            (r) => json.encode({
              'id': r.id,
              'categoryTitle': r.categoryTitle,
              'score': r.score,
              'totalQuestions': r.totalQuestions,
              'date': r.date.toIso8601String(),
            }),
          )
          .toList();
      await prefs.setStringList('quiz_results', stringList);
    } catch (_) {}
  }

  Future<void> _saveRemainingQuizzes(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('remaining_quizzes', value);
    } catch (_) {}
  }

  bool addSchedule(QuizSchedule schedule) {
    if (state.schedules.length >= 2) {
      return false; // Limit to max 2 schedules
    }
    final newSchedules = [...state.schedules, schedule];
    state = state.copyWith(schedules: newSchedules);
    _saveSchedulesToPrefs(newSchedules);

    // Schedule native Android status bar notification even when app is closed
    try {
      final parts = schedule.timeOfDay.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        NotificationService().scheduleNativeDailyNotification(
          id: schedule.id.hashCode,
          title: 'Scheduled Quiz Ready! ⏰',
          body:
              'It\'s time for your scheduled ${schedule.categoryTitle} quiz! Tap to start.',
          hour: hour,
          minute: minute,
        );
      }
    } catch (_) {}

    return true;
  }

  void removeSchedule(String id) {
    final newSchedules = state.schedules.where((s) => s.id != id).toList();
    state = state.copyWith(schedules: newSchedules);
    _saveSchedulesToPrefs(newSchedules);

    // Cancel native notification
    try {
      NotificationService().cancelNativeNotification(id.hashCode);
    } catch (_) {}
  }

  void addResult(TestResult result) {
    final newResults = [result, ...state.results];
    state = state.copyWith(results: newResults);
    _saveResultsToPrefs(newResults);
  }

  void decrementRemainingQuizzes() {
    final newValue = state.remainingQuizzes > 0
        ? state.remainingQuizzes - 1
        : 0;
    state = state.copyWith(remainingQuizzes: newValue);
    _saveRemainingQuizzes(newValue);
  }

  void incrementRemainingQuizzes() {
    final newValue = state.remainingQuizzes + 1;
    state = state.copyWith(remainingQuizzes: newValue);
    _saveRemainingQuizzes(newValue);
  }
}

final quizScheduleProvider =
    NotifierProvider<QuizScheduleNotifier, QuizScheduleState>(
      QuizScheduleNotifier.new,
    );
