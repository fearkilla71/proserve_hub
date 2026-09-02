import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/constants/launch_regions.dart';

void main() {
  group('launch region helpers', () {
    test('normalizes ZIP input to the first five digits', () {
      expect(normalizeZip('77002-1234'), '77002');
      expect(normalizeZip(' 77584 '), '77584');
      expect(normalizeZip('abc77002'), '77002');
    });

    test('allows Houston metro launch ZIPs', () {
      expect(isSupportedLaunchZip('77002'), isTrue);
      expect(isSupportedLaunchZip('77494'), isTrue);
      expect(isSupportedLaunchZip('77380'), isTrue);
      expect(isSupportedLaunchZip('77584'), isTrue);
      expect(launchRegionForZip('77002'), kLaunchRegionHoustonMetro);
      expect(marketStatusForZip('77002'), kMarketStatusActive);
    });

    test('sends unsupported ZIPs to waitlist', () {
      expect(isSupportedLaunchZip('78701'), isFalse);
      expect(isSupportedLaunchZip('75201'), isFalse);
      expect(launchRegionForZip('78701'), kLaunchRegionUnsupported);
      expect(marketStatusForZip('78701'), kMarketStatusWaitlist);
    });

    test('detects waitlisted profiles', () {
      expect(isWaitlistedProfile({'marketStatus': 'waitlist'}), isTrue);
      expect(isWaitlistedProfile({'marketStatus': 'active'}), isFalse);
      expect(isWaitlistedProfile({}), isFalse);
    });
  });
}
