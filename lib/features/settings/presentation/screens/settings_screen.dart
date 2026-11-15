import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/iap_service.dart';
import '../providers/ad_provider.dart';
import '../providers/app_settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SettingsScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _localizedPrice;
  String _purchaseStatus = 'Checking Google Play price...';

  @override
  void initState() {
    super.initState();
    _fetchLocalizedPrice();
  }

  Future<void> _fetchLocalizedPrice() async {
    if (mounted) {
      setState(() => _purchaseStatus = 'Checking Google Play price...');
    }
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (available) {
        final response = await InAppPurchase.instance.queryProductDetails({
          IapService.removeAdsProductId,
        });
        if (mounted && response.productDetails.isNotEmpty) {
          setState(() {
            _localizedPrice = response.productDetails.first.price;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _purchaseStatus = 'Retry Google Play price');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adState = ref.watch(adProvider);
    final appSettings = ref.watch(appSettingsProvider);

    final timerOptions = [
      {'label': '15 sec', 'val': 15},
      {'label': '30 sec (Default)', 'val': 30},
      {'label': '45 sec', 'val': 45},
      {'label': '60 sec (1 min)', 'val': 60},
      {'label': '90 sec', 'val': 90},
      {'label': '120 sec (2 mins)', 'val': 120},
    ];

    final questionCountOptions = [3, 4, 5, 6];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Appearance
            _buildSectionHeader('APPEARANCE & THEME'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dark Mode Theme',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Toggle app light/dark interface style',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isDark,
                      activeColor: AppColors.primary,
                      onChanged: (_) => widget.onToggleTheme(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Quiz Configuration
            _buildSectionHeader('QUIZ TIMING & LENGTH'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timer Duration Setting
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timer_rounded,
                            color: AppColors.info,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question Timer Limit',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Set response timer from 15s up to 2 mins',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: appSettings.questionTimerSeconds,
                      dropdownColor: isDark
                          ? AppColors.surfaceDark
                          : Colors.white,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      items: timerOptions.map((opt) {
                        return DropdownMenuItem<int>(
                          value: opt['val'] as int,
                          child: Text(
                            opt['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(appSettingsProvider.notifier)
                              .setQuestionTimerSeconds(val);
                        }
                      },
                    ),
                    const Divider(height: 28),

                    // Question Count Setting
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.format_list_numbered_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Questions per Quiz',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Choose question count (3 to 6 questions)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: questionCountOptions.map((count) {
                        final isSelected =
                            appSettings.quizQuestionCount == count;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3.0,
                            ),
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  '$count Qs',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.grey[100],
                              onSelected: (_) {
                                ref
                                    .read(appSettingsProvider.notifier)
                                    .setQuizQuestionCount(count);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Premium Ad-Free Purchase
            _buildSectionHeader('PREMIUM & AD-FREE'),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: adState.isAdFreePurchased
                      ? AppColors.success.withOpacity(0.5)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: adState.isAdFreePurchased ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                (adState.isAdFreePurchased
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            adState.isAdFreePurchased
                                ? Icons.verified_rounded
                                : Icons.block_rounded,
                            color: adState.isAdFreePurchased
                                ? AppColors.success
                                : AppColors.warning,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adState.isAdFreePurchased
                                    ? 'Ad-Free Status Active'
                                    : 'Remove All Ads',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: adState.isAdFreePurchased
                                      ? AppColors.success
                                      : null,
                                ),
                              ),
                              Text(
                                adState.isAdFreePurchased
                                    ? 'All banner and interstitial ads are permanently removed.'
                                    : 'Purchase Ad-Free mode to remove all ads across the app.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: adState.isAdFreePurchased
                            ? null
                            : () async {
                                if (_localizedPrice == null) {
                                  await _fetchLocalizedPrice();
                                  return;
                                }
                                final success = await IapService()
                                    .buyRemoveAds();
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Google Play could not start the purchase. Please try again.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: Icon(
                          adState.isAdFreePurchased
                              ? Icons.verified_rounded
                              : Icons.shopping_cart_rounded,
                          size: 18,
                        ),
                        label: Text(
                          adState.isAdFreePurchased
                              ? 'Remove Ads Purchased'
                              : _localizedPrice == null
                              ? _purchaseStatus
                              : 'Purchase Remove Ads ($_localizedPrice)',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          await IapService().restorePurchases(ref);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Restore requested. Any owned purchase will appear shortly.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.restore_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'Restore Previous Purchases',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          fontSize: 11,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
