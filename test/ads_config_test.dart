import 'package:flutter_test/flutter_test.dart';
import 'package:noted/data/ads.dart';

void main() {
  group('AdsConfig defaults', () {
    // These assert the properties a CI grep cannot: that a build with no
    // --dart-define flags is inert, and that it can tell it is using Google's
    // sample unit IDs rather than real ones.

    test('ads are off unless explicitly enabled at build time', () {
      expect(
        AdsConfig.enabled,
        isFalse,
        reason:
            'ADS_ENABLED must default to false so debug, test and web '
            'runs never touch the ad network',
      );
    });

    test('nothing is active without the build flag', () {
      // active = enabled && supported. enabled is false here, so whatever the
      // host platform reports, no ad SDK call should ever be made.
      expect(AdsConfig.active, isFalse);
    });

    test('a build with no unit IDs knows it is on test units', () {
      expect(
        AdsConfig.usingTestUnits,
        isTrue,
        reason:
            'without ADMOB_BANNER_* the defaults are Google sample units; '
            'shipping those violates AdMob policy, so the app must be able to '
            'detect it',
      );
    });

    test('the banner unit ID is always non-empty', () {
      // An empty unit ID crashes the SDK rather than failing to fill.
      expect(AdsConfig.bannerUnitId, isNotEmpty);
      expect(AdsConfig.bannerUnitId, startsWith('ca-app-pub-'));
    });
  });
}
