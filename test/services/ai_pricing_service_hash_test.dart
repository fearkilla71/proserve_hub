import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/services/ai_pricing_service.dart';

void main() {
  group('AiPricingService pricing input hash', () {
    test('is stable when map key order changes', () {
      final service = AiPricingService.instance;
      final first = service.buildPricingInput(
        service: ' Painting ',
        quantity: 4,
        zip: '77093',
        urgent: false,
        jobDetails: {
          'paintingQuestions': {
            'rooms_painting': 4,
            'wall_condition': 'fair',
          },
          'description': 'Living room and kitchen',
        },
      );
      final second = service.buildPricingInput(
        service: 'Painting',
        quantity: 4.0,
        zip: '77093',
        urgent: false,
        jobDetails: {
          'description': 'Living room and kitchen',
          'paintingQuestions': {
            'wall_condition': 'fair',
            'rooms_painting': 4.0,
          },
        },
      );

      expect(service.hashPricingInput(first), service.hashPricingInput(second));
    });

    test('changes when a meaningful project detail changes', () {
      final service = AiPricingService.instance;
      final base = service.buildPricingInput(
        service: 'Painting',
        quantity: 4,
        zip: '77093',
        urgent: false,
        jobDetails: {
          'paintingQuestions': {'rooms_painting': 4},
        },
      );
      final changed = service.buildPricingInput(
        service: 'Painting',
        quantity: 5,
        zip: '77093',
        urgent: false,
        jobDetails: {
          'paintingQuestions': {'rooms_painting': 5},
        },
      );

      expect(
        service.hashPricingInput(base),
        isNot(service.hashPricingInput(changed)),
      );
    });

    test('does not include loyalty discount in the scope hash', () {
      final service = AiPricingService.instance;
      final input = service.buildPricingInput(
        service: 'Painting',
        quantity: 4,
        zip: '77093',
        urgent: false,
        jobDetails: {
          'paintingQuestions': {'rooms_painting': 4},
        },
      );

      final hashBeforeRewardChange = service.hashPricingInput(input);
      final hashAfterRewardChange = service.hashPricingInput({
        ...input,
        // Historical snapshots may contain this field, but new scope hashes
        // intentionally ignore rewards so locked prices do not drift.
        'loyaltyDiscount': 0.08,
      });

      expect(hashBeforeRewardChange, hashAfterRewardChange);
    });
  });
}
