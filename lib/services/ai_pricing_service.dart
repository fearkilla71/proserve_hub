import '../utils/pricing_engine.dart';

/// AI-powered pricing service that generates fair market prices.
///
/// Uses the existing [PricingEngine] (Firestore `pricing_rules` + `zip_costs`)
/// as its base, then applies intelligent adjustments for job complexity,
/// urgency, and market conditions.
class AiPricingService {
  AiPricingService._();
  static final AiPricingService instance = AiPricingService._();

  /// Platform fee percentage (5%).
  static const double platformFeeRate = 0.05;

  /// Generate an AI price for a job request.
  ///
  /// Returns a map with:
  /// - `low`, `recommended`, `premium` — the three price tiers
  /// - `aiPrice` — the recommended price (what the customer sees)
  /// - `platformFee` — 5% of aiPrice kept by ProServe Hub
  /// - `contractorPayout` — 95% of aiPrice released to contractor
  /// - `confidence` — 0.0–1.0 confidence in the estimate
  /// - `factors` — list of human-readable factors that influenced pricing
  Future<Map<String, dynamic>> generatePrice({
    required String service,
    required double quantity,
    required String zip,
    bool urgent = false,
    Map<String, dynamic>? jobDetails,
    double loyaltyDiscount = 0.0, // 0.0–0.08 from EscrowStatsService
  }) async {
    // 1. Get base pricing — use the dedicated painting calculators when
    //    paintingQuestions are available so we get accurate per-item rates
    //    instead of the generic $450-per-room fallback.
    final paintingQuestions =
        jobDetails?['paintingQuestions'] as Map<String, dynamic>?;
    final paintingScope = (paintingQuestions?['scope'] ?? '')
        .toString()
        .toLowerCase();

    final cabinetQuestions =
        jobDetails?['cabinetQuestions'] as Map<String, dynamic>?;

    Map<String, double> basePrices;
    if (service.toLowerCase().contains('paint') && paintingQuestions != null) {
      if (paintingScope == 'exterior') {
        basePrices = await PricingEngine.calculateExteriorPaintingFromQuestions(
          paintingQuestions: paintingQuestions,
          zip: zip,
          urgent: urgent,
        );
      } else {
        basePrices = await PricingEngine.calculatePaintingFromRooms(
          paintingQuestions: paintingQuestions,
          zip: zip,
          urgent: urgent,
        );
      }
    } else if (service.toLowerCase().contains('cabinet') &&
        cabinetQuestions != null) {
      basePrices = await PricingEngine.calculateCabinetFromQuestions(
        cabinetQuestions: cabinetQuestions,
        zip: zip,
        urgent: urgent,
      );
    } else {
      basePrices = await PricingEngine.calculate(
        service: service,
        quantity: quantity,
        zip: zip,
        urgent: urgent,
      );
    }

    final low = basePrices['low']!;
    final recommended = basePrices['recommended']!;
    final premium = basePrices['premium']!;

    // 2. Apply complexity adjustments from job details
    double complexityMultiplier = 1.0;
    final factors = <String>[];

    if (jobDetails != null) {
      complexityMultiplier = _calculateComplexityMultiplier(
        service: service,
        details: jobDetails,
        factors: factors,
      );
    }

    // 3. Apply complexity to recommended price
    final adjustedRecommended = recommended * complexityMultiplier;
    final adjustedLow = low * complexityMultiplier;
    final adjustedPremium = premium * complexityMultiplier;

    // Round to nearest $5 for cleaner pricing
    final aiPrice = _roundTo5(adjustedRecommended);

    // 4. (platform split computed after discount below)

    // 5. Calculate confidence
    final confidence = _calculateConfidence(
      service: service,
      quantity: quantity,
      jobDetails: jobDetails,
    );

    // Always add base factors
    if (urgent) factors.add('Urgency premium (+25%)');
    factors.add('Market rate for $zip area');

    // 6. Calculate estimated market price (what contractors typically charge)
    // Contractors mark up 18-25% over fair market value
    final marketMultiplier = 1.0 + (0.18 + (confidence * 0.07));
    final estimatedMarketPrice = _roundTo5(aiPrice * marketMultiplier);

    // 7. Calculate instant booking discount (10% for booking now)
    // Plus loyalty discount (0-8% for repeat customers)
    final totalDiscountPercent = 10.0 + (loyaltyDiscount * 100);
    final originalAiPrice = aiPrice;
    final discountedAiPrice = _roundTo5(
      aiPrice * (1 - totalDiscountPercent / 100),
    );
    final discountedFee = _roundCents(discountedAiPrice * platformFeeRate);
    final discountedPayout = _roundCents(discountedAiPrice - discountedFee);

    // Add loyalty factor if applicable
    if (loyaltyDiscount > 0) {
      factors.add(
        'Loyalty reward (−${(loyaltyDiscount * 100).toStringAsFixed(0)}%)',
      );
    }

    return {
      'low': _roundTo5(adjustedLow),
      'recommended': _roundTo5(adjustedRecommended),
      'premium': _roundTo5(adjustedPremium),
      'aiPrice': discountedAiPrice,
      'originalAiPrice': originalAiPrice,
      'discountPercent': totalDiscountPercent,
      'loyaltyDiscountPercent': loyaltyDiscount * 100,
      'platformFee': discountedFee,
      'contractorPayout': discountedPayout,
      'estimatedMarketPrice': estimatedMarketPrice,
      'savingsAmount': _roundCents(estimatedMarketPrice - discountedAiPrice),
      'savingsPercent': estimatedMarketPrice > 0
          ? _roundCents(
              ((estimatedMarketPrice - discountedAiPrice) /
                      estimatedMarketPrice) *
                  100,
            )
          : 0.0,
      'confidence': confidence,
      'factors': factors,
    };
  }

  double _calculateComplexityMultiplier({
    required String service,
    required Map<String, dynamic> details,
    required List<String> factors,
  }) {
    double multiplier = 1.0;
    final svc = service.trim().toLowerCase();

    if (svc.contains('paint')) {
      return _paintingComplexity(details, factors);
    }
    if (svc.contains('cabinet')) {
      return _cabinetComplexity(details, factors);
    }

    // Generic complexity factors
    final desc = (details['description'] ?? '').toString().toLowerCase();

    if (desc.contains('repair') || desc.contains('damage')) {
      multiplier *= 1.15;
      factors.add('Repair work detected (+15%)');
    }
    if (desc.contains('custom') || desc.contains('specialty')) {
      multiplier *= 1.10;
      factors.add('Custom/specialty work (+10%)');
    }
    if (desc.contains('commercial') || desc.contains('business')) {
      multiplier *= 1.12;
      factors.add('Commercial property (+12%)');
    }
    if (desc.contains('multi') || desc.contains('story')) {
      multiplier *= 1.08;
      factors.add('Multi-level property (+8%)');
    }

    return multiplier;
  }

  double _paintingComplexity(
    Map<String, dynamic> details,
    List<String> factors,
  ) {
    double multiplier = 1.0;
    final questions =
        details['paintingQuestions'] as Map<String, dynamic>? ?? {};

    // Wall condition
    final wallCondition = (questions['wall_condition'] ?? '').toString();
    if (wallCondition == 'poor') {
      multiplier *= 1.20;
      factors.add('Poor wall condition — prep needed (+20%)');
    } else if (wallCondition == 'fair') {
      multiplier *= 1.05;
      factors.add('Fair wall condition (+5%)');
    }

    // Ceiling height
    final ceilingHeight = (questions['ceiling_height'] ?? '').toString();
    if (ceilingHeight.contains('10') || ceilingHeight.contains('12')) {
      multiplier *= 1.10;
      factors.add('High ceilings (+10%)');
    } else if (ceilingHeight.contains('vault') ||
        ceilingHeight.contains('14')) {
      multiplier *= 1.25;
      factors.add('Vaulted ceilings (+25%)');
    }

    // Paint what's included
    final whatToPaint = questions['what_to_paint'] as Map<String, dynamic>?;
    if (whatToPaint != null) {
      int extras = 0;
      if (whatToPaint['trim'] == true) extras++;
      if (whatToPaint['ceiling'] == true) extras++;
      if (whatToPaint['doors'] == true) extras++;
      if (whatToPaint['window_frames'] == true) extras++;
      if (extras >= 3) {
        multiplier *= 1.15;
        factors.add('Full scope (trim, ceilings, doors) (+15%)');
      } else if (extras >= 1) {
        multiplier *= 1.0 + (extras * 0.04);
        factors.add('Additional surfaces (+${(extras * 4)}%)');
      }
    }

    // Color change
    final colorFinish = (questions['color_finish'] ?? '').toString();
    if (colorFinish.contains('dark') || colorFinish.contains('drastic')) {
      multiplier *= 1.10;
      factors.add('Drastic color change (+10%)');
    }

    // Number of rooms
    final rooms = int.tryParse((questions['rooms_painting'] ?? '').toString());
    if (rooms != null && rooms > 5) {
      multiplier *= 1.05;
      factors.add('Large job ($rooms rooms) (+5%)');
    }

    // New construction (easier = discount)
    if (questions['new_construction'] == true) {
      multiplier *= 0.90;
      factors.add('New construction (no prep) (−10%)');
    }

    return multiplier;
  }

  double _cabinetComplexity(
    Map<String, dynamic> details,
    List<String> factors,
  ) {
    double multiplier = 1.0;
    final questions =
        details['cabinetQuestions'] as Map<String, dynamic>? ?? {};

    // Commercial property
    final propType = (questions['property_type'] ?? '').toString();
    if (propType == 'business') {
      multiplier *= 1.10;
      factors.add('Commercial property (+10%)');
    }

    // Large door count (above typical kitchen ~25 doors)
    final doors = (questions['cabinet_doors'] ?? 0) as int;
    if (doors > 40) {
      multiplier *= 1.08;
      factors.add('Large cabinet set ($doors doors) (+8%)');
    }

    return multiplier;
  }

  double _calculateConfidence({
    required String service,
    required double quantity,
    Map<String, dynamic>? jobDetails,
  }) {
    double confidence = 0.60; // Base confidence

    // More quantity info → higher confidence
    if (quantity > 0) confidence += 0.10;

    // Service-specific details boost confidence
    if (jobDetails != null) {
      if (jobDetails.containsKey('paintingQuestions')) confidence += 0.15;
      if (jobDetails.containsKey('cabinetQuestions')) confidence += 0.15;
      if (jobDetails.containsKey('description') &&
          (jobDetails['description'] as String).length > 50) {
        confidence += 0.10;
      }
      if (jobDetails.containsKey('propertyType')) confidence += 0.05;
    }

    return confidence.clamp(0.0, 0.95);
  }

  /// Round to the nearest $5.
  double _roundTo5(double value) {
    return (value / 5).round() * 5.0;
  }

  /// Round to 2 decimal places.
  double _roundCents(double value) {
    return (value * 100).round() / 100;
  }
}
