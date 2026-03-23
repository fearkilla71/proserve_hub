import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Maps Google Play / App Store product IDs to internal lead-pack IDs.
///
/// You must create these products in **Google Play Console → Monetize →
/// Products → In-app products** (type: consumable) and (for iOS) in **App
/// Store Connect → In-App Purchases**.
class LeadIapService {
  LeadIapService._();
  static final LeadIapService instance = LeadIapService._();

  // ── Product ID mapping ──
  // The keys match what the bottom-sheet passes (ne_1, ne_10, …).
  // The values are the product IDs configured in the stores.
  static const Map<String, String> packToProductId = {
    'ne_1': 'lead_ne_1',
    'ex_1': 'lead_ex_1',
  };

  /// Pack IDs that should go through native IAP.
  static bool isIapPack(String packId) => packToProductId.containsKey(packId);

  static Set<String> get allProductIds => packToProductId.values.toSet();

  /// Whether the current platform supports store IAP.
  static bool get supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // ── State ──

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Map<String, ProductDetails> _products = {};
  bool _initialised = false;

  /// Callers can set this to react when a purchase completes / fails.
  void Function(PurchaseDetails purchase)? onPurchaseUpdate;

  // ── Lifecycle ──

  /// Call once at app start (guarded by [supported]).
  Future<void> init() async {
    if (!supported || _initialised) return;
    _initialised = true;

    final available = await _iap.isAvailable();
    if (!available) return;

    // Pre-fetch product details from the store.
    final response = await _iap.queryProductDetails(allProductIds);
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }

    _sub = _iap.purchaseStream.listen(_handlePurchaseUpdates);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialised = false;
  }

  // ── Purchasing ──

  /// Returns the [ProductDetails] for a given internal pack ID (e.g. `ne_1`).
  ProductDetails? productFor(String packId) {
    final storeId = packToProductId[packId];
    if (storeId == null) return null;
    return _products[storeId];
  }

  /// Launches the native purchase sheet for a lead pack.
  /// Returns `true` if the purchase flow was started successfully.
  Future<bool> buy(String packId) async {
    final product = productFor(packId);
    if (product == null) {
      throw Exception(
        'Product not found in store. Make sure in-app products are configured.',
      );
    }

    final param = PurchaseParam(productDetails: product);
    return _iap.buyConsumable(purchaseParam: param);
  }

  // ── Purchase stream handling ──

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndDeliver(purchase);
        case PurchaseStatus.pending:
          // Waiting for payment confirmation — nothing to do.
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          // Complete so it doesn't hang.
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
      }
      onPurchaseUpdate?.call(purchase);
    }
  }

  /// Sends the purchase token to the backend for server-side verification,
  /// then marks the purchase complete (consuming it so it can be bought again).
  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyLeadPackPurchase',
      );
      await callable.call(<String, dynamic>{
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'verificationData': purchase.verificationData.serverVerificationData,
        'source': purchase.verificationData.source,
      });
    } catch (e) {
      debugPrint('[LeadIapService] verification error: $e');
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}
