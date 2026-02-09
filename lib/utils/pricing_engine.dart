import 'package:cloud_firestore/cloud_firestore.dart';

class PricingEngine {
  static bool _isPainting(String service) {
    final s = service.trim().toLowerCase();
    return s.contains('paint');
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> _getPricingDoc({
    required String service,
  }) async {
    final raw = service.trim();
    final lower = raw.toLowerCase();
    final col = FirebaseFirestore.instance.collection('pricing_rules');

    final lowerDoc = await col.doc(lower).get();
    if (lowerDoc.exists) return lowerDoc;

    if (raw.isNotEmpty && raw != lower) {
      final rawDoc = await col.doc(raw).get();
      if (rawDoc.exists) return rawDoc;
    }

    return lowerDoc;
  }

  static Future<String?> getUnit({required String service}) async {
    if (_isPainting(service)) {
      // Default unit for painting estimates: home square footage.
      // If Firestore is configured differently, the backend estimator still uses sqft.
      final pricingDoc = await _getPricingDoc(service: service);
      final unit = pricingDoc.data()?['unit'];
      final unitStr = unit is String ? unit.trim() : '';
      if (unitStr.toLowerCase() == 'room') return 'sqft';
      if (unitStr.isNotEmpty) return unitStr;
      return 'sqft';
    }

    final pricingDoc = await _getPricingDoc(service: service);
    if (!pricingDoc.exists) return null;
    final data = pricingDoc.data();
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
      final zipDoc = await FirebaseFirestore.instance
          .collection('zip_costs')
          .doc(zipKey)
          .get();

      final zipMultiplier = zipDoc.exists
          ? (zipDoc.data()!['multiplier'] as num).toDouble()
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

    final pricing = pricingDoc.data()!;
    final baseRate = (pricing['baseRate'] as num).toDouble();
    final minPrice = (pricing['minPrice'] as num).toDouble();
    final maxPrice = (pricing['maxPrice'] as num).toDouble();

    final zipDoc = await FirebaseFirestore.instance
        .collection('zip_costs')
        .doc(zipKey)
        .get();

    final zipMultiplier = zipDoc.exists
        ? (zipDoc.data()!['multiplier'] as num).toDouble()
        : 1.0;

    double price = baseRate * quantity * zipMultiplier;

    if (urgent) {
      price *= 1.25; // 25% urgency premium
    }

    price = price.clamp(minPrice, maxPrice);

    return {'low': price * 0.9, 'recommended': price, 'premium': price * 1.2};
  }
}
