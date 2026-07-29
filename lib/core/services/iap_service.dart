import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/presentation/providers/ad_provider.dart';

class IapService {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  static const String removeAdsProductId = 'remove_ads';

  /// Initialize Google Play Billing purchase stream and check existing purchases
  void initialize(WidgetRef ref) {
    _subscription?.cancel();
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList, ref);
      },
      onDone: () => _subscription?.cancel(),
      onError: (error) {},
    );

    // Auto-query active purchases on launch
    restorePurchases(ref);
  }

  void dispose() {
    _subscription?.cancel();
  }

  /// Trigger buy flow for "remove_ads" product
  Future<bool> buyRemoveAds() async {
    final bool available = await _iap.isAvailable();
    if (!available) return false;

    final ProductDetailsResponse response =
        await _iap.queryProductDetails({removeAdsProductId});

    if (response.productDetails.isNotEmpty) {
      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
    return false;
  }

  /// Restore purchases from Google Play account
  Future<void> restorePurchases(WidgetRef ref) async {
    try {
      final bool available = await _iap.isAvailable();
      if (available) {
        await _iap.restorePurchases();
      }
    } catch (_) {}
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList, WidgetRef ref) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.productID == removeAdsProductId) {
        if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          // Entitle user: Disable all ads across app permanently
          ref.read(adProvider.notifier).purchaseAdFree(true);

          if (purchaseDetails.pendingCompletePurchase) {
            _iap.completePurchase(purchaseDetails);
          }
        }
      }
    }
  }
}
