/// AdMob banner support.
///
/// Ads are mobile-only and entirely optional: on web, desktop, in tests, or
/// when [AdsConfig.enabled] is false, [AdBanner] renders nothing and no ad SDK
/// call is made. That keeps the rest of the app testable and keeps the web
/// build working, since `google_mobile_ads` has no web implementation.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsConfig {
  AdsConfig._();

  /// Master switch. Build with `--dart-define=ADS_ENABLED=true` to turn ads on;
  /// they stay off by default so debug and test runs never touch the network.
  static const bool enabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  /// Google's official test unit IDs. Replace with your own AdMob unit IDs via
  /// `--dart-define` before shipping — serving real ads to yourself, or test
  /// ads in production, both violate AdMob policy.
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';

  static const String _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: _testBannerAndroid,
  );
  static const String _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: _testBannerIos,
  );

  static bool get usingTestUnits =>
      _bannerAndroid == _testBannerAndroid || _bannerIos == _testBannerIos;

  /// True only where the AdMob SDK actually exists.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get active => enabled && supported;

  static String get bannerUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _bannerIos : _bannerAndroid;

  /// Call once at startup. A no-op where ads are unavailable.
  static Future<void> init() async {
    if (!active) return;
    await MobileAds.instance.initialize();
  }
}

/// An adaptive banner pinned wherever it is placed. Occupies zero space until
/// an ad has actually loaded, so the layout never shows an empty gap.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdsConfig.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final double width = MediaQuery.sizeOf(context).width;

    final AdSize? size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          MediaQuery.orientationOf(context),
          width.truncate(),
        );
    if (size == null || !mounted) return;

    final BannerAd ad = BannerAd(
      size: size,
      adUnitId: AdsConfig.bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          debugPrint('Banner failed to load: $error');
        },
      ),
    );

    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
