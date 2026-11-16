import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/no_ads_popup.dart';

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

  static const bool adsPausedForSuspension = false;
  static const int streakRewardDays = 3;

  static const String _prefLastOpenDate = 'iq_ad_streak_last_open_date';
  static const String _prefStreakDays = 'iq_ad_streak_days';
  static const String _prefAdFreeDate = 'iq_ad_free_date';
  static const String _prefPopupStep = 'iq_no_ads_popup_step';

  static String _adFreeDate = '';
  static int _popupStep = 0;
  static int _streakDays = 1;
  static bool _isStreakRewardToday = false;
  static bool _dialogCurrentlyVisible = false;
  static bool _popupShownThisLaunch = false;

  static final ValueNotifier<bool> adFreeTodayNotifier = ValueNotifier<bool>(false);

  static bool isValidAdUnitId(String id) {
    return RegExp(r'^ca-app-pub-\d+/\d+$').hasMatch(id.trim());
  }

  static String _dateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  static String _todayKey() => _dateKey(DateTime.now());

  static bool get isAdFreeToday =>
      adsPausedForSuspension || _adFreeDate == _todayKey();

  Future<void> initDailyState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    final lastOpen = prefs.getString(_prefLastOpenDate) ?? '';
    _streakDays = prefs.getInt(_prefStreakDays) ?? 0;
    _adFreeDate = prefs.getString(_prefAdFreeDate) ?? '';
    _popupStep = prefs.getInt(_prefPopupStep) ?? 0;

    if (lastOpen != today) {
      if (lastOpen == yesterday) {
        _streakDays += 1;
      } else {
        _streakDays = 1;
      }
      if (_streakDays >= streakRewardDays) {
        _isStreakRewardToday = true;
        _adFreeDate = today;
        _streakDays = 0;
        await prefs.setString(_prefAdFreeDate, today);
      }
      await prefs.setString(_prefLastOpenDate, today);
      await prefs.setInt(_prefStreakDays, _streakDays);
    } else if (_adFreeDate == today && _streakDays == 0) {
      _isStreakRewardToday = true;
    }

    if (adsPausedForSuspension) {
      _adFreeDate = today;
      await prefs.setString(_prefAdFreeDate, today);
    }

    adFreeTodayNotifier.value = isAdFreeToday;
  }

  static Future<void> markNoFillTodayAndNotify(String adUnitId) async {
    if (!isValidAdUnitId(adUnitId)) return;
    final today = _todayKey();
    if (_adFreeDate != today) {
      _adFreeDate = today;
      adFreeTodayNotifier.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAdFreeDate, today);
    }
  }

  static Future<void> showNoAdsPopupIfNeeded(
    BuildContext context, {
    required bool isAdFreePurchased,
  }) async {
    if ((!isAdFreePurchased && !isAdFreeToday) ||
        _popupShownThisLaunch ||
        _dialogCurrentlyVisible) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final prefs = await SharedPreferences.getInstance();
    final currentStep = _popupStep;
    _popupShownThisLaunch = true;
    _popupStep = (_popupStep + 1) % 3;
    await prefs.setInt(_prefPopupStep, _popupStep);

    if (!context.mounted) return;
    _dialogCurrentlyVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => NoAdsPopup(
        step: currentStep,
        isStreakReward: _isStreakRewardToday,
        streakDays: _streakDays,
        isAdFreePurchased: isAdFreePurchased,
      ),
    );
    _dialogCurrentlyVisible = false;
  }

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
    if (isAdFreeToday || !_isInitialized || _isLoadingInterstitial || _interstitialAd != null) {
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
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          markNoFillTodayAndNotify(_interstitialId);
        },
      ),
    );
  }

  /// Continue immediately when no ad is ready; otherwise continue after dismissal.
  void showInterstitialAd(BuildContext context, VoidCallback onAdClosed) {
    if (isAdFreeToday) {
      onAdClosed();
      return;
    }
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
