import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'iap_service.dart';

/// Handles in-app 5-star rating, sharing, $1.99 coffee IAP, and Play Store updates.
class SupportService {
  SupportService._();

  static const String packageId = 'com.iqquiz.app';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageId';

  static bool _updateCheckedThisLaunch = false;

  static Future<void> rateApp(BuildContext context) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    int selectedStars = 5;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Rate IQ Quiz',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How would you rate your experience?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => selectedStars = star),
                    icon: Icon(
                      star <= selectedStars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFC68B2C),
                      size: 34,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Thank you for rating us $selectedStars star${selectedStars == 1 ? '' : 's'}!',
                    ),
                  ),
                );
                if (!kIsWeb && selectedStars >= 4) {
                  try {
                    final inAppReview = InAppReview.instance;
                    if (await inAppReview.isAvailable()) {
                      await inAppReview.requestReview();
                    }
                  } catch (e) {
                    debugPrint('InAppReview error: $e');
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> shareApp() async {
    await Share.share(
      'Check out IQ Quiz — challenge your brain with daily quizzes!\n$playStoreUrl',
    );
  }

  static Future<void> buyCoffee(BuildContext context) async {
    final started = await IapService().buyCoffee();
    if (!started && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Coffee support (${IapService.coffeeProductId}) is not available right now.',
          ),
        ),
      );
    }
  }

  static Future<void> checkForAppUpdate(BuildContext context) async {
    if (kIsWeb || _updateCheckedThisLaunch) return;
    _updateCheckedThisLaunch = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Update Available',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'A newer version of IQ Quiz is available on Google Play. Update now for the latest improvements!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  if (info.immediateUpdateAllowed) {
                    await InAppUpdate.performImmediateUpdate();
                  } else if (info.flexibleUpdateAllowed) {
                    await InAppUpdate.startFlexibleUpdate();
                    await InAppUpdate.completeFlexibleUpdate();
                  } else {
                    await launchUrl(
                      Uri.parse(playStoreUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } catch (e) {
                  debugPrint('In-app update failed: $e');
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Update check skipped: $e');
    }
  }
}
