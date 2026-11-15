import 'dart:async';
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
    unawaited(restorePurchases(ref));
  }

  void dispose() {
    _subscription?.cancel();
  }

  /// Trigger buy flow for "remove_ads" product
  Future<bool> buyRemoveAds() async {
    try {
      if (!await _iap.isAvailable()) return false;
      final response = await _iap.queryProductDetails({removeAdsProductId});
      if (response.error != null) return false;
      final products = response.productDetails.where(
        (product) => product.id == removeAdsProductId,
      );
      if (products.isEmpty) return false;
      final ProductDetails productDetails = products.first;
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (_) {
      return false;
    }
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

  void _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
    WidgetRef ref,
  ) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.productID == removeAdsProductId) {
        if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Entitle user: Disable all ads across app permanently
          unawaited(ref.read(adProvider.notifier).purchaseAdFree(true));

          if (purchaseDetails.pendingCompletePurchase) {
            unawaited(_iap.completePurchase(purchaseDetails));
          }
        }
      }
    }
  }
}
