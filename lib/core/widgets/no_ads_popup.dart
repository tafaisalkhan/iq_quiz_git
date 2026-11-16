import 'package:flutter/material.dart';
import '../services/support_service.dart';

/// Daily popup shown on the Menu/Home tab when ads are unavailable/suspended
/// or earned via login streak. Rotates one primary action button:
///   step 0 (1st time): Rate App
///   step 1 (2nd time): Share With Friends
///   step 2 (3rd time): Buy Developer a Coffee ($1.99)
class NoAdsPopup extends StatelessWidget {
  const NoAdsPopup({
    super.key,
    required this.step,
    required this.isStreakReward,
    required this.streakDays,
    this.isAdFreePurchased = false,
  });

  final int step;
  final bool isStreakReward;
  final int streakDays;
  final bool isAdFreePurchased;

  @override
  Widget build(BuildContext context) {
    final actionIndex = step % 3;

    late final IconData headerIcon;
    late final String title;
    late final String body;
    late final String primaryLabel;
    late final IconData primaryIcon;

    final resolvedTitle = isAdFreePurchased
        ? 'Thank You for Your Support!'
        : (isStreakReward
            ? '$streakDays-Day Streak: No Ads Today!'
            : 'No Ads Today!');
    final prefix = isAdFreePurchased ? '' : 'Enjoy an ad-free experience today! ';
    if (actionIndex == 0) {
      headerIcon = Icons.star_rounded;
      title = resolvedTitle;
      body = '${prefix}If you love IQ Quiz, please rate us.';
      primaryLabel = 'Rate App';
      primaryIcon = Icons.star_rounded;
    } else if (actionIndex == 1) {
      headerIcon = Icons.share_rounded;
      title = resolvedTitle;
      body = '${prefix}Please share IQ Quiz with your friends and family.';
      primaryLabel = 'Share With Friends';
      primaryIcon = Icons.share_rounded;
    } else {
      headerIcon = Icons.local_cafe_rounded;
      title = resolvedTitle;
      body =
          '${prefix}Support the developer with a \$1.99 coffee to help keep the app growing.';
      primaryLabel = 'Buy Developer a Coffee (\$1.99)';
      primaryIcon = Icons.local_cafe_rounded;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                headerIcon,
                color: Theme.of(context).colorScheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(fontSize: 15, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final rootContext =
                      Navigator.of(context, rootNavigator: true).context;
                  Navigator.of(context).pop();
                  if (actionIndex == 0) {
                    await SupportService.rateApp(rootContext);
                  } else if (actionIndex == 1) {
                    await SupportService.shareApp();
                  } else {
                    await SupportService.buyCoffee(rootContext);
                  }
                },
                icon: Icon(primaryIcon),
                label: Text(
                  primaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                isAdFreePurchased ? 'Close' : 'Enjoy Ad-Free',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
