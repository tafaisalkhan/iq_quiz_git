import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../features/settings/presentation/providers/ad_provider.dart';
import '../config/app_config.dart';
import '../services/ad_service.dart';

class AdBannerWidget extends ConsumerStatefulWidget {
  final bool isTopBanner;

  const AdBannerWidget({
    super.key,
    required this.isTopBanner,
  });

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    if (!AppConfig.enableAds || AdService.isAdFreeToday) return;

    final adUnitId = Theme.of(context).platform == TargetPlatform.iOS
        ? AdService.iosBannerId
        : AdService.androidBannerId;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          AdService.markNoFillTodayAndNotify(adUnitId);
          if (!mounted) return;
          setState(() {
            _isAdLoaded = false;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.enableAds) {
      return const SizedBox.shrink();
    }

    final adState = ref.watch(adProvider);
    if (adState.isAdFreePurchased) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AdService.adFreeTodayNotifier,
      builder: (context, isAdFreeToday, _) {
        if (isAdFreeToday || !_isAdLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }
        return Container(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          alignment: Alignment.center,
          child: AdWidget(ad: _bannerAd!),
        );
      },
    );
  }
}
