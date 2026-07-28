import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animated_card.dart';
import '../../../../core/widgets/custom_page_route.dart';
import '../providers/quiz_schedule_provider.dart';
import 'detail_screen.dart';

class QuizScheduleScreen extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const QuizScheduleScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  ConsumerState<QuizScheduleScreen> createState() => _QuizScheduleScreenState();
}

class _QuizScheduleScreenState extends ConsumerState<QuizScheduleScreen> {
  bool _isLoading = false;

  Future<void> _startScheduledTest(QuizSchedule schedule) async {
    final scheduleState = ref.read(quizScheduleProvider);

    Future<void> loadAndLaunch() async {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await ApiClient().get('/items');
        final List<dynamic> modules = response['data'] ?? [];
        final List<dynamic> pooledQuestions = [];
        String mainDescription = 'Scheduled cognitive assessment session.';
        IconData mainIcon = Icons.psychology_rounded;
        Color mainColor = AppColors.primary;

        if (schedule.categoryId == 'all') {
          for (final m in modules) {
            final qList = (m['questions'] as List<dynamic>?) ?? [];
            pooledQuestions.addAll(qList);
          }
          mainDescription = 'Mixed cognitive assessment across all categories.';
        } else {
          final catIds = schedule.categoryId.split(',');
          for (final m in modules) {
            if (catIds.contains(m['id'])) {
              final qList = (m['questions'] as List<dynamic>?) ?? [];
              pooledQuestions.addAll(qList);
              if (pooledQuestions.length == qList.length) {
                mainIcon = _getIconByName(m['iconName'] ?? '');
                mainColor = _getColorFromHex(m['colorHex'] ?? 'FF6366F1');
              }
            }
          }
        }

        if (pooledQuestions.isEmpty) {
          throw Exception('No questions available in selected categories.');
        }

        final count = mathMin(schedule.questionsCount, pooledQuestions.length);
        final List<dynamic> shuffledList = List.from(pooledQuestions)..shuffle();
        final finalQuestions = shuffledList.sublist(0, count);

        if (!mounted) return;

        Navigator.of(context).push(
          CustomPageRoute(
            child: DetailScreen(
              id: schedule.categoryId,
              title: schedule.categoryTitle,
              description: mainDescription,
              icon: mainIcon,
              color: mainColor,
              questions: finalQuestions,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting test: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }

    if (scheduleState.remainingQuizzes > 0) {
      ref.read(quizScheduleProvider.notifier).decrementRemainingQuizzes();
      await loadAndLaunch();
    } else {
      _showAdUnlockDialog(context, () async {
        await loadAndLaunch();
      });
    }
  }

  int mathMin(int a, int b) => a < b ? a : b;

  IconData _getIconByName(String name) {
    switch (name) {
      case 'bubble_chart_outlined':
        return Icons.bubble_chart_outlined;
      case 'notifications_active_outlined':
        return Icons.notifications_active_outlined;
      case 'account_tree_rounded':
        return Icons.account_tree_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  Color _getColorFromHex(String hex) {
    try {
      final hexColor = hex.replaceAll('#', '');
      return Color(int.parse(hexColor, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _addDailySchedule() {
    final scheduleState = ref.read(quizScheduleProvider);
    if (scheduleState.schedules.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule limit reached (Max 2).')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddScheduleBottomSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(quizScheduleProvider);
    final schedules = scheduleState.schedules;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Schedule'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR DAILY SCHEDULES (${schedules.length}/2)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attempts Remaining Today: ${scheduleState.remainingQuizzes} / 2',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (schedules.length < 2)
                        IconButton(
                          icon: const Icon(Icons.add_alarm_rounded, color: AppColors.primary),
                          onPressed: _addDailySchedule,
                          tooltip: 'Add Daily Schedule',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (schedules.isEmpty)
                    AnimatedCard(
                      delay: const Duration(milliseconds: 50),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 48,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Schedules Set',
                              style: GoogleFonts.outfit(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the "+" icon above or button below to schedule a daily test timer.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: schedules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return AnimatedCard(
                          delay: Duration(milliseconds: (index + 1) * 80),
                          child: Container(
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.alarm_on_rounded, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            schedule.timeOfDay,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          color: AppColors.error, size: 20),
                                      onPressed: () {
                                        ref.read(quizScheduleProvider.notifier).removeSchedule(schedule.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Schedule deleted.')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  schedule.categoryTitle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Daily test reminder set with ${schedule.questionsCount} questions.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startScheduledTest(schedule),
                                    icon: Icon(
                                      scheduleState.remainingQuizzes == 0
                                          ? Icons.lock_open_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      scheduleState.remainingQuizzes == 0
                                          ? 'Unlock & Start Quiz'
                                          : 'Start Daily Quiz',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: scheduleState.remainingQuizzes == 0
                                          ? AppColors.warning
                                          : AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  if (schedules.length < 2)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addDailySchedule,
                        icon: const Icon(Icons.alarm_add_rounded),
                        label: const Text('Schedule New Daily Quiz'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _showAdUnlockDialog(BuildContext context, VoidCallback onUnlocked) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Quiz Limit Reached',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'You have used your 2 free quiz attempts. Watch a quick rewarded ad to unlock another quiz immediately!',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
              label: Text(
                'Watch Ad to Unlock',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                AdService().showRewardedAd(context, (coins) {
                  ref.read(quizScheduleProvider.notifier).incrementRemainingQuizzes();
                  ref.read(quizScheduleProvider.notifier).decrementRemainingQuizzes();
                  onUnlocked();
                });
              },
            ),
          ],
        );
      },
    );
  }
}

class AddScheduleBottomSheet extends StatefulWidget {
  final WidgetRef ref;

  const AddScheduleBottomSheet({super.key, required this.ref});

  @override
  State<AddScheduleBottomSheet> createState() => _AddScheduleBottomSheetState();
}

class _AddScheduleBottomSheetState extends State<AddScheduleBottomSheet> {
  String _selectedCategoryId = 'all';
  String _selectedCategoryTitle = 'All Categories (Mixed Quiz)';
  int _questionsCount = 5;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'title': 'All Categories (Mixed Quiz)'},
    {'id': 'pattern_matching', 'title': 'Spatial Pattern Matrix'},
    {'id': 'numerical_sequence', 'title': 'Numerical Series & Sequences'},
    {'id': 'iq_statement', 'title': 'Deductive Syllogisms & Logic'},
    {'id': 'logical_dependency', 'title': 'Analytical & Time Reasoning'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Daily Test Schedule',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'SELECT QUIZ CATEGORY',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat['id'],
                  child: Text(cat['title']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategoryId = val;
                    _selectedCategoryTitle =
                        _categories.firstWhere((c) => c['id'] == val)['title']!;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            Text(
              'NUMBER OF QUESTIONS: $_questionsCount (MAX 10)',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            Slider(
              value: _questionsCount.toDouble(),
              min: 3,
              max: 10,
              divisions: 7,
              activeColor: AppColors.primary,
              label: '$_questionsCount',
              onChanged: (val) {
                setState(() {
                  _questionsCount = val.toInt();
                });
              },
            ),
            const SizedBox(height: 20),

            Text(
              'SELECT SCHEDULED TIME',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (picked != null) {
                  setState(() {
                    _selectedTime = picked;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          _selectedTime.format(context),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Change Time',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final timeStr =
                      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
                  final schedule = QuizSchedule(
                    id: 'sched-${DateTime.now().millisecondsSinceEpoch}',
                    categoryId: _selectedCategoryId,
                    categoryTitle: _selectedCategoryTitle,
                    questionsCount: _questionsCount,
                    timeOfDay: timeStr,
                  );

                  final added = widget.ref
                      .read(quizScheduleProvider.notifier)
                      .addSchedule(schedule);
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added
                            ? 'Schedule added successfully!'
                            : 'Failed: Max 2 schedules allowed.',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Create Schedule',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
