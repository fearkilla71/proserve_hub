import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/constants/service_intake.dart';
import 'package:proserve_hub/constants/service_types.dart';

void main() {
  group('service intake definitions', () {
    test('every catalog service resolves to a definition or fallback', () {
      for (final service in kContractorServiceCatalog) {
        final definition = intakeDefinitionForService(service);
        expect(definition.questions, isNotEmpty, reason: service);
        expect(definition.photoPrompts, isNotEmpty, reason: service);
        expect(definition.quoteLineItems, isNotEmpty, reason: service);
      }
    });

    test('every catalog service can produce a complete lead payload', () {
      for (final service in kContractorServiceCatalog) {
        final definition = intakeDefinitionForService(service);
        final answers = _sampleAnswersFor(definition);
        final missing = requiredMissingFields(definition, answers);
        final score = leadQualityScore(
          definition: definition,
          answers: answers,
          photoCount: 3,
          zip: '77093',
          timeline: 'asap',
          budgetPreference: 'recommended',
        );
        final brief = contractorBriefForLead(
          service: service,
          definition: definition,
          answers: answers,
          photoCount: 3,
          zip: '77093',
          timeline: 'asap',
          notes: 'QA request for service intake coverage.',
        );
        final tags = matchTagsForAnswers(definition, answers);

        expect(missing, isEmpty, reason: service);
        expect(score, greaterThanOrEqualTo(75), reason: service);
        expect(
          leadQualityLabel(score, missing),
          'Strong lead',
          reason: service,
        );
        expect(serviceSlug(service), isNotEmpty, reason: service);
        expect(brief, contains(service), reason: service);
        expect(brief, contains('77093'), reason: service);
        expect(tags, isNotEmpty, reason: service);

        final expectedRoute = supportsInstantPrice(service)
            ? 'ai-price-offer'
            : 'recommended-pros';
        expect(expectedRoute, isNotEmpty, reason: service);
      }
    });

    test('release-priority services have specific required fields', () {
      for (final service in [
        'Interior Painting',
        'Cabinets',
        'Drywall Repair',
        'Pressure Washing',
        'Roofing',
        'Plumbing',
        'HVAC',
        'Electrical',
        'House Cleaning',
        'Moving Services',
        'Landscaping',
        'General Handyman',
      ]) {
        final definition = intakeDefinitionForService(service);
        expect(hasSpecificIntakeDefinition(service), isTrue, reason: service);
        expect(
          definition.questions.where((q) => q.required),
          isNotEmpty,
          reason: service,
        );
      }
    });

    test('lead quality score increases with better lead data', () {
      final definition = intakeDefinitionForService('Roofing');
      final weak = leadQualityScore(
        definition: definition,
        answers: const <String, dynamic>{},
        photoCount: 0,
        zip: '',
        timeline: '',
        budgetPreference: '',
      );
      final strong = leadQualityScore(
        definition: definition,
        answers: const {
          'roofing_need': 'Active leak',
          'roof_type': 'Shingle',
          'stories': '2',
          'active_leak': true,
          'insurance': true,
          'roof_age': '11-20 years',
        },
        photoCount: 4,
        zip: '77093',
        timeline: 'asap',
        budgetPreference: 'recommended',
      );

      expect(strong, greaterThan(weak));
      expect(leadQualityLabel(strong, const []), 'Strong lead');
    });

    test('required missing fields are reported by customer-facing label', () {
      final definition = intakeDefinitionForService('Plumbing');
      final missing = requiredMissingFields(definition, const {
        'plumbing_need': 'Leak',
      });

      expect(missing, contains('What is affected?'));
    });

    test('contractor brief summarizes trade-specific answers', () {
      final definition = intakeDefinitionForService('HVAC');
      final brief = contractorBriefForLead(
        service: 'HVAC',
        definition: definition,
        answers: const {
          'hvac_need': 'Repair',
          'system_type': 'Central AC',
          'symptoms': ['No cooling', 'Weak airflow'],
          'system_age': '11-15 years',
          'fully_out': true,
        },
        photoCount: 3,
        zip: '77093',
        timeline: 'asap',
      );

      expect(brief, contains('HVAC'));
      expect(brief, contains('Central AC'));
      expect(brief, contains('3 photos uploaded'));
    });

    test('match tags include inferred urgency and recurring signals', () {
      final roofTags = matchTagsForAnswers(
        intakeDefinitionForService('Roofing'),
        const {'roofing_need': 'Active leak', 'insurance': true},
      );
      final cleaningTags = matchTagsForAnswers(
        intakeDefinitionForService('House Cleaning'),
        const {'cleaning_type': 'Recurring'},
      );

      expect(roofTags, contains('emergency'));
      expect(roofTags, contains('insurance'));
      expect(cleaningTags, contains('recurring'));
    });
  });
}

Map<String, dynamic> _sampleAnswersFor(ServiceIntakeDefinition definition) {
  return {
    for (final question in definition.questions)
      question.id: switch (question.type) {
        ServiceIntakeQuestionType.choice =>
          question.options.isNotEmpty ? question.options.first : 'Repair',
        ServiceIntakeQuestionType.multiChoice =>
          question.options.take(2).toList(growable: false),
        ServiceIntakeQuestionType.number => 3,
        ServiceIntakeQuestionType.text =>
          'Customer supplied clear project notes.',
        ServiceIntakeQuestionType.yesNo => true,
      },
  };
}
