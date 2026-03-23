/// Canonical lists of service types used across the app.
///
/// Import this file instead of hardcoding service names in
/// individual screens and widgets.
library;

/// Core painting & related trade services offered on the platform.
const kPaintingServices = <String>[
  'Interior Painting',
  'Exterior Painting',
  'Pressure Washing',
  'Cabinets',
  'Drywall Repair',
];

/// Service type slug → display name mapping (used in quotes, contracts, etc.).
const kServiceTypeSlugMap = <String, String>{
  'painting': 'Interior Painting',
  'exterior_painting': 'Exterior Painting',
  'cabinet_painting': 'Cabinet Painting',
  'drywall': 'Drywall Repair',
  'pressure_washing': 'Pressure Washing',
};

/// Extended service list including non-painting trades.
const kQuickServices = <String, String>{
  ...kServiceTypeSlugMap,
  'roofing': 'Roofing',
  'flooring': 'Flooring',
  'plumbing': 'Plumbing',
  'electrical': 'Electrical',
};
