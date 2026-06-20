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
    'Appliance Repair',
    'Roofing',
    'Siding',
    'Flooring',
    'Epoxy Flooring',
    'Plumbing',
    'Electrical',
    'HVAC',
    'Window Replacement',
    'Door Installation & Repair',
    'Garage Door',
    'Bathroom Remodel',
    'Kitchen Remodel',
    'Deck & Patio',
    'Patio Installation',
    'Fencing',
    'Fence Staining',
    'Tile & Backsplash',
    'Trim & Crown Molding',
    'Wallpaper Removal & Install',
    'Popcorn Ceiling Removal',
    'Demolition',
    'General Handyman',
    'Foundation Repair',
    'Basement Waterproofing',
    'Insulation',
    'Chimney & Fireplace Repair',
    'Driveway Repair',
    'Driveway Sealcoating',
    'Asphalt & Paving',
  ],
  'Outdoor & property services': [
    'Landscaping',
    'Tree Service',
    'Sprinkler & Irrigation',
    'Pool Installation',
    'Pool Cleaning & Maintenance',
    'Pool Repair',
    'Hot Tub & Spa Service',
    'Solar Panels',
    'Pest Control',
    'Gutter Cleaning',
    'Gutter Repair & Installation',
    'Lawn Care',
    'Yard Cleanup',
    'Concrete',
    'Masonry',
    'Drainage & Grading',
    'Excavation',
    'Land Surveying',
    'Commercial Painting',
  ],
  'Cleaning & maintenance': [
    'House Cleaning',
    'Deep Cleaning',
    'Move-Out Cleaning',
    'Carpet Cleaning',
    'Window Cleaning',
    'Dryer Vent Cleaning',
    'Junk Removal',
  ],
  'Safety & specialty systems': [
    'Home Inspection',
    'Mold Testing & Remediation',
    'Security Camera Installation',
    'Generator Installation & Repair',
    'Septic Tank Service',
    'Water Softener Installation',
    'Well Pump Repair',
    'Locksmith',
  ],
  'Moving & setup': [
    'Moving Services',
    'Furniture Assembly',
    'Furniture Repair',
    'TV Mounting',
    'Smart Home Installation',
  ],
};

const kContractorServiceCatalog = <String>[
  ...kPaintingServices,
  'Appliance Repair',
  'Roofing',
  'Siding',
  'Flooring',
  'Epoxy Flooring',
  'Plumbing',
  'Electrical',
  'HVAC',
  'Window Replacement',
  'Door Installation & Repair',
  'Garage Door',
  'Bathroom Remodel',
  'Kitchen Remodel',
  'Deck & Patio',
  'Patio Installation',
  'Fencing',
  'Fence Staining',
  'Tile & Backsplash',
  'Trim & Crown Molding',
  'Wallpaper Removal & Install',
  'Popcorn Ceiling Removal',
  'Demolition',
  'General Handyman',
  'Foundation Repair',
  'Basement Waterproofing',
  'Insulation',
  'Chimney & Fireplace Repair',
  'Driveway Repair',
  'Driveway Sealcoating',
  'Asphalt & Paving',
  'Landscaping',
  'Tree Service',
  'Sprinkler & Irrigation',
  'Pool Installation',
  'Pool Cleaning & Maintenance',
  'Pool Repair',
  'Hot Tub & Spa Service',
  'Solar Panels',
  'Pest Control',
  'Gutter Cleaning',
  'Gutter Repair & Installation',
  'Lawn Care',
  'Yard Cleanup',
  'Concrete',
  'Masonry',
  'Drainage & Grading',
  'Excavation',
  'Land Surveying',
  'Commercial Painting',
  'House Cleaning',
  'Deep Cleaning',
  'Move-Out Cleaning',
  'Carpet Cleaning',
  'Window Cleaning',
  'Dryer Vent Cleaning',
  'Junk Removal',
  'Home Inspection',
  'Mold Testing & Remediation',
  'Security Camera Installation',
  'Generator Installation & Repair',
  'Septic Tank Service',
  'Water Softener Installation',
  'Well Pump Repair',
  'Locksmith',
  'Moving Services',
  'Furniture Assembly',
  'Furniture Repair',
  'TV Mounting',
  'Smart Home Installation',
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
  'appliance_repair': 'Appliance Repair',
  'siding': 'Siding',
  'flooring': 'Flooring',
  'epoxy_flooring': 'Epoxy Flooring',
  'plumbing': 'Plumbing',
  'electrical': 'Electrical',
  'hvac': 'HVAC',
  'window_replacement': 'Window Replacement',
  'door_installation_repair': 'Door Installation & Repair',
  'garage_door': 'Garage Door',
  'bathroom_remodel': 'Bathroom Remodel',
  'kitchen_remodel': 'Kitchen Remodel',
  'deck_patio': 'Deck & Patio',
  'patio_installation': 'Patio Installation',
  'fencing': 'Fencing',
  'fence_staining': 'Fence Staining',
  'tile_backsplash': 'Tile & Backsplash',
  'trim_crown_molding': 'Trim & Crown Molding',
  'wallpaper_removal_install': 'Wallpaper Removal & Install',
  'popcorn_ceiling_removal': 'Popcorn Ceiling Removal',
  'demolition': 'Demolition',
  'general_handyman': 'General Handyman',
  'foundation_repair': 'Foundation Repair',
  'basement_waterproofing': 'Basement Waterproofing',
  'insulation': 'Insulation',
  'chimney_fireplace_repair': 'Chimney & Fireplace Repair',
  'driveway_repair': 'Driveway Repair',
  'driveway_sealcoating': 'Driveway Sealcoating',
  'asphalt_paving': 'Asphalt & Paving',
  'landscaping': 'Landscaping',
  'tree_service': 'Tree Service',
  'sprinkler_irrigation': 'Sprinkler & Irrigation',
  'pool_installation': 'Pool Installation',
  'pool_cleaning_maintenance': 'Pool Cleaning & Maintenance',
  'pool_repair': 'Pool Repair',
  'hot_tub_spa_service': 'Hot Tub & Spa Service',
  'solar_panels': 'Solar Panels',
  'pest_control': 'Pest Control',
  'gutter_cleaning': 'Gutter Cleaning',
  'gutter_repair_installation': 'Gutter Repair & Installation',
  'lawn_care': 'Lawn Care',
  'yard_cleanup': 'Yard Cleanup',
  'concrete': 'Concrete',
  'masonry': 'Masonry',
  'drainage_grading': 'Drainage & Grading',
  'excavation': 'Excavation',
  'land_surveying': 'Land Surveying',
  'commercial_painting': 'Commercial Painting',
  'house_cleaning': 'House Cleaning',
  'deep_cleaning': 'Deep Cleaning',
  'move_out_cleaning': 'Move-Out Cleaning',
  'carpet_cleaning': 'Carpet Cleaning',
  'window_cleaning': 'Window Cleaning',
  'dryer_vent_cleaning': 'Dryer Vent Cleaning',
  'junk_removal': 'Junk Removal',
  'home_inspection': 'Home Inspection',
  'mold_testing_remediation': 'Mold Testing & Remediation',
  'security_camera_installation': 'Security Camera Installation',
  'generator_installation_repair': 'Generator Installation & Repair',
  'septic_tank_service': 'Septic Tank Service',
  'water_softener_installation': 'Water Softener Installation',
  'well_pump_repair': 'Well Pump Repair',
  'locksmith': 'Locksmith',
  'moving_services': 'Moving Services',
  'furniture_assembly': 'Furniture Assembly',
  'furniture_repair': 'Furniture Repair',
  'tv_mounting': 'TV Mounting',
  'smart_home_installation': 'Smart Home Installation',
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
  'power_washing': 'Pressure Washing',
  'appliance_repair': 'Appliance Repair',
  'appliance repair': 'Appliance Repair',
  'appliances': 'Appliance Repair',
  'siding': 'Siding',
  'siding repair': 'Siding',
  'deck_patio': 'Deck & Patio',
  'deck patio': 'Deck & Patio',
  'deck & patio': 'Deck & Patio',
  'deck and patio': 'Deck & Patio',
  'patio': 'Patio Installation',
  'patio installation': 'Patio Installation',
  'patio_installation': 'Patio Installation',
  'pool_installation': 'Pool Installation',
  'pool installation': 'Pool Installation',
  'pool_service': 'Pool Cleaning & Maintenance',
  'pool service': 'Pool Cleaning & Maintenance',
  'pool cleaning': 'Pool Cleaning & Maintenance',
  'pool maintenance': 'Pool Cleaning & Maintenance',
  'pool_cleaning_maintenance': 'Pool Cleaning & Maintenance',
  'pool cleaning and maintenance': 'Pool Cleaning & Maintenance',
  'pool repair': 'Pool Repair',
  'pool_repair': 'Pool Repair',
  'hot tub': 'Hot Tub & Spa Service',
  'hot tub service': 'Hot Tub & Spa Service',
  'spa service': 'Hot Tub & Spa Service',
  'hot_tub_spa_service': 'Hot Tub & Spa Service',
  'window_replacement': 'Window Replacement',
  'window replacement': 'Window Replacement',
  'windows': 'Window Replacement',
  'window cleaning': 'Window Cleaning',
  'window_cleaning': 'Window Cleaning',
  'garage_door': 'Garage Door',
  'garage door': 'Garage Door',
  'garage door repair': 'Garage Door',
  'epoxy flooring': 'Epoxy Flooring',
  'epoxy_flooring': 'Epoxy Flooring',
  'hvac repair': 'HVAC',
  'furnace repair': 'HVAC',
  'furnace maintenance': 'HVAC',
  'air conditioning': 'HVAC',
  'ac repair': 'HVAC',
  'door installation': 'Door Installation & Repair',
  'door repair': 'Door Installation & Repair',
  'door_installation_repair': 'Door Installation & Repair',
  'bathroom_remodel': 'Bathroom Remodel',
  'bathroom remodel': 'Bathroom Remodel',
  'kitchen_remodel': 'Kitchen Remodel',
  'kitchen remodel': 'Kitchen Remodel',
  'tree_service': 'Tree Service',
  'tree service': 'Tree Service',
  'tree trimming': 'Tree Service',
  'tree removal': 'Tree Service',
  'sprinkler_irrigation': 'Sprinkler & Irrigation',
  'sprinkler irrigation': 'Sprinkler & Irrigation',
  'sprinkler repair': 'Sprinkler & Irrigation',
  'irrigation': 'Sprinkler & Irrigation',
  'solar_panels': 'Solar Panels',
  'solar panels': 'Solar Panels',
  'pest_control': 'Pest Control',
  'pest control': 'Pest Control',
  'gutter_cleaning': 'Gutter Cleaning',
  'gutter cleaning': 'Gutter Cleaning',
  'gutter services': 'Gutter Cleaning',
  'gutter repair': 'Gutter Repair & Installation',
  'gutter installation': 'Gutter Repair & Installation',
  'gutter_repair_installation': 'Gutter Repair & Installation',
  'lawn_care': 'Lawn Care',
  'lawn care': 'Lawn Care',
  'lawn mowing': 'Lawn Care',
  'lawn trimming': 'Lawn Care',
  'yard cleanup': 'Yard Cleanup',
  'yard clean up': 'Yard Cleanup',
  'yard_cleanup': 'Yard Cleanup',
  'concrete_masonry': 'Concrete',
  'concrete & masonry': 'Concrete',
  'concrete and masonry': 'Concrete',
  'masonry': 'Masonry',
  'drainage grading': 'Drainage & Grading',
  'drainage_grading': 'Drainage & Grading',
  'grading': 'Drainage & Grading',
  'excavation': 'Excavation',
  'land surveying': 'Land Surveying',
  'land_surveying': 'Land Surveying',
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
  'handyman': 'General Handyman',
  'foundation repair': 'Foundation Repair',
  'foundation_repair': 'Foundation Repair',
  'basement waterproofing': 'Basement Waterproofing',
  'basement_waterproofing': 'Basement Waterproofing',
  'insulation': 'Insulation',
  'chimney repair': 'Chimney & Fireplace Repair',
  'fireplace repair': 'Chimney & Fireplace Repair',
  'chimney_fireplace_repair': 'Chimney & Fireplace Repair',
  'driveway repair': 'Driveway Repair',
  'driveway_repair': 'Driveway Repair',
  'driveway sealcoating': 'Driveway Sealcoating',
  'driveway_sealcoating': 'Driveway Sealcoating',
  'asphalt paving': 'Asphalt & Paving',
  'asphalt_paving': 'Asphalt & Paving',
  'paving': 'Asphalt & Paving',
  'house cleaning': 'House Cleaning',
  'house_cleaning': 'House Cleaning',
  'home cleaning': 'House Cleaning',
  'deep cleaning': 'Deep Cleaning',
  'deep_cleaning': 'Deep Cleaning',
  'move out cleaning': 'Move-Out Cleaning',
  'move-out cleaning': 'Move-Out Cleaning',
  'move_out_cleaning': 'Move-Out Cleaning',
  'carpet cleaning': 'Carpet Cleaning',
  'carpet_cleaning': 'Carpet Cleaning',
  'dryer vent cleaning': 'Dryer Vent Cleaning',
  'dryer_vent_cleaning': 'Dryer Vent Cleaning',
  'junk removal': 'Junk Removal',
  'junk_removal': 'Junk Removal',
  'home inspection': 'Home Inspection',
  'home_inspection': 'Home Inspection',
  'mold remediation': 'Mold Testing & Remediation',
  'mold testing': 'Mold Testing & Remediation',
  'mold_testing_remediation': 'Mold Testing & Remediation',
  'security camera installation': 'Security Camera Installation',
  'security cameras': 'Security Camera Installation',
  'security_camera_installation': 'Security Camera Installation',
  'generator installation': 'Generator Installation & Repair',
  'generator repair': 'Generator Installation & Repair',
  'generator_installation_repair': 'Generator Installation & Repair',
  'septic tank': 'Septic Tank Service',
  'septic tank service': 'Septic Tank Service',
  'septic_tank_service': 'Septic Tank Service',
  'water softener': 'Water Softener Installation',
  'water softener installation': 'Water Softener Installation',
  'water_softener_installation': 'Water Softener Installation',
  'well pump': 'Well Pump Repair',
  'well pump repair': 'Well Pump Repair',
  'well_pump_repair': 'Well Pump Repair',
  'locksmith': 'Locksmith',
  'moving': 'Moving Services',
  'movers': 'Moving Services',
  'moving services': 'Moving Services',
  'moving_services': 'Moving Services',
  'furniture assembly': 'Furniture Assembly',
  'furniture_assembly': 'Furniture Assembly',
  'furniture repair': 'Furniture Repair',
  'furniture_repair': 'Furniture Repair',
  'tv mounting': 'TV Mounting',
  'tv_mounting': 'TV Mounting',
  'smart home': 'Smart Home Installation',
  'smart home installation': 'Smart Home Installation',
  'smart_home_installation': 'Smart Home Installation',
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
