import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── Google Test AdMob IDs (production IDs in gitignored admob_secrets.json) ─
  static const String androidBannerId =
      String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
  static const String iosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  static const String androidInterstitialId =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');
  static const String iosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  static const String androidRewardedId =
      String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-3940256099942544/5224354917');
  static const String iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;

  String get _interstitialId => defaultTargetPlatform == TargetPlatform.iOS
      ? iosInterstitialId
      : androidInterstitialId;

  /// Initialize Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      preloadInterstitial();
    } catch (_) {}
  }

  void preloadInterstitial() {
    if (!_isInitialized || _isLoadingInterstitial || _interstitialAd != null) {
      return;
    }
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// Continue immediately when no ad is ready; otherwise continue after dismissal.
  void showInterstitialAd(BuildContext context, VoidCallback onAdClosed) {
    final ad = _interstitialAd;
    if (ad == null) {
      preloadInterstitial();
      onAdClosed();
      return;
    }
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preloadInterstitial();
        onAdClosed();
      },
    );
    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      preloadInterstitial();
      onAdClosed();
    }
  }

  /// Load and display real production Rewarded Ad with fail-safe fallback
  void showRewardedAd(
    BuildContext context,
    Function(int rewardAmount) onRewardEarned,
  ) {
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
