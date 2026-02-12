import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Minimal subscription helper.
///
/// Notes:
/// - Requires products configured in Google Play Console / App Store Connect.
/// - For real entitlements, verify purchases server-side.
class SubscriptionService {
  static const String contractorProMonthlyProductId =
      'contractor_pro_monthly_11_99';

  static bool get supportsStoreIap {
    // `in_app_purchase` supports Android/iOS/macOS. It is not supported on
    // Windows/Linux desktop and should not be touched there.
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<bool> isAvailable() {
    if (!supportsStoreIap) return Future<bool>.value(false);
    return InAppPurchase.instance.isAvailable();
  }

  Stream<List<PurchaseDetails>> get purchaseStream {
    if (!supportsStoreIap) return const Stream<List<PurchaseDetails>>.empty();
    return InAppPurchase.instance.purchaseStream;
  }

  Future<ProductDetailsResponse> queryProducts(Set<String> productIds) {
    if (!supportsStoreIap) {
      throw Exception('Store subscription is not supported on this platform');
    }
    return InAppPurchase.instance.queryProductDetails(productIds);
  }

  Future<void> buy(ProductDetails product) async {
    if (!supportsStoreIap) {
      throw Exception('Store subscription is not supported on this platform');
    }
    final param = PurchaseParam(productDetails: product);
    final ok = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: param,
    );
    if (!ok) {
      throw Exception('Purchase could not be started');
    }
  }

  Future<void> completeIfNeeded(PurchaseDetails purchase) async {
    if (!supportsStoreIap) return;
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  /// Restores previously purchased subscriptions (required by App Store).
  Future<void> restorePurchases() async {
    if (!supportsStoreIap) {
      throw Exception('Store subscription is not supported on this platform');
    }
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> verifyAndActivateContractorPro(PurchaseDetails purchase) async {
    // Best-effort server verification (recommended for real entitlements).
    // This expects you to implement a Cloud Function to validate the receipt
    // and grant access (e.g., mark users/{uid}.isPro = true).
    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (!useCallable) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyContractorSubscriptionPurchase',
      );
      await callable.call(<String, dynamic>{
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'verificationData': purchase.verificationData.serverVerificationData,
        'verificationSource': purchase.verificationData.source,
        'transactionDate': purchase.transactionDate,
      });
    } catch (_) {
      // Ignore by default; UI will show a generic "activation pending".
    }
  }
}
