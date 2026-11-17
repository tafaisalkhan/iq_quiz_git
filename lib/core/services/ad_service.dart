import 'dart:async';
import 'dart:math';
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

  static String _adFreeDate = '';
  static int _streakDays = 1;
  static bool _isStreakRewardToday = false;
  static bool _streakRecordedToday = false;
  static String _lastOpenDate = '';
  static bool _noFillThisLaunch = false;
  static bool _dialogCurrentlyVisible = false;
  static bool _popupShownThisLaunch = false;
  static bool _isRemoveAdsPurchased = false;
  static final Random _random = Random();

  static final ValueNotifier<bool> adFreeTodayNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isNoFillNotifier = ValueNotifier<bool>(false);

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

    _lastOpenDate = prefs.getString(_prefLastOpenDate) ?? '';
    _isRemoveAdsPurchased = prefs.getBool('is_ad_free_purchased_v2') ?? false;
    _streakDays = prefs.getInt(_prefStreakDays) ?? 0;
    _adFreeDate = prefs.getString(_prefAdFreeDate) ?? '';
    _streakRecordedToday = _lastOpenDate == today;
    _isStreakRewardToday = !_isRemoveAdsPurchased && _adFreeDate == today;

    if (adsPausedForSuspension) {
      _adFreeDate = today;
      await prefs.setString(_prefAdFreeDate, today);
    }

    adFreeTodayNotifier.value = isAdFreeToday;
  }

  /// Advances the 3-day streak only when an ad actually loads (ads running & not remove_ads).
  static Future<void> markAdLoadedForStreak() async {
    if (_isRemoveAdsPurchased || _isStreakRewardToday || _streakRecordedToday) {
      return;
    }
    _streakRecordedToday = true;

    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

    if (_lastOpenDate == today) return;
    _streakDays = (_lastOpenDate == yesterday) ? _streakDays + 1 : 1;

    if (_streakDays >= streakRewardDays) {
      final tomorrow = _dateKey(DateTime.now().add(const Duration(days: 1)));
      _adFreeDate = tomorrow;
      _streakDays = 0;
      await prefs.setString(_prefAdFreeDate, tomorrow);
    }
    _lastOpenDate = today;
    await prefs.setString(_prefLastOpenDate, today);
    await prefs.setInt(_prefStreakDays, _streakDays);
  }

  static String streakNotificationSuffix({required bool isRemoveAdsPurchased}) {
    if (isRemoveAdsPurchased) return '';
    final tomorrow = _dateKey(DateTime.now().add(const Duration(days: 1)));
    if (_adFreeDate == tomorrow) {
      return ' Streak complete! Today is 100% Ad-Free (Banner & Interstitial off)!';
    }
    if (_streakDays == 1) {
      return ' Open today (Day 2/3) to get closer to a Free Ad-Free Day!';
    }
    if (_streakDays == 2) {
      return ' 1 more day (Day 3/3) to unlock tomorrow Ad-Free!';
    }
    return '';
  }

  static Future<void> markNoFillTodayAndNotify(String adUnitId) async {
    if (!isValidAdUnitId(adUnitId)) return;
    _noFillThisLaunch = true;
    isNoFillNotifier.value = true;
  }

  static Future<void> showNoAdsPopupIfNeeded(
    BuildContext context, {
    required bool isAdFreePurchased,
  }) async {
    _isRemoveAdsPurchased = isAdFreePurchased;
    if (_popupShownThisLaunch || _dialogCurrentlyVisible) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final randomStep = _random.nextInt(3);
    _popupShownThisLaunch = true;

    if (!context.mounted) return;
    _dialogCurrentlyVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => NoAdsPopup(
        step: randomStep,
        isStreakReward: _isStreakRewardToday && !isAdFreePurchased && !_noFillThisLaunch,
        streakDays: _streakDays,
        isAdFreePurchased: isAdFreePurchased,
        isNoFill: _noFillThisLaunch,
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
          markAdLoadedForStreak();
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
    if (_isRemoveAdsPurchased || adsPausedForSuspension || _noFillThisLaunch) {
      onRewardEarned(1);
      return;
    }
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
            markNoFillTodayAndNotify(adUnitId);
            safeReward();
          },
        ),
      );
    } catch (_) {
      safeReward();
    }
  }
}
