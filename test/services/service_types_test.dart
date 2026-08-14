import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/constants/service_types.dart';

void main() {
  group('service catalog normalization', () {
    test('normalizes cabinet aliases to the canonical service', () {
      expect(canonicalServiceName('Cabinet Painting'), 'Cabinets');
      expect(canonicalServiceName('Cabinet Refinishing'), 'Cabinets');
      expect(serviceMatches('Cabinets', 'Cabinet Painting'), isTrue);
    });

    test('matches broad painting to specific painting services', () {
      expect(serviceMatches('Interior Painting', 'Painting'), isTrue);
      expect(serviceMatches('Exterior Painting', 'Painting'), isTrue);
      expect(serviceMatches('Commercial Painting', 'Painting'), isTrue);
      expect(serviceMatches('Roofing', 'Painting'), isFalse);
    });

    test('keeps broad home services in the shared catalog', () {
      expect(kContractorServiceCatalog, contains('Roofing'));
      expect(kContractorServiceCatalog, contains('HVAC'));
      expect(kContractorServiceCatalog, contains('Plumbing'));
      expect(kContractorServiceCatalog, contains('Electrical'));
      expect(kContractorServiceCatalog, contains('General Handyman'));
      expect(kContractorServiceCatalog, contains('House Cleaning'));
      expect(kContractorServiceCatalog, contains('Appliance Repair'));
      expect(kContractorServiceCatalog, contains('Siding'));
      expect(kContractorServiceCatalog, contains('Home Inspection'));
      expect(kContractorServiceCatalog, contains('Mold Testing & Remediation'));
      expect(kContractorServiceCatalog, contains('Moving Services'));
      expect(kContractorServiceCatalog, contains('Smart Home Installation'));
    });

    test('grouped service categories do not duplicate canonical services', () {
      final seen = <String>{};
      for (final category in kHomeServiceCategories.entries) {
        for (final service in category.value) {
          final key = serviceKey(canonicalServiceName(service));
          expect(
            seen.add(key),
            isTrue,
            reason: '${category.key} repeats $service',
          );
        }
      }
    });

    test('normalizes release catalog aliases from large marketplaces', () {
      expect(canonicalServiceName('Power Washing'), 'Pressure Washing');
      expect(canonicalServiceName('HVAC Repair'), 'HVAC');
      expect(canonicalServiceName('Furnace Maintenance'), 'HVAC');
      expect(
        canonicalServiceName('Pool Service'),
        'Pool Cleaning & Maintenance',
      );
      expect(
        canonicalServiceName('Security Cameras'),
        'Security Camera Installation',
      );
      expect(canonicalServiceName('Movers'), 'Moving Services');
      expect(canonicalServiceName('TV Mounting'), 'TV Mounting');
      expect(
        canonicalServiceName('Mold Remediation'),
        'Mold Testing & Remediation',
      );
    });

    test('keeps new release services out of instant pricing', () {
      expect(supportsInstantPrice('Interior Painting'), isTrue);
      expect(supportsInstantPrice('Cabinet Painting'), isTrue);
      expect(supportsInstantPrice('House Cleaning'), isFalse);
      expect(supportsInstantPrice('Roofing'), isFalse);
      expect(supportsInstantPrice('Home Inspection'), isFalse);
      expect(supportsInstantPrice('Moving Services'), isFalse);
    });

    test('adds release services to quick smart-request choices', () {
      expect(kQuickServices['house_cleaning'], 'House Cleaning');
      expect(kQuickServices['appliance_repair'], 'Appliance Repair');
      expect(
        kQuickServices['gutter_repair_installation'],
        'Gutter Repair & Installation',
      );
      expect(
        kQuickServices['security_camera_installation'],
        'Security Camera Installation',
      );
      expect(kQuickServices['moving_services'], 'Moving Services');
    });

    test(
      'merges legacy contractor service fields and de-duplicates aliases',
      () {
        final services = contractorServicesFromData({
          'services': ['Interior Painting', 'Cabinet Painting'],
          'servicesOffered': ['Cabinets', 'Roofing'],
          'serviceTypes': ['Drywall Repair & Texture'],
        });

        expect(services, [
          'Interior Painting',
          'Cabinets',
          'Roofing',
          'Drywall Repair',
        ]);
      },
    );
  });
}
