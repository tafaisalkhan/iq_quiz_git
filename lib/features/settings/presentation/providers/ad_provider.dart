import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdState {
  final bool isAdFreePurchased;
  final int userCoins;

  const AdState({required this.isAdFreePurchased, required this.userCoins});

  factory AdState.initial() {
    return const AdState(isAdFreePurchased: false, userCoins: 0);
  }

  AdState copyWith({bool? isAdFreePurchased, int? userCoins}) {
    return AdState(
      isAdFreePurchased: isAdFreePurchased ?? this.isAdFreePurchased,
      userCoins: userCoins ?? this.userCoins,
    );
  }
}

class AdNotifier extends Notifier<AdState> {
  // Versioned to discard ad-free flags granted by the old billing-unavailable fallback.
  static const _entitlementKey = 'is_ad_free_purchased_v2';
  @override
  AdState build() {
    _loadFromPrefs();
    return AdState.initial();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final purchased = prefs.getBool(_entitlementKey) ?? false;
      if (purchased && !state.isAdFreePurchased) {
        state = state.copyWith(isAdFreePurchased: true);
      }
    } catch (_) {}
  }

  /// Toggles and persists the Ad-Free purchase status
  Future<void> purchaseAdFree(bool purchased) async {
    state = state.copyWith(isAdFreePurchased: purchased);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_entitlementKey, purchased);
    } catch (_) {}
  }

  /// Increments user coins after watching rewarded ads
  void rewardUser(int amount) {
    state = state.copyWith(userCoins: state.userCoins + amount);
  }
}

final adProvider = NotifierProvider<AdNotifier, AdState>(AdNotifier.new);
