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

  /// Look up the ZIP-based cost multiplier. Returns 1.0 if no override.
  static Future<double> getZipMultiplier(String zip) async {
    final zipKey = zip.trim();
    if (zipKey.isEmpty) return 1.0;
    final doc = await _getCachedDoc('zip_costs', zipKey);
    if (!doc.exists) return 1.0;
    return (doc.data?['multiplier'] as num?)?.toDouble() ?? 1.0;
  }

  /// Fetch Firestore rate overrides from `pricing_config/{configKey}`.
  ///
  /// Allows admins to update pricing without a code deploy.
  /// Falls back to the hardcoded default when the doc or field is missing.
  static Future<double> _rate(
    String configKey,
    String field,
    double fallback,
  ) async {
    final doc = await _getCachedDoc('pricing_config', configKey);
    if (!doc.exists) return fallback;
    final v = doc.data?[field];
    if (v is num) return v.toDouble();
    return fallback;
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
  ///
  /// Rates are overridable via Firestore `pricing_config/interior_painting`.
  /// ZIP multiplier applied automatically.
  static Future<Map<String, double>> calculatePaintingFromRooms({
    required Map<String, dynamic> paintingQuestions,
    required String zip,
    bool urgent = false,
  }) async {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    bool asBool(dynamic v) => v == true;

    // ── Firestore rate overrides (falls back to hardcoded) ──
    const cfg = 'interior_painting';
    final stdLabor = await _rate(cfg, 'std_room_labor', 450);
    final stdPaint = await _rate(cfg, 'std_room_paint', 500);
    final kitLabor = await _rate(cfg, 'kitchen_labor', 500);
    final kitPaint = await _rate(cfg, 'kitchen_paint', 560);
    final ldLabor = await _rate(cfg, 'living_dining_labor', 500);
    final ldPaint = await _rate(cfg, 'living_dining_paint', 560);
    final ceilStdLabor = await _rate(cfg, 'ceiling_std_labor', 125);
    final ceilStdPaint = await _rate(cfg, 'ceiling_std_paint', 150);
    final ceilKitLabor = await _rate(cfg, 'ceiling_kit_labor', 200);
    final ceilKitPaint = await _rate(cfg, 'ceiling_kit_paint', 225);
    final door1Labor = await _rate(cfg, 'door_one_side_labor', 75);
    final door1Paint = await _rate(cfg, 'door_one_side_paint', 90);
    final door2Labor = await _rate(cfg, 'door_both_sides_labor', 100);
    final door2Paint = await _rate(cfg, 'door_both_sides_paint', 115);
    final trimStdLabor = await _rate(cfg, 'trim_std_labor', 40);
    final trimStdPaint = await _rate(cfg, 'trim_std_paint', 55);
    final trimKitLabor = await _rate(cfg, 'trim_kit_labor', 55);
    final trimKitPaint = await _rate(cfg, 'trim_kit_paint', 70);
    final stairLabor = await _rate(cfg, 'stairwell_labor', 225);
    final stairPaint = await _rate(cfg, 'stairwell_paint', 260);
    final railLabor = await _rate(cfg, 'railing_labor', 200);
    final railPaint = await _rate(cfg, 'railing_paint', 240);
    final accentLabor = await _rate(cfg, 'accent_wall_labor', 150);
    final accentPaint = await _rate(cfg, 'accent_wall_paint', 200);
    final wpStd = await _rate(cfg, 'wallpaper_std', 125);
    final wpLiving = await _rate(cfg, 'wallpaper_living', 280);
    final wpKit = await _rate(cfg, 'wallpaper_kitchen', 250);
    final winLabor = await _rate(cfg, 'window_labor', 35);
    final winPaint = await _rate(cfg, 'window_paint', 50);
    final garLabor = await _rate(cfg, 'garage_labor', 500);
    final garPaint = await _rate(cfg, 'garage_paint', 625);
    final launLabor = await _rate(cfg, 'laundry_labor', 175);
    final launPaint = await _rate(cfg, 'laundry_paint', 220);

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
    final wpKitchensCount = asInt(paintingQuestions['wallpaper_kitchens']);
    final windows = asInt(paintingQuestions['windows']);
    final garages = asInt(paintingQuestions['garages']);
    final laundryRooms = asInt(paintingQuestions['laundry_rooms']);

    final stdRooms = bedrooms + bathrooms + closets;
    final kitchenRooms = kitchens;
    final livingDiningRooms = livingRooms + diningRooms;

    double total = 0;

    // Wall painting
    total += stdRooms * (includesPaint ? stdPaint : stdLabor);
    total += kitchenRooms * (includesPaint ? kitPaint : kitLabor);
    total += livingDiningRooms * (includesPaint ? ldPaint : ldLabor);

    // Ceilings
    if (ceilingBedrooms) {
      total += stdRooms * (includesPaint ? ceilStdPaint : ceilStdLabor);
    }
    if (ceilingKitchens) {
      total += kitchenRooms * (includesPaint ? ceilKitPaint : ceilKitLabor);
    }
    if (ceilingLivingDining) {
      total +=
          livingDiningRooms * (includesPaint ? ceilKitPaint : ceilKitLabor);
    }

    // Doors
    total += doorsOneSide * (includesPaint ? door1Paint : door1Labor);
    total += doorsBothSides * (includesPaint ? door2Paint : door2Labor);

    // Trim / baseboards
    if (trimStandard) {
      total += stdRooms * (includesPaint ? trimStdPaint : trimStdLabor);
    }
    if (trimKitchens) {
      total += kitchenRooms * (includesPaint ? trimKitPaint : trimKitLabor);
    }
    if (trimLivingDining) {
      total +=
          livingDiningRooms * (includesPaint ? trimKitPaint : trimKitLabor);
    }

    // Crown molding (same rates as trim)
    if (crownStandard) {
      total += stdRooms * (includesPaint ? trimStdPaint : trimStdLabor);
    }
    if (crownKitchens) {
      total += kitchenRooms * (includesPaint ? trimKitPaint : trimKitLabor);
    }
    if (crownLivingDining) {
      total +=
          livingDiningRooms * (includesPaint ? trimKitPaint : trimKitLabor);
    }

    // Stairwells
    total += stairwells * (includesPaint ? stairPaint : stairLabor);

    // Railings
    total += railings * (includesPaint ? railPaint : railLabor);

    // Accent walls
    total += accentWalls * (includesPaint ? accentPaint : accentLabor);

    // Wallpaper removal (labor only)
    total += wpStdRooms * wpStd;
    total += wpLivingRooms * wpLiving;
    total += wpKitchensCount * wpKit;

    // Windows
    total += windows * (includesPaint ? winPaint : winLabor);

    // Garage
    total += garages * (includesPaint ? garPaint : garLabor);

    // Laundry
    total += laundryRooms * (includesPaint ? launPaint : launLabor);

    if (urgent) {
      total *= 1.25;
    }

    // Apply ZIP multiplier
    final zipMult = await getZipMultiplier(zip);
    total *= zipMult;

    return {'low': total * 0.88, 'recommended': total, 'premium': total * 1.15};
  }

  /// Sqft-based exterior painting pricing (client-side fallback).
  ///
  /// Per sqft of exterior wall area:
  ///   Siding:  $1.75 labor, $2.25 with paint
  ///   Fascia:  $2.50 labor, $3.50 with paint  (~8% of wall area)
  ///   Soffit:  $2.50 labor, $3.50 with paint  (~10% of wall area)
  ///
  /// Add-ons (flat rate):
  ///   Doors: $200 labor, $300 with paint (each)
  ///   Trim/windows: $35 labor, $50 with paint (per opening)
  ///   Garage door: $200 labor, $300 with paint (each)
  ///   Deck/Fence: $2.00 labor, $3.00 with paint (per sqft)
  ///
  /// Story multiplier: 1=1.0, 2=1.25, 3+=1.50
  /// Color change: +15%
  /// Min job: $1,200
  ///
  /// Rates are overridable via Firestore `pricing_config/exterior_painting`.
  /// ZIP multiplier applied automatically.
  static Future<Map<String, double>> calculateExteriorPaintingFromQuestions({
    required Map<String, dynamic> paintingQuestions,
    required String zip,
    bool urgent = false,
  }) async {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    double asDouble(dynamic v) =>
        v is double ? v : double.tryParse('$v') ?? 0.0;

    // ── Firestore rate overrides ──
    const cfg = 'exterior_painting';
    final sidingLabor = await _rate(cfg, 'siding_labor_sqft', 1.75);
    final sidingPaint = await _rate(cfg, 'siding_paint_sqft', 2.25);
    final fasciaLabor = await _rate(cfg, 'fascia_labor_sqft', 2.50);
    final fasciaPaint = await _rate(cfg, 'fascia_paint_sqft', 3.50);
    final soffitLabor = await _rate(cfg, 'soffit_labor_sqft', 2.50);
    final soffitPaint = await _rate(cfg, 'soffit_paint_sqft', 3.50);
    final trimLaborSqft = await _rate(cfg, 'trim_labor_sqft', 2.75);
    final trimPaintSqft = await _rate(cfg, 'trim_paint_sqft', 4.00);
    final gutterLabor = await _rate(cfg, 'gutter_labor_sqft', 2.50);
    final gutterPaint = await _rate(cfg, 'gutter_paint_sqft', 3.50);
    final doorLabor = await _rate(cfg, 'door_labor', 200);
    final doorPaint = await _rate(cfg, 'door_paint', 300);
    final winLabor = await _rate(cfg, 'window_labor', 35);
    final winPaint = await _rate(cfg, 'window_paint', 50);
    final shutLabor = await _rate(cfg, 'shutter_labor', 55);
    final shutPaint = await _rate(cfg, 'shutter_paint', 80);
    final garLabor = await _rate(cfg, 'garage_door_labor', 200);
    final garPaint = await _rate(cfg, 'garage_door_paint', 300);
    final deckLabor = await _rate(cfg, 'deck_fence_labor_sqft', 2.00);
    final deckPaint = await _rate(cfg, 'deck_fence_paint_sqft', 3.00);
    final minJob = await _rate(cfg, 'min_job', 1200);

    final exteriorSqft = asDouble(paintingQuestions['exterior_sqft']);
    final includesPaint = paintingQuestions['includes_paint'] != false;

    // Stories
    final stories = (paintingQuestions['stories'] ?? '1').toString();
    double storyMultiplier = 1.0;
    if (stories == '2') storyMultiplier = 1.25;
    if (stories == '3_plus' || stories == '3') storyMultiplier = 1.50;

    // What to paint
    final whatToPaint =
        paintingQuestions['what_to_paint'] as Map<String, dynamic>? ?? {};
    final paintSiding = whatToPaint['siding'] != false;
    final paintFascia = whatToPaint['fascia'] == true;
    final paintSoffit = whatToPaint['soffit'] == true;
    final paintTrim = whatToPaint['trim'] == true;
    final paintGutters = whatToPaint['gutters'] == true;

    double total = 0;

    if (paintSiding) {
      total += exteriorSqft * (includesPaint ? sidingPaint : sidingLabor);
    }
    if (paintFascia) {
      final fasciaSqft = (exteriorSqft * 0.08).roundToDouble();
      total += fasciaSqft * (includesPaint ? fasciaPaint : fasciaLabor);
    }
    if (paintSoffit) {
      final soffitSqft = (exteriorSqft * 0.10).roundToDouble();
      total += soffitSqft * (includesPaint ? soffitPaint : soffitLabor);
    }
    if (paintTrim) {
      final trimSqft = (exteriorSqft * 0.06).roundToDouble();
      total += trimSqft * (includesPaint ? trimPaintSqft : trimLaborSqft);
    }
    if (paintGutters) {
      final gutterSqft = (exteriorSqft * 0.04).roundToDouble();
      total += gutterSqft * (includesPaint ? gutterPaint : gutterLabor);
    }

    // Add-ons
    final doors = asInt(paintingQuestions['doors']);
    final windows = asInt(paintingQuestions['windows']);
    final shutterPairs = asInt(paintingQuestions['shutter_pairs']);
    final garageDoors = asInt(paintingQuestions['garage_doors']);
    final deckFenceSqft = asDouble(paintingQuestions['deck_fence_sqft']);

    total += doors * (includesPaint ? doorPaint : doorLabor);
    total += windows * (includesPaint ? winPaint : winLabor);
    total += shutterPairs * (includesPaint ? shutPaint : shutLabor);
    total += garageDoors * (includesPaint ? garPaint : garLabor);
    total += deckFenceSqft * (includesPaint ? deckPaint : deckLabor);

    // Story multiplier
    total *= storyMultiplier;

    // Color change
    if (paintingQuestions['color_finish'] == 'color_change') {
      total *= 1.15;
    }

    if (urgent) {
      total *= 1.25;
    }

    // Apply ZIP multiplier
    final zipMult = await getZipMultiplier(zip);
    total *= zipMult;

    // Minimum job
    if (total < minJob) total = minJob;

    return {'low': total * 0.88, 'recommended': total, 'premium': total * 1.15};
  }

  /// Per-door cabinet painting / refinishing pricing (client-side fallback).
  ///
  /// Painting rates:
  ///   Door face: $125 per door
  ///   Drawer front: $75 per drawer (~60% of door)
  ///   Cabinet box interior (per door): $50 extra
  ///
  /// Refinishing / stain rates:
  ///   Door face: $165 per door
  ///   Drawer front: $100 per drawer
  ///   Cabinet box interior (per door): $65 extra
  ///
  /// Add-ons:
  ///   Crown molding: $200 flat
  ///   Hardware removal & reinstall: $5/door
  ///   Island: $250 flat
  ///
  /// Color change: +15%
  /// ASAP / urgent: +25%
  /// Min job: $800
  ///
  /// Rates are overridable via Firestore `pricing_config/cabinet_refinishing`.
  /// ZIP multiplier applied automatically.
  static Future<Map<String, double>> calculateCabinetFromQuestions({
    required Map<String, dynamic> cabinetQuestions,
    required String zip,
    bool urgent = false,
  }) async {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    bool asBool(dynamic v) => v == true;

    // ── Firestore rate overrides ──
    const cfg = 'cabinet_refinishing';
    final paintDoor = await _rate(cfg, 'paint_door', 125);
    final paintDrawer = await _rate(cfg, 'paint_drawer', 75);
    final paintInteriorRate = await _rate(cfg, 'paint_interior', 150);
    final refinDoor = await _rate(cfg, 'refinish_door', 165);
    final refinDrawer = await _rate(cfg, 'refinish_drawer', 100);
    final refinInteriorRate = await _rate(cfg, 'refinish_interior', 180);
    final crownRate = await _rate(cfg, 'crown_molding', 200);
    final hardwareRate = await _rate(cfg, 'hardware_per_unit', 5);
    final islandRate = await _rate(cfg, 'island', 250);
    final minJob = await _rate(cfg, 'min_job', 800);

    final doors = asInt(cabinetQuestions['cabinet_doors']);
    final drawers = asInt(cabinetQuestions['cabinet_drawers']);
    final cabinets = asInt(cabinetQuestions['cabinet_count']);
    final paintInteriors = asBool(cabinetQuestions['paint_interiors']);

    final workType = (cabinetQuestions['work_type'] ?? 'paint')
        .toString()
        .toLowerCase();
    final isRefinish = workType == 'refinish';

    final doorRate = isRefinish ? refinDoor : paintDoor;
    final drawerRate = isRefinish ? refinDrawer : paintDrawer;
    final interiorRate = isRefinish ? refinInteriorRate : paintInteriorRate;

    double total = 0;

    total += doors * doorRate;
    total += drawers * drawerRate;

    if (paintInteriors) {
      total += cabinets * interiorRate;
    }

    // Add-ons
    if (asBool(cabinetQuestions['crown_molding'])) {
      total += crownRate;
    }
    if (asBool(cabinetQuestions['hardware_reinstall'])) {
      total += (doors + drawers) * hardwareRate;
    }
    if (asBool(cabinetQuestions['has_island'])) {
      total += islandRate;
    }

    // Color change adds 15%
    final colorChange = (cabinetQuestions['color_change'] ?? '')
        .toString()
        .toLowerCase();
    if (colorChange == 'change') {
      total *= 1.15;
    }

    if (urgent) {
      total *= 1.25;
    }

    // Apply ZIP multiplier
    final zipMult = await getZipMultiplier(zip);
    total *= zipMult;

    // Minimum job
    if (total < minJob) total = minJob;

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
