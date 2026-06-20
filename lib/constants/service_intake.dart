import 'service_types.dart';

enum ServiceIntakeQuestionType { choice, multiChoice, number, text, yesNo }

class ServiceIntakeQuestion {
  const ServiceIntakeQuestion({
    required this.id,
    required this.label,
    required this.type,
    this.options = const <String>[],
    this.required = false,
    this.helper,
    this.unit,
  });

  final String id;
  final String label;
  final ServiceIntakeQuestionType type;
  final List<String> options;
  final bool required;
  final String? helper;
  final String? unit;
}

class ServiceIntakeDefinition {
  const ServiceIntakeDefinition({
    required this.service,
    required this.summary,
    required this.questions,
    required this.photoPrompts,
    required this.quoteLineItems,
    required this.matchTags,
    this.version = 1,
  });

  final String service;
  final String summary;
  final List<ServiceIntakeQuestion> questions;
  final List<String> photoPrompts;
  final List<String> quoteLineItems;
  final List<String> matchTags;
  final int version;
}

const _genericDefinition = ServiceIntakeDefinition(
  service: 'General Home Service',
  summary:
      'Collect clear project scope, photos, access details, timing, and budget fit so pros can quote with fewer callbacks.',
  questions: [
    ServiceIntakeQuestion(
      id: 'project_type',
      label: 'What type of help do you need?',
      type: ServiceIntakeQuestionType.choice,
      required: true,
      options: ['Repair', 'Install', 'Replace', 'Maintenance', 'Inspection'],
    ),
    ServiceIntakeQuestion(
      id: 'quantity',
      label: 'Approximate size or quantity',
      type: ServiceIntakeQuestionType.number,
      required: true,
      helper: 'Use your best estimate. Pros can confirm later.',
    ),
    ServiceIntakeQuestion(
      id: 'access',
      label: 'Any access or safety details?',
      type: ServiceIntakeQuestionType.multiChoice,
      options: ['Stairs', 'High area', 'Tight access', 'Occupied home', 'Pets'],
    ),
    ServiceIntakeQuestion(
      id: 'materials_ready',
      label: 'Do you already have materials?',
      type: ServiceIntakeQuestionType.yesNo,
    ),
    ServiceIntakeQuestion(
      id: 'scope_notes',
      label: 'What should the pro know before quoting?',
      type: ServiceIntakeQuestionType.text,
    ),
  ],
  photoPrompts: [
    'Wide photo of the full work area',
    'Close-up of the issue or surface',
    'Access points, measurements, or existing materials',
  ],
  quoteLineItems: ['Labor', 'Materials', 'Setup and cleanup', 'Warranty'],
  matchTags: ['manual-quote'],
);

final Map<String, ServiceIntakeDefinition> _definitions = {
  'Painting': const ServiceIntakeDefinition(
    service: 'Painting',
    summary:
        'Capture rooms, surface condition, paint scope, trim, ceilings, and whether paint is included.',
    questions: [
      ServiceIntakeQuestion(
        id: 'paint_scope',
        label: 'What are you painting?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Interior', 'Exterior', 'Commercial', 'Touch-up'],
      ),
      ServiceIntakeQuestion(
        id: 'rooms',
        label: 'How many rooms or areas?',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'extras',
        label: 'Include any extras?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: ['Ceilings', 'Trim', 'Doors', 'Cabinets', 'Accent wall'],
      ),
      ServiceIntakeQuestion(
        id: 'surface_condition',
        label: 'Surface condition',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Excellent', 'Fair', 'Needs repair', 'Peeling or damaged'],
      ),
      ServiceIntakeQuestion(
        id: 'paint_included',
        label: 'Do you want paint included?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'color_change',
        label: 'Is this a color change?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'occupancy',
        label: 'Will the space be occupied?',
        type: ServiceIntakeQuestionType.choice,
        options: ['Occupied', 'Vacant', 'Not sure'],
      ),
    ],
    photoPrompts: [
      'Wide photos of each room or exterior side',
      'Close-up of damaged or patched areas',
      'Trim, ceilings, doors, or color-change examples',
    ],
    quoteLineItems: ['Labor', 'Paint/materials', 'Prep/repairs', 'Cleanup'],
    matchTags: ['painting', 'surface-prep'],
  ),
  'Interior Painting': const ServiceIntakeDefinition(
    service: 'Interior Painting',
    summary:
        'Capture rooms, ceilings, trim, doors, condition, paint preference, and occupancy.',
    questions: [
      ServiceIntakeQuestion(
        id: 'rooms',
        label: 'How many rooms?',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'room_types',
        label: 'Which spaces are included?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Bedrooms',
          'Bathrooms',
          'Kitchen',
          'Living room',
          'Hallways',
          'Closets',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'extras',
        label: 'Include any extras?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: ['Ceilings', 'Trim', 'Doors', 'Crown molding', 'Accent wall'],
      ),
      ServiceIntakeQuestion(
        id: 'surface_condition',
        label: 'Wall condition',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Excellent', 'Fair', 'Needs patching', 'Heavy repair'],
      ),
      ServiceIntakeQuestion(
        id: 'paint_included',
        label: 'Do you want paint included?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'color_change',
        label: 'Is this a color change?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Wide room photos',
      'Close-ups of wall damage',
      'Photos of trim, ceilings, doors, or accent walls',
    ],
    quoteLineItems: [
      'Labor',
      'Paint/materials',
      'Wall prep',
      'Trim/ceiling extras',
    ],
    matchTags: ['interior-painting', 'surface-prep'],
  ),
  'Exterior Painting': const ServiceIntakeDefinition(
    service: 'Exterior Painting',
    summary:
        'Capture exterior surface, stories, condition, sqft, paint scope, and access.',
    questions: [
      ServiceIntakeQuestion(
        id: 'exterior_sqft',
        label: 'Approximate exterior square feet',
        type: ServiceIntakeQuestionType.number,
        required: true,
        unit: 'sqft',
      ),
      ServiceIntakeQuestion(
        id: 'stories',
        label: 'How many stories?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['1', '2', '3+'],
      ),
      ServiceIntakeQuestion(
        id: 'surface_type',
        label: 'Exterior surface',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Siding',
          'Brick',
          'Stucco',
          'Wood',
          'Trim',
          'Doors',
          'Shutters',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'surface_condition',
        label: 'Surface condition',
        type: ServiceIntakeQuestionType.choice,
        options: ['Good', 'Faded', 'Peeling', 'Needs repair'],
      ),
      ServiceIntakeQuestion(
        id: 'paint_included',
        label: 'Do you want paint included?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Front, sides, and back exterior photos',
      'Close-ups of peeling or damaged areas',
      'Doors, shutters, trim, deck, or fence areas',
    ],
    quoteLineItems: [
      'Labor',
      'Paint/materials',
      'Prep/washing',
      'Ladders/safety',
    ],
    matchTags: ['exterior-painting', 'multi-story'],
  ),
  'Cabinets': const ServiceIntakeDefinition(
    service: 'Cabinets',
    summary:
        'Capture cabinet count, doors, drawers, finish type, interiors, hardware, island, and condition.',
    questions: [
      ServiceIntakeQuestion(
        id: 'work_type',
        label: 'What cabinet work do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Paint', 'Stain', 'Refinish', 'Repair', 'New install'],
      ),
      ServiceIntakeQuestion(
        id: 'cabinet_doors',
        label: 'How many cabinet doors?',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'cabinet_drawers',
        label: 'How many drawers?',
        type: ServiceIntakeQuestionType.number,
      ),
      ServiceIntakeQuestion(
        id: 'extras',
        label: 'Include any extras?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Paint interiors',
          'Island',
          'Crown molding',
          'Hardware reinstall',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'condition',
        label: 'Cabinet condition',
        type: ServiceIntakeQuestionType.choice,
        options: ['Good', 'Worn finish', 'Damaged', 'Needs repair'],
      ),
      ServiceIntakeQuestion(
        id: 'color_change',
        label: 'Is this a color change?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Full kitchen cabinet view',
      'Close-up of doors and drawer fronts',
      'Damaged areas, island, hardware, or interior shelves',
    ],
    quoteLineItems: [
      'Prep/sanding',
      'Paint/stain',
      'Doors/drawers',
      'Hardware',
    ],
    matchTags: ['cabinet-painting', 'fine-finish'],
  ),
  'Drywall Repair': const ServiceIntakeDefinition(
    service: 'Drywall Repair',
    summary:
        'Capture repair type, damage size, texture, wall/ceiling location, and whether painting is needed.',
    questions: [
      ServiceIntakeQuestion(
        id: 'repair_type',
        label: 'What drywall help do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: [
          'Hole repair',
          'Cracks',
          'Water damage',
          'Texture match',
          'Install new drywall',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'damage_count',
        label: 'How many damaged areas?',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'locations',
        label: 'Where is the work?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: ['Wall', 'Ceiling', 'Corner', 'Garage', 'Bathroom'],
      ),
      ServiceIntakeQuestion(
        id: 'texture',
        label: 'Texture type',
        type: ServiceIntakeQuestionType.choice,
        options: ['Smooth', 'Orange peel', 'Knockdown', 'Popcorn', 'Not sure'],
      ),
      ServiceIntakeQuestion(
        id: 'painting_needed',
        label: 'Will painting be needed after repair?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Wide photo showing where damage is located',
      'Close-up of each damaged area',
      'Texture close-up for matching',
    ],
    quoteLineItems: [
      'Patch/repair',
      'Texture match',
      'Materials',
      'Painting add-on',
    ],
    matchTags: ['drywall', 'texture-match'],
  ),
  'Pressure Washing': const ServiceIntakeDefinition(
    service: 'Pressure Washing',
    summary:
        'Capture surface type, approximate size, stains, water access, and multi-story needs.',
    questions: [
      ServiceIntakeQuestion(
        id: 'surfaces',
        label: 'What needs pressure washing?',
        type: ServiceIntakeQuestionType.multiChoice,
        required: true,
        options: [
          'Driveway',
          'Siding',
          'Deck',
          'Fence',
          'Patio',
          'Roof',
          'Walkway',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'sqft',
        label: 'Approximate square feet',
        type: ServiceIntakeQuestionType.number,
        required: true,
        unit: 'sqft',
      ),
      ServiceIntakeQuestion(
        id: 'stains',
        label: 'What stains are present?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: ['Mold', 'Algae', 'Oil', 'Rust', 'Paint', 'General dirt'],
      ),
      ServiceIntakeQuestion(
        id: 'water_access',
        label: 'Is water access available?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'multi_story',
        label: 'Is any work above one story?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Wide photo of every surface',
      'Close-up of stains',
      'Water spigot or access area',
    ],
    quoteLineItems: [
      'Surface cleaning',
      'Stain treatment',
      'Water/access setup',
      'Cleanup',
    ],
    matchTags: ['pressure-washing', 'exterior-cleaning'],
  ),
  'Roofing': const ServiceIntakeDefinition(
    service: 'Roofing',
    summary:
        'Capture repair/replacement type, roof material, stories, leaks, storm damage, and insurance status.',
    questions: [
      ServiceIntakeQuestion(
        id: 'roofing_need',
        label: 'What roofing help do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: [
          'Repair',
          'Active leak',
          'Inspection',
          'Replacement',
          'Storm damage',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'roof_type',
        label: 'Roof type',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Shingle', 'Metal', 'Tile', 'Flat', 'Not sure'],
      ),
      ServiceIntakeQuestion(
        id: 'stories',
        label: 'How many stories?',
        type: ServiceIntakeQuestionType.choice,
        options: ['1', '2', '3+'],
      ),
      ServiceIntakeQuestion(
        id: 'active_leak',
        label: 'Is there active leaking?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'insurance',
        label: 'Is insurance involved?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'roof_age',
        label: 'Approximate roof age',
        type: ServiceIntakeQuestionType.choice,
        options: [
          '0-5 years',
          '6-10 years',
          '11-20 years',
          '20+ years',
          'Not sure',
        ],
      ),
    ],
    photoPrompts: [
      'Roof angle from the ground',
      'Ceiling stain or active leak area',
      'Missing shingles, flashing, vents, or storm damage',
    ],
    quoteLineItems: [
      'Inspection',
      'Materials',
      'Labor/safety setup',
      'Debris removal',
    ],
    matchTags: ['roofing', 'insurance', 'emergency'],
  ),
  'Plumbing': const ServiceIntakeDefinition(
    service: 'Plumbing',
    summary:
        'Capture issue type, fixture, shutoff status, water damage, sewage backup, and urgency.',
    questions: [
      ServiceIntakeQuestion(
        id: 'plumbing_need',
        label: 'What plumbing help do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Leak', 'Clog', 'Install', 'Replace', 'Diagnosis'],
      ),
      ServiceIntakeQuestion(
        id: 'fixture',
        label: 'What is affected?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: [
          'Toilet',
          'Sink',
          'Tub/shower',
          'Water heater',
          'Main line',
          'Pipe',
          'Other',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'water_shutoff',
        label: 'Can the water be shut off?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'water_damage',
        label: 'Is there visible water damage?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'sewage_backup',
        label: 'Is sewage backing up?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Fixture or pipe area',
      'Close-up of leak, clog, or valve',
      'Water damage or floor/cabinet area',
    ],
    quoteLineItems: [
      'Diagnostic/service call',
      'Labor',
      'Parts/fixtures',
      'Testing/cleanup',
    ],
    matchTags: ['plumbing', 'emergency'],
  ),
  'HVAC': const ServiceIntakeDefinition(
    service: 'HVAC',
    summary:
        'Capture system type, repair/install need, symptoms, age, outage status, and model photos.',
    questions: [
      ServiceIntakeQuestion(
        id: 'hvac_need',
        label: 'What HVAC help do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Repair', 'Maintenance', 'Install', 'Replace', 'Diagnosis'],
      ),
      ServiceIntakeQuestion(
        id: 'system_type',
        label: 'System type',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: [
          'Central AC',
          'Furnace',
          'Heat pump',
          'Mini split',
          'Not sure',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'symptoms',
        label: 'What symptoms are you seeing?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'No cooling',
          'No heat',
          'Noise',
          'Leak',
          'Short cycling',
          'Weak airflow',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'system_age',
        label: 'Approximate system age',
        type: ServiceIntakeQuestionType.choice,
        options: [
          '0-5 years',
          '6-10 years',
          '11-15 years',
          '15+ years',
          'Not sure',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'fully_out',
        label: 'Is heating or cooling completely out?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Thermostat display',
      'Indoor unit label/model plate',
      'Outdoor condenser or furnace area',
    ],
    quoteLineItems: ['Diagnostic', 'Labor', 'Parts/equipment', 'Testing'],
    matchTags: ['hvac', 'emergency'],
  ),
  'Electrical': const ServiceIntakeDefinition(
    service: 'Electrical',
    summary:
        'Capture repair/install type, panel/outlet/lighting scope, outage status, access, and permit likelihood.',
    questions: [
      ServiceIntakeQuestion(
        id: 'electrical_need',
        label: 'What electrical help do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: [
          'Repair',
          'Install',
          'Panel',
          'Outlet/switch',
          'Lighting',
          'Diagnosis',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'power_out',
        label: 'Is power out anywhere?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'breaker_issue',
        label: 'Is a breaker tripping?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'locations',
        label: 'Where is the work?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Kitchen',
          'Bathroom',
          'Garage',
          'Outdoor',
          'Panel',
          'Whole home',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'permit_likely',
        label: 'May this need a permit?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Panel or breaker area',
      'Outlet, switch, fixture, or wiring location',
      'Area where new work should be installed',
    ],
    quoteLineItems: ['Diagnostic', 'Labor', 'Materials', 'Permit/code work'],
    matchTags: ['electrical', 'permit-likely'],
  ),
  'House Cleaning': const ServiceIntakeDefinition(
    service: 'House Cleaning',
    summary:
        'Capture cleaning type, bedroom/bathroom count, sqft, pets, add-ons, and home condition.',
    questions: [
      ServiceIntakeQuestion(
        id: 'cleaning_type',
        label: 'What type of cleaning?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Standard', 'Deep cleaning', 'Move-out', 'Recurring'],
      ),
      ServiceIntakeQuestion(
        id: 'bedrooms',
        label: 'Bedrooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'bathrooms',
        label: 'Bathrooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'sqft',
        label: 'Approximate square feet',
        type: ServiceIntakeQuestionType.number,
        unit: 'sqft',
      ),
      ServiceIntakeQuestion(
        id: 'addons',
        label: 'Add-ons needed',
        type: ServiceIntakeQuestionType.multiChoice,
        options: ['Fridge', 'Oven', 'Windows', 'Baseboards', 'Inside cabinets'],
      ),
      ServiceIntakeQuestion(
        id: 'pets',
        label: 'Are pets in the home?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Kitchen and main living area',
      'Bathrooms needing attention',
      'Any areas needing deep cleaning',
    ],
    quoteLineItems: [
      'Cleaning labor',
      'Supplies',
      'Add-ons',
      'Recurring discount',
    ],
    matchTags: ['cleaning', 'recurring'],
  ),
  'Deep Cleaning': const ServiceIntakeDefinition(
    service: 'Deep Cleaning',
    summary: 'Capture room count, add-ons, condition, pets, and access.',
    questions: [
      ServiceIntakeQuestion(
        id: 'bedrooms',
        label: 'Bedrooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'bathrooms',
        label: 'Bathrooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'sqft',
        label: 'Approximate square feet',
        type: ServiceIntakeQuestionType.number,
        unit: 'sqft',
      ),
      ServiceIntakeQuestion(
        id: 'addons',
        label: 'Deep-clean add-ons',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Fridge',
          'Oven',
          'Windows',
          'Baseboards',
          'Inside cabinets',
          'Walls',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'pets',
        label: 'Are pets in the home?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: ['Kitchen', 'Bathrooms', 'Problem areas'],
    quoteLineItems: [
      'Deep-clean labor',
      'Supplies',
      'Add-ons',
      'Travel/access',
    ],
    matchTags: ['cleaning'],
  ),
  'Move-Out Cleaning': const ServiceIntakeDefinition(
    service: 'Move-Out Cleaning',
    summary: 'Capture room count, sqft, deadline, add-ons, and home condition.',
    questions: [
      ServiceIntakeQuestion(
        id: 'bedrooms',
        label: 'Bedrooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'bathrooms',
        label: 'Bathrooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'sqft',
        label: 'Approximate square feet',
        type: ServiceIntakeQuestionType.number,
        unit: 'sqft',
      ),
      ServiceIntakeQuestion(
        id: 'deadline',
        label: 'Move-out deadline',
        type: ServiceIntakeQuestionType.text,
      ),
      ServiceIntakeQuestion(
        id: 'addons',
        label: 'Required add-ons',
        type: ServiceIntakeQuestionType.multiChoice,
        options: ['Fridge', 'Oven', 'Windows', 'Baseboards', 'Inside cabinets'],
      ),
    ],
    photoPrompts: ['Kitchen', 'Bathrooms', 'Any heavy-use areas'],
    quoteLineItems: [
      'Move-out cleaning',
      'Supplies',
      'Add-ons',
      'Deadline/access',
    ],
    matchTags: ['cleaning', 'move-out'],
  ),
  'Moving Services': const ServiceIntakeDefinition(
    service: 'Moving Services',
    summary:
        'Capture from/to ZIP, home size, stairs, heavy items, packing help, and move date.',
    questions: [
      ServiceIntakeQuestion(
        id: 'from_zip',
        label: 'Moving from ZIP',
        type: ServiceIntakeQuestionType.text,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'to_zip',
        label: 'Moving to ZIP',
        type: ServiceIntakeQuestionType.text,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'bedrooms',
        label: 'Bedrooms or rooms',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'access',
        label: 'Access details',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Stairs',
          'Elevator',
          'Long carry',
          'Apartment',
          'Storage unit',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'heavy_items',
        label: 'Heavy or fragile items',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Piano',
          'Safe',
          'Appliances',
          'Large glass',
          'Gym equipment',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'packing_help',
        label: 'Do you need packing help?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'move_date',
        label: 'Preferred move date',
        type: ServiceIntakeQuestionType.text,
      ),
    ],
    photoPrompts: [
      'Largest rooms or packed items',
      'Stairs, elevator, or entry access',
      'Heavy or fragile items',
    ],
    quoteLineItems: [
      'Crew labor',
      'Truck/travel',
      'Packing materials',
      'Heavy items',
    ],
    matchTags: ['moving', 'large-project'],
  ),
  'Landscaping': const ServiceIntakeDefinition(
    service: 'Landscaping',
    summary:
        'Capture service type, lot size, cleanup/design needs, debris removal, and irrigation.',
    questions: [
      ServiceIntakeQuestion(
        id: 'landscape_need',
        label: 'What landscaping help do you need?',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: [
          'Mowing',
          'Cleanup',
          'Design/install',
          'Planting',
          'Mulch/rock',
          'Maintenance',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'lot_size',
        label: 'Approximate lot or yard size',
        type: ServiceIntakeQuestionType.choice,
        options: ['Small', 'Medium', 'Large', 'Not sure'],
      ),
      ServiceIntakeQuestion(
        id: 'frequency',
        label: 'One-time or recurring?',
        type: ServiceIntakeQuestionType.choice,
        options: ['One-time', 'Weekly', 'Bi-weekly', 'Monthly'],
      ),
      ServiceIntakeQuestion(
        id: 'debris_removal',
        label: 'Need debris hauled away?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'irrigation',
        label: 'Is irrigation involved?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: [
      'Front yard',
      'Back yard',
      'Problem areas or desired design examples',
    ],
    quoteLineItems: [
      'Labor',
      'Materials/plants',
      'Debris haul-away',
      'Recurring service',
    ],
    matchTags: ['landscaping', 'recurring'],
  ),
  'Lawn Care': const ServiceIntakeDefinition(
    service: 'Lawn Care',
    summary:
        'Capture yard size, frequency, grass height, edging, and debris removal.',
    questions: [
      ServiceIntakeQuestion(
        id: 'yard_size',
        label: 'Yard size',
        type: ServiceIntakeQuestionType.choice,
        required: true,
        options: ['Small', 'Medium', 'Large', 'Not sure'],
      ),
      ServiceIntakeQuestion(
        id: 'frequency',
        label: 'One-time or recurring?',
        type: ServiceIntakeQuestionType.choice,
        options: ['One-time', 'Weekly', 'Bi-weekly', 'Monthly'],
      ),
      ServiceIntakeQuestion(
        id: 'extras',
        label: 'Include extras?',
        type: ServiceIntakeQuestionType.multiChoice,
        options: [
          'Edging',
          'Blowing',
          'Weed eating',
          'Leaf cleanup',
          'Fertilizer',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'debris_removal',
        label: 'Need debris hauled away?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
    ],
    photoPrompts: ['Front yard', 'Back yard', 'Overgrown or problem areas'],
    quoteLineItems: [
      'Mowing',
      'Edging/blowing',
      'Yard cleanup',
      'Recurring service',
    ],
    matchTags: ['lawn-care', 'recurring'],
  ),
  'General Handyman': const ServiceIntakeDefinition(
    service: 'General Handyman',
    summary:
        'Capture task list, number of tasks, materials, access height, and urgency.',
    questions: [
      ServiceIntakeQuestion(
        id: 'task_type',
        label: 'What type of task?',
        type: ServiceIntakeQuestionType.multiChoice,
        required: true,
        options: [
          'Repair',
          'Install',
          'Assembly',
          'Mounting',
          'Caulking',
          'Small carpentry',
        ],
      ),
      ServiceIntakeQuestion(
        id: 'task_count',
        label: 'How many tasks?',
        type: ServiceIntakeQuestionType.number,
        required: true,
      ),
      ServiceIntakeQuestion(
        id: 'materials_ready',
        label: 'Do you already have materials?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'ladder_needed',
        label: 'Will ladder or height access be needed?',
        type: ServiceIntakeQuestionType.yesNo,
      ),
      ServiceIntakeQuestion(
        id: 'task_notes',
        label: 'List the tasks you need done',
        type: ServiceIntakeQuestionType.text,
        required: true,
      ),
    ],
    photoPrompts: [
      'Each task area',
      'Broken parts or existing materials',
      'Any access constraints',
    ],
    quoteLineItems: [
      'Labor',
      'Materials',
      'Trip/setup',
      'Task-specific repairs',
    ],
    matchTags: ['handyman'],
  ),
};

ServiceIntakeDefinition intakeDefinitionForService(String? service) {
  final canonical = canonicalServiceName(service ?? '');
  return _definitions[canonical] ?? _genericDefinition;
}

bool hasSpecificIntakeDefinition(String? service) {
  final canonical = canonicalServiceName(service ?? '');
  return _definitions.containsKey(canonical);
}

List<String> requiredMissingFields(
  ServiceIntakeDefinition definition,
  Map<String, dynamic> answers,
) {
  final missing = <String>[];
  for (final question in definition.questions.where((q) => q.required)) {
    final value = answers[question.id];
    if (value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty)) {
      missing.add(question.label);
    }
  }
  return missing;
}

int leadQualityScore({
  required ServiceIntakeDefinition definition,
  required Map<String, dynamic> answers,
  required int photoCount,
  required String zip,
  required String timeline,
  required String budgetPreference,
}) {
  var score = 0;
  if (zip.trim().length == 5) score += 15;
  if (photoCount > 0) score += 20;
  if (photoCount >= 3) score += 10;
  if (timeline.trim().isNotEmpty) score += 10;
  if (budgetPreference.trim().isNotEmpty) score += 10;

  final answered = definition.questions.where((question) {
    final value = answers[question.id];
    return value != null &&
        !(value is String && value.trim().isEmpty) &&
        !(value is List && value.isEmpty);
  }).length;
  if (definition.questions.isNotEmpty) {
    score += ((answered / definition.questions.length) * 35).round();
  }
  return score.clamp(0, 100);
}

String leadQualityLabel(int score, List<String> missing) {
  if (score >= 75 && missing.isEmpty) return 'Strong lead';
  if (score >= 45) return 'Needs follow-up';
  return 'Missing details';
}

String contractorBriefForLead({
  required String service,
  required ServiceIntakeDefinition definition,
  required Map<String, dynamic> answers,
  required int photoCount,
  required String zip,
  required String timeline,
  String? notes,
}) {
  final parts = <String>[
    'Customer needs $service',
    if (zip.trim().isNotEmpty) 'near ZIP ${zip.trim()}',
    if (timeline.trim().isNotEmpty) 'timeline: $timeline',
  ];

  for (final question in definition.questions.take(5)) {
    final value = answers[question.id];
    final formatted = _formatAnswer(value);
    if (formatted.isNotEmpty) {
      parts.add('${question.label}: $formatted');
    }
  }

  if (photoCount > 0) {
    parts.add('$photoCount photo${photoCount == 1 ? '' : 's'} uploaded');
  }
  final trimmedNotes = notes?.trim();
  if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
    parts.add('Notes: $trimmedNotes');
  }
  return parts.join(' • ');
}

List<String> matchTagsForAnswers(
  ServiceIntakeDefinition definition,
  Map<String, dynamic> answers,
) {
  final tags = <String>{...definition.matchTags};
  final serialized = answers.values.map(_formatAnswer).join(' ').toLowerCase();
  if (serialized.contains('emergency') ||
      serialized.contains('active leak') ||
      serialized.contains('completely out') ||
      serialized.contains('power out') ||
      serialized.contains('sewage')) {
    tags.add('emergency');
  }
  if (serialized.contains('insurance')) tags.add('insurance');
  if (serialized.contains('recurring') ||
      serialized.contains('weekly') ||
      serialized.contains('bi-weekly') ||
      serialized.contains('monthly')) {
    tags.add('recurring');
  }
  if (serialized.contains('commercial') || serialized.contains('business')) {
    tags.add('commercial');
  }
  if (serialized.contains('3+') ||
      serialized.contains('multi') ||
      serialized.contains('above one story')) {
    tags.add('multi-story');
  }
  if (serialized.contains('permit')) tags.add('permit-likely');
  return tags.toList(growable: false);
}

String answerLabelForId(ServiceIntakeDefinition definition, String id) {
  for (final question in definition.questions) {
    if (question.id == id) return question.label;
  }
  return id;
}

String _formatAnswer(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value.where((e) => e.toString().trim().isNotEmpty).join(', ');
  }
  return value.toString().trim();
}
