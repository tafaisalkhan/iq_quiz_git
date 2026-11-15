import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/daily_quiz_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_page_route.dart';
import 'detail_screen.dart';

class DailyQuizScreen extends ConsumerStatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  ConsumerState<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends ConsumerState<DailyQuizScreen> {
  final _service = DailyQuizService();
  DailyQuizHistory? _history;
  late DateTime _month;
  bool _starting = false;
  Future<void>? _completionSave;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    try {
      final history = await _service.loadHistory();
      if (mounted) setState(() => _history = history);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not load daily quiz history: $error');
    }
  }

  Future<void> _startToday() async {
    if (_starting || _history?.resultFor(DateTime.now()) != null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    _completionSave = null;
    try {
      final day = DateTime.now();
      final questions = await _service.questionsFor(day);
      if (questions.isEmpty)
        throw StateError('No quiz questions are available.');
      if (!mounted) return;
      await Navigator.of(context).push(
        CustomPageRoute(
          child: DetailScreen(
            id: 'daily_quiz',
            title: 'Daily Quiz',
            description:
                'Daily questions selected for ${DailyQuizService.dayKey(day)}.',
            icon: Icons.today_rounded,
            color: AppColors.primary,
            questions: questions,
            isDailyChallenge: true,
            onQuizCompleted: (score, total) {
              final save = _service.saveResult(day, score, total);
              _completionSave = save;
              return save;
            },
          ),
        ),
      );
      await _completionSave;
      await _load();
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Could not start today\'s quiz: $error');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String _status(DateTime day) {
    final history = _history;
    if (history == null) return 'Upcoming';
    if (history.resultFor(day) != null) return 'Completed';
    final today = DateTime.now();
    final date = DateTime(day.year, day.month, day.day);
    final current = DateTime(today.year, today.month, today.day);
    if (date.isBefore(history.startDate)) return 'Before you started';
    if (date.isBefore(current)) return 'Skipped';
    if (date == current) return 'Ready today';
    return 'Upcoming';
  }

  void _showDay(DateTime day) {
    final result = _history?.resultFor(day);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DailyQuizService.dayKey(day)),
        content: Text(
          result == null
              ? _status(day)
              : 'Completed • ${result.score} of ${result.total} correct',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    final today = DateTime.now();
    final completedToday = history?.resultFor(today);
    final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month).weekday - 1;
    final completed = history?.results.length ?? 0;
    final skipped = history == null
        ? 0
        : List.generate(
            DateTime(
              today.year,
              today.month,
              today.day,
            ).difference(history.startDate).inDays,
            (index) => history.startDate.add(Duration(days: index)),
          ).where((day) => history.resultFor(day) == null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Quiz'), centerTitle: true),
      body: history == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today’s challenge',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          completedToday == null
                              ? 'Answer today’s questions and build your daily record. Questions do not repeat until the daily pool is complete.'
                              : 'Completed today: ${completedToday.score} of ${completedToday.total} correct.',
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: completedToday == null && !_starting
                                ? _startToday
                                : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _starting
                                  ? 'Loading questions…'
                                  : completedToday == null
                                  ? 'Start daily quiz'
                                  : 'Completed today',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        context,
                        '$completed',
                        'Completed',
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        context,
                        '$skipped',
                        'Skipped',
                        AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => setState(
                                () => _month = DateTime(
                                  _month.year,
                                  _month.month - 1,
                                ),
                              ),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              '${_month.year} • ${_monthName(_month.month)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              onPressed:
                                  DateTime(
                                    _month.year,
                                    _month.month,
                                  ).isBefore(DateTime(today.year, today.month))
                                  ? () => setState(
                                      () => _month = DateTime(
                                        _month.year,
                                        _month.month + 1,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final label in [
                              'M',
                              'T',
                              'W',
                              'T',
                              'F',
                              'S',
                              'S',
                            ])
                              Expanded(child: Center(child: Text(label))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                          itemCount: leading + lastDay,
                          itemBuilder: (context, index) {
                            if (index < leading) return const SizedBox.shrink();
                            final day = DateTime(
                              _month.year,
                              _month.month,
                              index - leading + 1,
                            );
                            final status = _status(day);
                            final color = status == 'Completed'
                                ? AppColors.success
                                : status == 'Skipped'
                                ? AppColors.error
                                : status == 'Ready today'
                                ? AppColors.primary
                                : Colors.grey;
                            return InkWell(
                              onTap: () => _showDay(day),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                    alpha:
                                        status == 'Upcoming' ||
                                            status == 'Before you started'
                                        ? 0.06
                                        : 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: status == 'Ready today'
                                      ? Border.all(color: color)
                                      : null,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (status == 'Completed' ||
                                          status == 'Skipped')
                                        Icon(
                                          status == 'Completed'
                                              ? Icons.check
                                              : Icons.close,
                                          size: 12,
                                          color: color,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Green: completed  •  Red: skipped  •  Outlined: today',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your history begins on the first day you open Daily Quiz.',
                ),
              ],
            ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: color),
          ),
          Text(label),
        ],
      ),
    ),
  );

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}
