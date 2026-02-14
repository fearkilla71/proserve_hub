import 'package:cloud_firestore/cloud_firestore.dart';

/// Loads material databases from Firestore with a hardcoded fallback.
///
/// Firestore collection: `material_databases/{serviceType}`
/// Each document contains a `materials` array of {name, pricePerUnit, unit}.
///
/// Uses a 10-minute in-memory cache to avoid redundant reads.
///
/// This service works with the `MaterialItem` class defined in
/// `cost_estimator_screen.dart`. It returns raw data maps that should be
/// converted to `MaterialItem` instances by the caller.
class MaterialDatabaseService {
  static final _firestore = FirebaseFirestore.instance;
  static final Map<String, _CachedMaterials> _cache = {};
  static const _ttl = Duration(minutes: 10);

  /// Returns a list of `{name, pricePerUnit, unit}` maps for the given service.
  ///
  /// Tries Firestore first, falls back to a hardcoded default.
  static Future<List<Map<String, dynamic>>> getMaterials(
    String serviceType,
  ) async {
    final key = serviceType.toLowerCase().trim();

    // Return cached if fresh.
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _ttl) {
      return cached.items;
    }

    try {
      final doc = await _firestore
          .collection('material_databases')
          .doc(key)
          .get();

      if (doc.exists && doc.data() != null) {
        final raw = doc.data()!['materials'];
        if (raw is List) {
          final items = raw
              .whereType<Map<String, dynamic>>()
              .where(
                (m) =>
                    m['name'] != null &&
                    m['pricePerUnit'] != null &&
                    m['unit'] != null,
              )
              .toList();
          if (items.isNotEmpty) {
            _cache[key] = _CachedMaterials(items, DateTime.now());
            return items;
          }
        }
      }
    } catch (_) {
      // Fall through to defaults.
    }

    final defaults = _defaultMaterials[key];
    if (defaults != null) {
      _cache[key] = _CachedMaterials(defaults, DateTime.now());
    }
    return defaults ?? [];
  }

  /// Hardcoded fallback data — same as the previous inline map.
  static final Map<String, List<Map<String, dynamic>>> _defaultMaterials = {
    'painting': [
      {
        'name': 'Interior Paint (Gallon)',
        'pricePerUnit': 35.00,
        'unit': 'gallon',
      },
      {
        'name': 'Exterior Paint (Gallon)',
        'pricePerUnit': 45.00,
        'unit': 'gallon',
      },
      {'name': 'Primer (Gallon)', 'pricePerUnit': 25.00, 'unit': 'gallon'},
      {'name': 'Paint Roller Set', 'pricePerUnit': 15.00, 'unit': 'set'},
      {'name': 'Paint Brushes', 'pricePerUnit': 12.00, 'unit': 'set'},
      {'name': 'Drop Cloth', 'pricePerUnit': 10.00, 'unit': 'unit'},
      {'name': 'Painter\'s Tape', 'pricePerUnit': 8.00, 'unit': 'roll'},
      {'name': 'Sandpaper Pack', 'pricePerUnit': 12.00, 'unit': 'pack'},
    ],
    'drywall repair': [
      {'name': 'Drywall (4x8)', 'pricePerUnit': 15.00, 'unit': 'sheet'},
      {'name': 'Joint Compound', 'pricePerUnit': 18.00, 'unit': 'bucket'},
      {'name': 'Drywall Tape', 'pricePerUnit': 6.00, 'unit': 'roll'},
      {'name': 'Drywall Screws', 'pricePerUnit': 9.00, 'unit': 'box'},
      {'name': 'Corner Bead', 'pricePerUnit': 7.00, 'unit': 'unit'},
      {'name': 'Sanding Sponge', 'pricePerUnit': 5.00, 'unit': 'unit'},
      {'name': 'Primer (Gallon)', 'pricePerUnit': 25.00, 'unit': 'gallon'},
    ],
    'pressure washing': [
      {
        'name': 'Pressure Washer Rental (Day)',
        'pricePerUnit': 85.00,
        'unit': 'day',
      },
      {
        'name': 'Surface Cleaner Attachment',
        'pricePerUnit': 35.00,
        'unit': 'unit',
      },
      {'name': 'Degreaser/Cleaner', 'pricePerUnit': 18.00, 'unit': 'bottle'},
      {'name': 'Mildew Remover', 'pricePerUnit': 16.00, 'unit': 'bottle'},
      {'name': 'Hose (50ft)', 'pricePerUnit': 25.00, 'unit': 'unit'},
      {'name': 'Nozzle Set', 'pricePerUnit': 20.00, 'unit': 'set'},
      {'name': 'Safety Goggles', 'pricePerUnit': 12.00, 'unit': 'unit'},
      {'name': 'Gloves', 'pricePerUnit': 10.00, 'unit': 'pair'},
    ],
  };
}

class _CachedMaterials {
  final List<Map<String, dynamic>> items;
  final DateTime fetchedAt;
  _CachedMaterials(this.items, this.fetchedAt);
}
