import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import 'question_bank_service.dart';

class DailyQuizResult {
  final int score;
  final int total;

  const DailyQuizResult(this.score, this.total);
}

class DailyQuizHistory {
  final DateTime startDate;
  final Map<String, DailyQuizResult> results;

  const DailyQuizHistory(this.startDate, this.results);

  DailyQuizResult? resultFor(DateTime day) => results[DailyQuizService.dayKey(day)];
}

class DailyQuizService {
  static const _startKey = 'daily_quiz_start_date';
  static const _resultsKey = 'daily_quiz_results';
  static const _seenKey = 'daily_quiz_seen_questions';
  static const _assignmentsKey = 'daily_quiz_assignments';

  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<DailyQuizHistory> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final today = dayKey(DateTime.now());
    var start = prefs.getString(_startKey);
    if (start == null) {
      start = today;
      await prefs.setString(_startKey, start);
    }
    final saved = prefs.getString(_resultsKey);
    final raw = saved == null ? <String, dynamic>{} : json.decode(saved) as Map<String, dynamic>;
    final results = <String, DailyQuizResult>{};
    for (final entry in raw.entries) {
      final value = entry.value as Map<String, dynamic>;
      results[entry.key] = DailyQuizResult(value['score'] as int, value['total'] as int);
    }
    return DailyQuizHistory(DateTime.parse(start), results);
  }

  Future<void> saveResult(DateTime day, int score, int total) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_resultsKey);
    final results = saved == null ? <String, dynamic>{} : json.decode(saved) as Map<String, dynamic>;
    if (results.containsKey(dayKey(day))) return;
    results.putIfAbsent(dayKey(day), () => {'score': score, 'total': total});
    await prefs.setString(_resultsKey, json.encode(results));

    // Daily progress is independent of the regular quiz's q_seen_* keys.
    final assignments = _readAssignments(prefs);
    final seen = prefs.getStringList(_seenKey)?.toSet() ?? <String>{};
    seen.addAll(assignments[dayKey(day)] ?? const []);
    await prefs.setStringList(_seenKey, seen.toList());
  }

  Future<List<dynamic>> questionsFor(DateTime day) async {
    final response = await ApiClient().get('/items');
    final categories = response['data'] as List<dynamic>;
    final questions = <String, dynamic>{};
    for (final category in categories) {
      final categoryId = category['id'] as String;
      final categoryQuestions = await QuestionBankService().getAllQuestions(categoryId);
      for (var index = 0; index < categoryQuestions.length; index++) {
        questions['$categoryId:$index'] = categoryQuestions[index];
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final assignments = _readAssignments(prefs);
    final key = dayKey(day);
    var selected = assignments[key];
    if (selected == null || selected.any((id) => !questions.containsKey(id))) {
      final seen = prefs.getStringList(_seenKey)?.toSet() ?? <String>{};
      var available = questions.keys.where((id) => !seen.contains(id)).toList();
      if (available.isEmpty) {
        seen.clear();
        await prefs.remove(_seenKey);
        available = questions.keys.toList();
      }
      available.shuffle(Random(day.year * 10000 + day.month * 100 + day.day));
      selected = available.take(5).toList();
      assignments[key] = selected;
      await prefs.setString(_assignmentsKey, json.encode(assignments));
    }
    return selected.map((id) => questions[id]).toList();
  }

  Map<String, List<String>> _readAssignments(SharedPreferences prefs) {
    final saved = prefs.getString(_assignmentsKey);
    if (saved == null) return {};
    final raw = json.decode(saved) as Map<String, dynamic>;
    return raw.map((key, value) => MapEntry(key, List<String>.from(value as List)));
  }
}
