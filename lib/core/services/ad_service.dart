import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme/app_colors.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Real Production AdMob IDs ─────────────────────────────────────────────
  // App ID:  ca-app-pub-1852108665659812~4950039925
  static const String androidBannerId = 'ca-app-pub-1852108665659812/4653838096';
  static const String iosBannerId     = 'ca-app-pub-1852108665659812/4653838096';

  static const String androidInterstitialId = 'ca-app-pub-1852108665659812/9000965577';
  static const String iosInterstitialId     = 'ca-app-pub-1852108665659812/9000965577';

  static const String androidRewardedId = 'ca-app-pub-1852108665659812/3445386569';
  static const String iosRewardedId     = 'ca-app-pub-1852108665659812/3445386569';

  bool _isInitialized = false;

  /// Initialize Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (_) {}
  }

  /// Load and display real production Interstitial Ad with fail-safe fallback
  void showInterstitialAd(BuildContext context, VoidCallback onAdClosed) {
    initialize();
    final adUnitId = Theme.of(context).platform == TargetPlatform.iOS
        ? iosInterstitialId
        : androidInterstitialId;

    bool hasCompleted = false;

    void safeOnClosed() {
      if (!hasCompleted) {
        hasCompleted = true;
        onAdClosed();
      }
    }

    // Fail-safe timeout: If AdMob doesn't respond in 3.5 seconds, proceed seamlessly
    Timer(const Duration(milliseconds: 3500), () {
      safeOnClosed();
    });

    try {
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                safeOnClosed();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                safeOnClosed();
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (error) {
            safeOnClosed();
          },
        ),
      );
    } catch (_) {
      safeOnClosed();
    }
  }

  /// Load and display real production Rewarded Ad with fail-safe fallback
  void showRewardedAd(BuildContext context, Function(int rewardAmount) onRewardEarned) {
    initialize();
    final adUnitId = Theme.of(context).platform == TargetPlatform.iOS
        ? iosRewardedId
        : androidRewardedId;

    bool hasRewarded = false;

    void safeReward() {
      if (!hasRewarded) {
        hasRewarded = true;
        onRewardEarned(1);
      }
    }

    // Fail-safe timeout: If AdMob doesn't respond in 4 seconds, grant unlock so user is never blocked
    Timer(const Duration(milliseconds: 4000), () {
      safeReward();
    });

    try {
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                safeReward();
              },
            );
            ad.show(
              onUserEarnedReward: (adWithoutView, reward) {
                safeReward();
              },
            );
          },
          onAdFailedToLoad: (error) {
            safeReward();
          },
        ),
      );
    } catch (_) {
      safeReward();
    }
  }
}
