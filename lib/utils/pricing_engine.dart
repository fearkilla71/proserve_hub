import 'package:cloud_firestore/cloud_firestore.dart';

/// Cached Firestore document with expiry.
class _CachedDoc {
  final Map<String, dynamic>? data;
  final bool exists;
  final DateTime fetchedAt;

  _CachedDoc({
    required this.data,
    required this.exists,
    required this.fetchedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > PricingEngine._cacheTtl;
}

class PricingEngine {
  /// Time-to-live for cached pricing/zip docs.
  static const _cacheTtl = Duration(minutes: 5);

  /// In-memory cache keyed by collection/docId.
  static final Map<String, _CachedDoc> _cache = {};

  /// Clear the entire pricing cache (e.g. on logout or manual refresh).
  static void clearCache() => _cache.clear();

  static bool _isPainting(String service) {
    final s = service.trim().toLowerCase();
    return s.contains('paint');
  }

  /// Fetch a Firestore doc with in-memory caching + TTL.
  static Future<_CachedDoc> _getCachedDoc(
    String collection,
    String docId,
  ) async {
    final key = '$collection/$docId';
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) return cached;

    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .get();
    final entry = _CachedDoc(
      data: snap.data(),
      exists: snap.exists,
      fetchedAt: DateTime.now(),
    );
    _cache[key] = entry;
    return entry;
  }

  static Future<_CachedDoc> _getPricingDoc({required String service}) async {
    final raw = service.trim();
    final lower = raw.toLowerCase();

    final lowerDoc = await _getCachedDoc('pricing_rules', lower);
    if (lowerDoc.exists) return lowerDoc;

    if (raw.isNotEmpty && raw != lower) {
      final rawDoc = await _getCachedDoc('pricing_rules', raw);
      if (rawDoc.exists) return rawDoc;
    }

    return lowerDoc;
  }

  static Future<String?> getUnit({required String service}) async {
    if (_isPainting(service)) {
      final pricingDoc = await _getPricingDoc(service: service);
      final unit = pricingDoc.data?['unit'];
      final unitStr = unit is String ? unit.trim() : '';
      if (unitStr.toLowerCase() == 'room') return 'sqft';
      if (unitStr.isNotEmpty) return unitStr;
      return 'sqft';
    }

    final pricingDoc = await _getPricingDoc(service: service);
    if (!pricingDoc.exists) return null;
    final data = pricingDoc.data;
    final unit = data?['unit'];
    return unit is String && unit.trim().isNotEmpty ? unit.trim() : null;
  }

  static Future<Map<String, double>> calculate({
    required String service,
    required double quantity,
    required String zip,
    bool urgent = false,
  }) async {
    if (_isPainting(service)) {
      // Interior painting baseline (walls only): $1.75–$2.75 per sqft.
      final zipKey = zip.trim();
      final zipDoc = await _getCachedDoc('zip_costs', zipKey);

      final zipMultiplier = zipDoc.exists
          ? (zipDoc.data?['multiplier'] as num?)?.toDouble() ?? 1.0
          : 1.0;

      double low = 1.75 * quantity * zipMultiplier;
      double high = 2.75 * quantity * zipMultiplier;
      double rec = 2.25 * quantity * zipMultiplier;

      if (urgent) {
        low *= 1.25;
        rec *= 1.25;
        high *= 1.25;
      }

      return {'low': low, 'recommended': rec, 'premium': high};
    }

    final serviceKey = service.trim().toLowerCase();
    final zipKey = zip.trim();

    final pricingDoc = await _getPricingDoc(service: service);

    if (!pricingDoc.exists) {
      throw Exception(
        "Pricing not configured for '$service'. Create pricing_rules/$serviceKey",
      );
    }

    final pricing = pricingDoc.data ?? {};
    final baseRate = (pricing['baseRate'] as num?)?.toDouble() ?? 0.0;
    final minPrice = (pricing['minPrice'] as num?)?.toDouble() ?? 0.0;
    final maxPrice = (pricing['maxPrice'] as num?)?.toDouble() ?? 10000.0;

    final zipDoc = await _getCachedDoc('zip_costs', zipKey);

    final zipMultiplier = zipDoc.exists
        ? (zipDoc.data?['multiplier'] as num?)?.toDouble() ?? 1.0
        : 1.0;

    double price = baseRate * quantity * zipMultiplier;

    if (urgent) {
      price *= 1.25; // 25% urgency premium
    }

    price = price.clamp(minPrice, maxPrice);

    return {'low': price * 0.9, 'recommended': price, 'premium': price * 1.2};
  }
}
