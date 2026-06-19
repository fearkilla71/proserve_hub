/// Canonical lists of service types used across the app.
///
/// Import this file instead of hardcoding service names in
/// individual screens and widgets.
library;

/// Core painting & related trade services offered on the platform.
/// These have the strongest first-party workflow support today.
const kPaintingServices = <String>[
  'Interior Painting',
  'Exterior Painting',
  'Pressure Washing',
  'Cabinets',
  'Drywall Repair',
];

/// Broader home-service catalog contractors can select for profile matching.
const kHomeServiceCategories = <String, List<String>>{
  'Core instant-price services': kPaintingServices,
  'Home repair & remodel': [
    'Roofing',
    'Flooring',
    'Epoxy Flooring',
    'Plumbing',
    'Electrical',
    'HVAC',
    'Window Replacement',
    'Garage Door',
    'Bathroom Remodel',
    'Kitchen Remodel',
    'Deck & Patio',
    'Fencing',
    'Fence Staining',
    'Tile & Backsplash',
    'Trim & Crown Molding',
    'Wallpaper Removal & Install',
    'Popcorn Ceiling Removal',
    'Demolition',
    'General Handyman',
  ],
  'Outdoor & property services': [
    'Landscaping',
    'Tree Service',
    'Pool Installation',
    'Solar Panels',
    'Pest Control',
    'Gutter Cleaning',
    'Lawn Care',
    'Concrete',
    'Masonry',
    'Commercial Painting',
  ],
};

const kContractorServiceCatalog = <String>[
  ...kPaintingServices,
  'Roofing',
  'Flooring',
  'Epoxy Flooring',
  'Plumbing',
  'Electrical',
  'HVAC',
  'Window Replacement',
  'Garage Door',
  'Bathroom Remodel',
  'Kitchen Remodel',
  'Deck & Patio',
  'Fencing',
  'Fence Staining',
  'Tile & Backsplash',
  'Trim & Crown Molding',
  'Wallpaper Removal & Install',
  'Popcorn Ceiling Removal',
  'Demolition',
  'General Handyman',
  'Landscaping',
  'Tree Service',
  'Pool Installation',
  'Solar Panels',
  'Pest Control',
  'Gutter Cleaning',
  'Lawn Care',
  'Concrete',
  'Masonry',
  'Commercial Painting',
];

/// Service type slug → display name mapping (used in quotes, contracts, etc.).
const kServiceTypeSlugMap = <String, String>{
  'painting': 'Interior Painting',
  'exterior_painting': 'Exterior Painting',
  'cabinet_painting': 'Cabinets',
  'drywall': 'Drywall Repair',
  'drywall_repair': 'Drywall Repair',
  'pressure_washing': 'Pressure Washing',
};

/// Extended service list including non-painting trades.
const kQuickServices = <String, String>{
  ...kServiceTypeSlugMap,
  'roofing': 'Roofing',
  'flooring': 'Flooring',
  'epoxy_flooring': 'Epoxy Flooring',
  'plumbing': 'Plumbing',
  'electrical': 'Electrical',
  'hvac': 'HVAC',
  'window_replacement': 'Window Replacement',
  'garage_door': 'Garage Door',
  'bathroom_remodel': 'Bathroom Remodel',
  'kitchen_remodel': 'Kitchen Remodel',
  'deck_patio': 'Deck & Patio',
  'fencing': 'Fencing',
  'fence_staining': 'Fence Staining',
  'tile_backsplash': 'Tile & Backsplash',
  'trim_crown_molding': 'Trim & Crown Molding',
  'wallpaper_removal_install': 'Wallpaper Removal & Install',
  'popcorn_ceiling_removal': 'Popcorn Ceiling Removal',
  'demolition': 'Demolition',
  'general_handyman': 'General Handyman',
  'landscaping': 'Landscaping',
  'tree_service': 'Tree Service',
  'pool_installation': 'Pool Installation',
  'solar_panels': 'Solar Panels',
  'pest_control': 'Pest Control',
  'gutter_cleaning': 'Gutter Cleaning',
  'lawn_care': 'Lawn Care',
  'concrete': 'Concrete',
  'masonry': 'Masonry',
  'commercial_painting': 'Commercial Painting',
};

const _kServiceAliases = <String, String>{
  'painting': 'Painting',
  'paint': 'Painting',
  'interior_painting': 'Interior Painting',
  'interior painting': 'Interior Painting',
  'exterior_painting': 'Exterior Painting',
  'exterior painting': 'Exterior Painting',
  'cabinet_painting': 'Cabinets',
  'cabinet painting': 'Cabinets',
  'cabinet refinishing': 'Cabinets',
  'cabinets': 'Cabinets',
  'drywall': 'Drywall Repair',
  'drywall repair': 'Drywall Repair',
  'drywall repair & texture': 'Drywall Repair',
  'drywall texture': 'Drywall Repair',
  'pressure_washing': 'Pressure Washing',
  'pressure washing': 'Pressure Washing',
  'power washing': 'Pressure Washing',
  'deck_patio': 'Deck & Patio',
  'deck patio': 'Deck & Patio',
  'deck & patio': 'Deck & Patio',
  'pool_installation': 'Pool Installation',
  'pool installation': 'Pool Installation',
  'window_replacement': 'Window Replacement',
  'window replacement': 'Window Replacement',
  'garage_door': 'Garage Door',
  'garage door': 'Garage Door',
  'epoxy flooring': 'Epoxy Flooring',
  'bathroom_remodel': 'Bathroom Remodel',
  'bathroom remodel': 'Bathroom Remodel',
  'kitchen_remodel': 'Kitchen Remodel',
  'kitchen remodel': 'Kitchen Remodel',
  'tree_service': 'Tree Service',
  'tree service': 'Tree Service',
  'solar_panels': 'Solar Panels',
  'solar panels': 'Solar Panels',
  'pest_control': 'Pest Control',
  'pest control': 'Pest Control',
  'gutter_cleaning': 'Gutter Cleaning',
  'gutter cleaning': 'Gutter Cleaning',
  'lawn_care': 'Lawn Care',
  'lawn care': 'Lawn Care',
  'concrete_masonry': 'Concrete',
  'concrete & masonry': 'Concrete',
  'fence_staining': 'Fence Staining',
  'fence staining': 'Fence Staining',
  'tile_backsplash': 'Tile & Backsplash',
  'tile backsplash': 'Tile & Backsplash',
  'tile & backsplash': 'Tile & Backsplash',
  'trim_crown_molding': 'Trim & Crown Molding',
  'trim crown molding': 'Trim & Crown Molding',
  'trim & crown molding': 'Trim & Crown Molding',
  'wallpaper_removal_install': 'Wallpaper Removal & Install',
  'wallpaper removal install': 'Wallpaper Removal & Install',
  'wallpaper removal & install': 'Wallpaper Removal & Install',
  'popcorn_ceiling_removal': 'Popcorn Ceiling Removal',
  'popcorn ceiling removal': 'Popcorn Ceiling Removal',
  'general_handyman': 'General Handyman',
  'general handyman': 'General Handyman',
  'commercial_painting': 'Commercial Painting',
  'commercial painting': 'Commercial Painting',
};

const kInstantPriceServiceNames = <String>{
  'Interior Painting',
  'Exterior Painting',
  'Pressure Washing',
  'Cabinets',
  'Drywall Repair',
};

String serviceKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String canonicalServiceName(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return raw;
  final alias =
      _kServiceAliases[raw.toLowerCase()] ?? _kServiceAliases[serviceKey(raw)];
  if (alias != null) return alias;
  for (final service in kContractorServiceCatalog) {
    if (serviceKey(service) == serviceKey(raw)) return service;
  }
  return raw;
}

String serviceSlug(String value) {
  final canonical = canonicalServiceName(value);
  final match = kQuickServices.entries.where(
    (entry) => canonicalServiceName(entry.value) == canonical,
  );
  if (match.isNotEmpty) return match.first.key;
  return serviceKey(canonical).replaceAll(' ', '_');
}

bool supportsInstantPrice(String value) {
  return kInstantPriceServiceNames.contains(canonicalServiceName(value));
}

bool serviceMatches(String contractorService, String requestedService) {
  final contractor = canonicalServiceName(contractorService);
  final requested = canonicalServiceName(requestedService);
  if (contractor.isEmpty || requested.isEmpty) return false;
  if (contractor == requested) return true;
  if (requested == 'Painting') {
    return contractor == 'Interior Painting' ||
        contractor == 'Exterior Painting' ||
        contractor == 'Commercial Painting';
  }
  if (contractor == 'Painting') {
    return requested == 'Interior Painting' ||
        requested == 'Exterior Painting' ||
        requested == 'Commercial Painting';
  }
  return serviceKey(contractor).contains(serviceKey(requested)) ||
      serviceKey(requested).contains(serviceKey(contractor));
}

List<String> normalizeServiceList(Iterable<dynamic>? services) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in services ?? const []) {
    final canonical = canonicalServiceName(raw.toString());
    if (canonical.trim().isEmpty) continue;
    final key = serviceKey(canonical);
    if (seen.add(key)) result.add(canonical);
  }
  return result;
}

List<dynamic> _listFrom(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

List<String> contractorServicesFromData(Map<String, dynamic>? data) {
  final merged = <dynamic>[
    ..._listFrom(data?['services']),
    ..._listFrom(data?['servicesOffered']),
    ..._listFrom(data?['serviceTypes']),
  ];
  return normalizeServiceList(merged);
}
