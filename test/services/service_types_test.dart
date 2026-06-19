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
