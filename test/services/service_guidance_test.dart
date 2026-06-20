import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/constants/service_guidance.dart';

void main() {
  group('service guidance', () {
    test('provides deep guidance for top release services', () {
      for (final service in [
        'Roofing',
        'Plumbing',
        'HVAC',
        'House Cleaning',
        'Moving Services',
      ]) {
        final guidance = guidanceForService(service);
        expect(guidance.customerQuestions.length, greaterThanOrEqualTo(5));
        expect(guidance.photoTips, isNotEmpty);
        expect(guidance.quoteLineItems.length, greaterThanOrEqualTo(4));
        expect(guidance.manualQuoteReason, isNotNull);
        expect(hasSpecificGuidance(service), isTrue);
      }
    });

    test('uses aliases when resolving guidance', () {
      expect(guidanceForService('HVAC Repair').summary, contains('HVAC'));
      expect(guidanceForService('Pool Service').manualQuoteReason, isNotNull);
    });

    test('falls back for unsupported specific guidance without crashing', () {
      final guidance = guidanceForService('Wallpaper Removal & Install');
      expect(guidance.customerQuestions, isNotEmpty);
      expect(hasSpecificGuidance('Wallpaper Removal & Install'), isFalse);
    });
  });
}
