import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/question_bank_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animated_card.dart';
import '../../../../core/widgets/custom_page_route.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../settings/presentation/providers/ad_provider.dart';
import '../../../settings/presentation/providers/app_settings_provider.dart';
import '../providers/quiz_schedule_provider.dart';
import '../providers/navigation_provider.dart';
import 'detail_screen.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tapCount = 0;
  List<dynamic> _modules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (AppConfig.enableFirebaseDatabase) {
        // Simulate loading from Firebase Firestore database
        await Future.delayed(const Duration(milliseconds: 1200));
        _modules = [
          {
            "id": "firebase_auth",
            "title": "Firebase Social Sign-In",
            "description": "Federated authentication is active via Google / Apple accounts.",
            "iconName": "lock_outline_rounded",
            "colorHex": "FF6366F1"
          },
          {
            "id": "firebase_db",
            "title": "Firebase Cloud Firestore",
            "description": "Cloud document collections are active.",
            "iconName": "bubble_chart_outlined",
            "colorHex": "FF14B8A6"
          }
        ];
      } else {
        // If not Firebase Database, read directly from App JSON file via ApiClient
        final response = await ApiClient().get('/items');
        _modules = response['data'] ?? [];
      }
    } catch (e) {
      _errorMessage = 'Failed to load modules: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _getIconByName(String name) {
    switch (name) {
      case 'grid_view_rounded':
      case 'bubble_chart_outlined':
        return Icons.grid_view_rounded;
      case 'calculate_rounded':
      case 'notifications_active_outlined':
        return Icons.calculate_rounded;
      case 'psychology_rounded':
      case 'extension_rounded':
        return Icons.psychology_rounded;
      case 'schedule_rounded':
      case 'account_tree_rounded':
        return Icons.schedule_rounded;
      default:
        return Icons.quiz_rounded;
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

  void _triggerNotificationAlert() {
    NotificationService().showNotification(
      context,
      title: 'Success Alert! ⚡',
      message: 'This slides down using custom Overlay and elastic physics.',
      icon: Icons.flash_on_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'IQ Quiz',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final remaining = ref.watch(quizScheduleProvider).remainingQuizzes;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_num_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$remaining/2',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.today_rounded, color: AppColors.primary),
                  title: const Text('Today’s Daily Quiz'),
                  subtitle: const Text('Your questions and progress stay saved after a restart.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => ref.read(navigationProvider.notifier).setIndex(1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text(
                    'COGNITIVE TEST MODULES',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '5 Qs / Session',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildCapabilitiesGrid(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }




  Widget _buildCapabilitiesGrid(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_errorMessage != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(
        _modules.length,
        (index) {
          final module = _modules[index];
          return _buildModuleCard(
            context: context,
            id: module['id'] ?? 'module_$index',
            title: module['title'] ?? '',
            description: module['description'] ?? '',
            icon: _getIconByName(module['iconName'] ?? ''),
            color: _getColorFromHex(module['colorHex'] ?? 'FF6366F1'),
            delayIndex: index + 2,
            questions: module['questions'] ?? [],
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Shimmer(width: 48, height: 48, borderRadius: 12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Shimmer(width: 150, height: 16, borderRadius: 4),
                        const SizedBox(height: 8),
                        const Shimmer(width: double.infinity, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required int delayIndex,
    required List<dynamic> questions,
  }) {
    return AnimatedCard(
      delay: Duration(milliseconds: delayIndex * 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5.0),
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.2), width: 1.2),
          ),
          child: InkWell(
            onTap: () async {
              final scheduleState = ref.read(quizScheduleProvider);

              Future<void> launchQuiz() async {
                final appSettings = ref.read(appSettingsProvider);
                final qCount = appSettings.quizQuestionCount;
                final pickedQuestions = await QuestionBankService().pickQuestions(
                  categoryId: id,
                  count: qCount,
                );
                if (!context.mounted) return;
                Navigator.of(context).push(
                  CustomPageRoute(
                    child: DetailScreen(
                      id: id,
                      title: title,
                      description: description,
                      icon: icon,
                      color: color,
                      questions: pickedQuestions,
                    ),
                  ),
                );
              }

              final adState = ref.read(adProvider);
              final isAdFree = adState.isAdFreePurchased;

              if (isAdFree || scheduleState.remainingQuizzes > 0) {
                if (!isAdFree) {
                  ref.read(quizScheduleProvider.notifier).decrementRemainingQuizzes();
                }
                await launchQuiz();
              } else {
                _showAdUnlockDialog(context, launchQuiz);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Hero(
                    tag: 'module-icon-$id',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'module-title-$id',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            height: 1.25,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final adState = ref.watch(adProvider);
                      final scheduleState = ref.watch(quizScheduleProvider);
                      final remaining = scheduleState.remainingQuizzes;
                      if (!adState.isAdFreePurchased && remaining == 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_circle_fill_rounded, color: AppColors.warning, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                'Unlock',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.grey.withOpacity(0.6),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUtilitiesCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedCard(
      delay: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark.withOpacity(0.5)
                : AppColors.borderLight.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  'Core Action Utilities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Trigger a custom sliding notification to verify in-app popup banner behavior.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _triggerNotificationAlert,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Trigger Notification'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tapCount++;
                      });
                      NotificationService().showNotification(
                        context,
                        title: 'Counter Updated! 📈',
                        message: 'Custom button clicked $_tapCount times.',
                        icon: Icons.trending_up_rounded,
                      );
                    },
                    child: Text('Taps: $_tapCount'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsTestingCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adState = ref.watch(adProvider);

    return AnimatedCard(
      delay: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark.withOpacity(0.5)
                : AppColors.borderLight.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ad_units_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Boilerplate Ads Testing',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Test full-screen Interstitial Ads and Rewarded Ads. Check reactive changes immediately when toggling Ad-Free in Settings.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (adState.isAdFreePurchased)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars_rounded, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ads Disabled: Ad-Free Active! 🎉',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AdService().showInterstitialAd(context, () {
                          NotificationService().showNotification(
                            context,
                            title: 'Interstitial Ad Closed! 📲',
                            message: 'Normal application flow resumed.',
                            icon: Icons.play_arrow_rounded,
                          );
                        });
                      },
                      icon: const Icon(Icons.fullscreen_rounded, size: 18),
                      label: const Text('Interstitial'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AdService().showRewardedAd(context, (coins) {
                          ref.read(adProvider.notifier).rewardUser(coins);
                          NotificationService().showNotification(
                            context,
                            title: 'Reward Earned! 💰',
                            message: 'Successfully earned +$coins Coins.',
                            icon: Icons.monetization_on_rounded,
                          );
                        });
                      },
                      icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                      label: const Text('Watch & Earn'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAdUnlockDialog(BuildContext context, Future<void> Function() onUnlocked) {
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
              onPressed: () async {
                Navigator.of(context).pop();
                AdService().showRewardedAd(context, (coins) async {
                  ref.read(quizScheduleProvider.notifier).incrementRemainingQuizzes();
                  ref.read(quizScheduleProvider.notifier).decrementRemainingQuizzes();
                  await onUnlocked();
                });
              },
            ),
          ],
        );
      },
    );
  }
}
