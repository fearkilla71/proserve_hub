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
      return 'rooms';
    }

    final pricingDoc = await _getPricingDoc(service: service);
    if (!pricingDoc.exists) return null;
    final data = pricingDoc.data;
    final unit = data?['unit'];
    return unit is String && unit.trim().isNotEmpty ? unit.trim() : null;
  }

  /// Room-based interior painting pricing (client-side fallback).
  ///
  /// Standard rooms (bedroom/bath/closet): $450 labor, $500 with paint.
  /// Kitchen: $500 labor, $560 with paint.
  /// Living/Dining: $500 labor, $560 with paint.
  /// Ceilings (standard): $125 labor, $150 with paint.
  /// Ceilings (kitchen/dining): $200 labor, $225 with paint.
  /// Door one side: $75 labor, $90 with paint.
  /// Door both sides: $100 labor, $115 with paint.
  /// Trim std room: $40 labor, $55 with paint.
  /// Trim kitchen/living/dining: $55 labor, $70 with paint.
  /// Crown molding: same rates as trim.
  /// Stairwells: $225 labor, $260 with paint.
  /// Railings: $200 labor, $240 with paint.
  /// Accent walls: $150 labor, $200 with paint.
  /// Wallpaper removal: $125 std, $280 living, $250 kitchen.
  /// Windows: $35 labor, $50 with paint.
  /// Garage: $500 labor, $625 with paint.
  /// Laundry: $175 labor, $220 with paint.
  static Map<String, double> calculatePaintingFromRooms({
    required Map<String, dynamic> paintingQuestions,
    required String zip,
    bool urgent = false,
  }) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    bool asBool(dynamic v) => v == true;

    final bedrooms = asInt(paintingQuestions['bedrooms']);
    final bathrooms = asInt(paintingQuestions['bathrooms']);
    final closets = asInt(paintingQuestions['closets']);
    final kitchens = asInt(paintingQuestions['kitchens']);
    final livingRooms = asInt(paintingQuestions['living_rooms']);
    final diningRooms = asInt(paintingQuestions['dining_rooms']);
    final includesPaint = asBool(paintingQuestions['includes_paint']);

    final ceilingBedrooms = asBool(paintingQuestions['ceiling_bedrooms']);
    final ceilingKitchens = asBool(paintingQuestions['ceiling_kitchens']);
    final ceilingLivingDining = asBool(
      paintingQuestions['ceiling_living_dining'],
    );

    // Doors
    final doorsOneSide = asInt(paintingQuestions['doors_one_side']);
    final doorsBothSides = asInt(paintingQuestions['doors_both_sides']);

    // Trim
    final trimStandard = asBool(paintingQuestions['trim_standard']);
    final trimKitchens = asBool(paintingQuestions['trim_kitchens']);
    final trimLivingDining = asBool(paintingQuestions['trim_living_dining']);

    // Crown molding
    final crownStandard = asBool(paintingQuestions['crown_standard']);
    final crownKitchens = asBool(paintingQuestions['crown_kitchens']);
    final crownLivingDining = asBool(paintingQuestions['crown_living_dining']);

    // Additional items
    final stairwells = asInt(paintingQuestions['stairwells']);
    final railings = asInt(paintingQuestions['railings']);
    final accentWalls = asInt(paintingQuestions['accent_walls']);
    final wpStdRooms = asInt(paintingQuestions['wallpaper_std_rooms']);
    final wpLivingRooms = asInt(paintingQuestions['wallpaper_living_rooms']);
    final wpKitchens = asInt(paintingQuestions['wallpaper_kitchens']);
    final windows = asInt(paintingQuestions['windows']);
    final garages = asInt(paintingQuestions['garages']);
    final laundryRooms = asInt(paintingQuestions['laundry_rooms']);

    final stdRooms = bedrooms + bathrooms + closets;
    final kitchenRooms = kitchens;
    final livingDiningRooms = livingRooms + diningRooms;

    double total = 0;

    // Wall painting
    total += stdRooms * (includesPaint ? 500 : 450);
    total += kitchenRooms * (includesPaint ? 560 : 500);
    total += livingDiningRooms * (includesPaint ? 560 : 500);

    // Ceilings
    if (ceilingBedrooms) {
      total += stdRooms * (includesPaint ? 150 : 125);
    }
    if (ceilingKitchens) {
      total += kitchenRooms * (includesPaint ? 225 : 200);
    }
    if (ceilingLivingDining) {
      total += livingDiningRooms * (includesPaint ? 225 : 200);
    }

    // Doors
    total += doorsOneSide * (includesPaint ? 90 : 75);
    total += doorsBothSides * (includesPaint ? 115 : 100);

    // Trim / baseboards
    if (trimStandard) {
      total += stdRooms * (includesPaint ? 55 : 40);
    }
    if (trimKitchens) {
      total += kitchenRooms * (includesPaint ? 70 : 55);
    }
    if (trimLivingDining) {
      total += livingDiningRooms * (includesPaint ? 70 : 55);
    }

    // Crown molding (same rates as trim)
    if (crownStandard) {
      total += stdRooms * (includesPaint ? 55 : 40);
    }
    if (crownKitchens) {
      total += kitchenRooms * (includesPaint ? 70 : 55);
    }
    if (crownLivingDining) {
      total += livingDiningRooms * (includesPaint ? 70 : 55);
    }

    // Stairwells
    total += stairwells * (includesPaint ? 260 : 225);

    // Railings
    total += railings * (includesPaint ? 240 : 200);

    // Accent walls
    total += accentWalls * (includesPaint ? 200 : 150);

    // Wallpaper removal (labor only)
    total += wpStdRooms * 125;
    total += wpLivingRooms * 280;
    total += wpKitchens * 250;

    // Windows
    total += windows * (includesPaint ? 50 : 35);

    // Garage
    total += garages * (includesPaint ? 625 : 500);

    // Laundry
    total += laundryRooms * (includesPaint ? 220 : 175);

    if (urgent) {
      total *= 1.25;
    }

    return {'low': total * 0.88, 'recommended': total, 'premium': total * 1.15};
  }

  static Future<Map<String, double>> calculate({
    required String service,
    required double quantity,
    required String zip,
    bool urgent = false,
  }) async {
    if (_isPainting(service)) {
      // Room-based pricing – delegate to calculatePaintingFromRooms if we have
      // painting questions data, otherwise fall back to a simple per-room rate.
      return {
        'low': 450.0 * quantity * 0.88,
        'recommended': 450.0 * quantity,
        'premium': 450.0 * quantity * 1.15,
      };
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
