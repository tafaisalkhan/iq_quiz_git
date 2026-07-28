import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Service that manages question pools per category.
///
/// Algorithm:
/// 1. Load all questions for a category from the combined bank.
/// 2. Maintain a per-category "seen" list stored in SharedPreferences.
/// 3. On each quiz, pick [count] questions from the UNSEEN pool.
/// 4. When the unseen pool is empty (all questions exhausted), reshuffle
///    the full list and start again (seen list is cleared).
class QuestionBankService {
  static final QuestionBankService _instance = QuestionBankService._internal();
  factory QuestionBankService() => _instance;
  QuestionBankService._internal();

  // In-memory cache of the combined question bank: categoryId → list of questions
  Map<String, List<dynamic>>? _combinedBank;

  static const String _prefPrefix = 'q_seen_'; // key prefix: q_seen_<categoryId>
  static const String _prefOrder = 'q_order_'; // key prefix: q_order_<categoryId> (shuffled order)

  /// Load and cache the combined question bank (dashboard_items.json + questions_bank.json).
  Future<Map<String, List<dynamic>>> _getBank() async {
    if (_combinedBank != null) return _combinedBank!;

    final Map<String, List<dynamic>> bank = {};

    // 1. Load dashboard_items.json (base categories + pattern_matching visual questions)
    try {
      final baseJson = await rootBundle.loadString('assets/config/dashboard_items.json');
      final List<dynamic> baseList = json.decode(baseJson);
      for (final category in baseList) {
        final id = category['id'] as String;
        final questions = List<dynamic>.from(category['questions'] ?? []);
        bank[id] = questions;
      }
    } catch (e) {
      // ignore load errors
    }

    // 2. Load questions_bank.json (additional 100 questions per text category)
    try {
      final bankJson = await rootBundle.loadString('assets/config/questions_bank.json');
      final Map<String, dynamic> bankData = json.decode(bankJson);
      bankData.forEach((categoryId, questions) {
        final qList = List<dynamic>.from(questions as List);
        if (bank.containsKey(categoryId)) {
          bank[categoryId] = [...bank[categoryId]!, ...qList];
        } else {
          bank[categoryId] = qList;
        }
      });
    } catch (e) {
      // ignore load errors
    }

    _combinedBank = bank;
    return bank;
  }

  /// Returns the total question count for a given category.
  Future<int> getTotalQuestions(String categoryId) async {
    final bank = await _getBank();
    return bank[categoryId]?.length ?? 0;
  }

  /// Returns all questions for a category (merged bank).
  Future<List<dynamic>> getAllQuestions(String categoryId) async {
    final bank = await _getBank();
    return bank[categoryId] ?? [];
  }

  /// Pick [count] unseen questions for a category, in order.
  /// When the unseen pool is exhausted, it resets and reshuffles all questions.
  Future<List<dynamic>> pickQuestions({
    required String categoryId,
    int count = 5,
  }) async {
    final bank = await _getBank();
    final allQuestions = bank[categoryId] ?? [];
    if (allQuestions.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final seenKey = '$_prefPrefix$categoryId';
    final orderKey = '$_prefOrder$categoryId';

    // Load or create a shuffled order (list of indices as strings)
    List<String> orderStrings = prefs.getStringList(orderKey) ?? [];
    List<int> order = orderStrings.map(int.parse).toList();

    // Load seen count (how many from the order have been shown)
    int seenCount = prefs.getInt(seenKey) ?? 0;

    // If order is empty or stale (bank grew), create a new shuffled order
    if (order.isEmpty || order.length != allQuestions.length) {
      order = List.generate(allQuestions.length, (i) => i)..shuffle(Random());
      seenCount = 0;
    }

    // How many are unseen
    int unseen = order.length - seenCount;

    // If fewer than [count] remain unseen, reset
    if (unseen < count) {
      // Reshuffle for next round
      order.shuffle(Random());
      seenCount = 0;
      unseen = order.length;
    }

    // Pick next [count] indices from the order
    final pickedIndices = order.sublist(seenCount, seenCount + count);
    final pickedQuestions = pickedIndices.map((i) => allQuestions[i]).toList();

    // Advance seen count
    seenCount += count;

    // Persist
    await prefs.setStringList(orderKey, order.map((i) => i.toString()).toList());
    await prefs.setInt(seenKey, seenCount);

    return pickedQuestions;
  }

  /// How many questions remain unseen for this category.
  Future<int> getRemainingUnseen(String categoryId) async {
    final bank = await _getBank();
    final allQuestions = bank[categoryId] ?? [];
    if (allQuestions.isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final seenKey = '$_prefPrefix$categoryId';
    final seen = prefs.getInt(seenKey) ?? 0;
    return (allQuestions.length - seen).clamp(0, allQuestions.length);
  }

  /// Reset the seen progress for a specific category (for testing/debug).
  Future<void> resetCategory(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefPrefix$categoryId');
    await prefs.remove('$_prefOrder$categoryId');
  }

  /// Reset ALL categories.
  Future<void> resetAll() async {
    _combinedBank = null;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (k) => k.startsWith(_prefPrefix) || k.startsWith(_prefOrder),
    );
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
