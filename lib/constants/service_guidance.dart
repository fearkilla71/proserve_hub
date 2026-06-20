import 'service_types.dart';

class ServiceGuidance {
  const ServiceGuidance({
    required this.summary,
    required this.customerQuestions,
    required this.photoTips,
    required this.quoteLineItems,
    required this.matchSignals,
    this.manualQuoteReason,
  });

  final String summary;
  final List<String> customerQuestions;
  final List<String> photoTips;
  final List<String> quoteLineItems;
  final List<String> matchSignals;
  final String? manualQuoteReason;
}

const _defaultGuidance = ServiceGuidance(
  summary:
      'Describe the work, timeline, location, and any photos that help pros price it accurately.',
  customerQuestions: [
    'What needs to be done?',
    'What is the approximate size or quantity?',
    'When do you want the work completed?',
    'Are there access, safety, or material details the pro should know?',
  ],
  photoTips: [
    'Wide photo of the full work area',
    'Close-up of the issue or surface',
    'Any access points, measurements, or existing materials',
  ],
  quoteLineItems: [
    'Labor',
    'Materials',
    'Setup and cleanup',
    'Warranty or follow-up',
  ],
  matchSignals: [
    'Offers this service',
    'Works in your area',
    'Verified profile',
  ],
  manualQuoteReason:
      'This service needs a pro to review details before quoting.',
);

const _guidanceByCanonicalService = <String, ServiceGuidance>{
  'Roofing': ServiceGuidance(
    summary:
        'Roofing requests work best with photos, roof type, leak details, and urgency.',
    customerQuestions: [
      'Is this a repair, leak, inspection, or replacement?',
      'What roof type do you have: shingle, metal, tile, flat, or other?',
      'How many stories is the home?',
      'Do you see active leaking, missing shingles, or storm damage?',
      'Is insurance involved?',
    ],
    photoTips: [
      'Exterior roof angle from the ground',
      'Close-up of leak, ceiling stain, or damaged area',
      'Attic or interior water damage if safe to photograph',
    ],
    quoteLineItems: [
      'Roof inspection and diagnosis',
      'Materials and shingles',
      'Flashing, vents, and underlayment',
      'Labor and safety setup',
      'Debris removal and warranty',
    ],
    matchSignals: [
      'Roofing service match',
      'Storm/leak repair experience',
      'Verified and reviewed',
    ],
    manualQuoteReason:
        'Roofing prices depend on roof pitch, access, layers, and hidden damage.',
  ),
  'Plumbing': ServiceGuidance(
    summary:
        'Plumbing requests should capture fixture, leak/clog severity, and emergency status.',
    customerQuestions: [
      'Is this a leak, clog, installation, replacement, or diagnosis?',
      'Which fixture or line is affected?',
      'Can the water be shut off?',
      'Is there visible water damage or sewage backup?',
      'Is this urgent or after-hours?',
    ],
    photoTips: [
      'Photo of the fixture or pipe area',
      'Close-up of leak, valve, or drain',
      'Any visible water damage',
    ],
    quoteLineItems: [
      'Diagnosis or service call',
      'Labor',
      'Parts and fixtures',
      'Emergency or access fee',
      'Cleanup and testing',
    ],
    matchSignals: [
      'Plumbing service match',
      'Emergency availability',
      'Verified and reviewed',
    ],
    manualQuoteReason: 'Plumbing prices vary by access, parts, and severity.',
  ),
  'HVAC': ServiceGuidance(
    summary:
        'HVAC requests need system type, symptoms, age, and whether heat or cooling is down.',
    customerQuestions: [
      'Is this repair, maintenance, replacement, or installation?',
      'What system type do you have?',
      'What symptoms are you seeing?',
      'How old is the system?',
      'Is heating or cooling completely out?',
    ],
    photoTips: [
      'Thermostat display',
      'Indoor unit label or model plate',
      'Outdoor condenser or furnace area',
    ],
    quoteLineItems: [
      'Diagnostic visit',
      'Labor',
      'Parts or equipment',
      'Refrigerant or materials',
      'System testing',
    ],
    matchSignals: [
      'HVAC service match',
      'Repair/install experience',
      'Verified and reviewed',
    ],
    manualQuoteReason:
        'HVAC pricing depends on system condition, equipment, and parts.',
  ),
  'House Cleaning': ServiceGuidance(
    summary:
        'Cleaning requests should define home size, cleaning level, rooms, and add-ons.',
    customerQuestions: [
      'Is this standard, deep, move-out, or recurring cleaning?',
      'How many bedrooms and bathrooms?',
      'What is the approximate square footage?',
      'Do you need fridge, oven, windows, or baseboards included?',
      'Will pets or special access instructions be involved?',
    ],
    photoTips: [
      'Kitchen and main living area',
      'Bathrooms needing attention',
      'Any areas needing deep cleaning',
    ],
    quoteLineItems: [
      'Cleaning labor',
      'Supplies',
      'Deep-clean add-ons',
      'Travel or access fee',
      'Recurring service discount',
    ],
    matchSignals: [
      'Cleaning service match',
      'Recurring or move-out experience',
      'Reviewed by homeowners',
    ],
    manualQuoteReason:
        'Cleaning pricing depends on room count, condition, and add-ons.',
  ),
  'Moving Services': ServiceGuidance(
    summary:
        'Moving requests need home size, stairs, distance, heavy items, and packing help.',
    customerQuestions: [
      'How many bedrooms or rooms are being moved?',
      'What ZIP code are you moving from and to?',
      'Are there stairs, elevators, or long carries?',
      'Do you have heavy or fragile items?',
      'Do you need packing, boxes, or furniture assembly?',
    ],
    photoTips: [
      'Largest rooms or packed items',
      'Stairs, elevator, or entry access',
      'Heavy items like safes, pianos, or appliances',
    ],
    quoteLineItems: [
      'Crew labor',
      'Truck and travel',
      'Packing materials',
      'Heavy item handling',
      'Furniture assembly or disassembly',
    ],
    matchSignals: [
      'Moving service match',
      'Truck/crew availability',
      'Verified and reviewed',
    ],
    manualQuoteReason:
        'Moving prices depend on distance, access, crew size, and item count.',
  ),
};

ServiceGuidance guidanceForService(String? service) {
  final canonical = canonicalServiceName(service ?? '');
  return _guidanceByCanonicalService[canonical] ?? _defaultGuidance;
}

bool hasSpecificGuidance(String? service) {
  return _guidanceByCanonicalService.containsKey(
    canonicalServiceName(service ?? ''),
  );
}
