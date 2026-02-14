import 'package:geocoding/geocoding.dart';

import '../utils/zip_locations.dart';

/// Resolves any US ZIP code to lat/lng using the [geocoding] package,
/// with the hardcoded [zipLocations] map as an instant cache / fallback.
class ZipLookupService {
  ZipLookupService._();
  static final ZipLookupService instance = ZipLookupService._();

  /// In-memory cache so each ZIP is geocoded at most once per session.
  final Map<String, Map<String, double>> _cache = {};

  /// Returns `{'lat': ..., 'lng': ...}` for the given 5-digit US ZIP,
  /// or `null` if the ZIP cannot be resolved.
  Future<Map<String, double>?> lookup(String zip) async {
    final key = zip.trim();
    if (key.isEmpty || key.length != 5) return null;

    // 1. Check runtime cache
    if (_cache.containsKey(key)) return _cache[key];

    // 2. Check hardcoded Houston-area map (instant)
    final hardcoded = zipLocations[key];
    if (hardcoded != null) {
      _cache[key] = hardcoded;
      return hardcoded;
    }

    // 3. Geocode via platform service (Android / iOS)
    try {
      final locations = await locationFromAddress('$key, United States');
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final result = {'lat': loc.latitude, 'lng': loc.longitude};
        _cache[key] = result;
        return result;
      }
    } catch (_) {
      // Geocoding failed — ZIP may be invalid or offline
    }

    return null;
  }

  /// Synchronous check: returns cached result immediately or `null`.
  /// Use when you need a non-async lookup (e.g. inside a where-clause).
  Map<String, double>? lookupCached(String zip) {
    final key = zip.trim();
    return _cache[key] ?? zipLocations[key];
  }
}
