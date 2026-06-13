import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionVerificationResult {
  const SubscriptionVerificationResult({
    required this.verified,
    this.tier,
    this.status,
    this.message,
  });

  final bool verified;
  final String? tier;
  final String? status;
  final String? message;

  factory SubscriptionVerificationResult.fromData(dynamic data) {
    if (data is! Map) {
      return const SubscriptionVerificationResult(
        verified: false,
        status: 'bad_response',
        message: 'The store response could not be verified.',
      );
    }

    return SubscriptionVerificationResult(
      verified: data['verified'] == true,
      tier: data['tier']?.toString(),
      status: data['status']?.toString(),
      message: data['message']?.toString(),
    );
  }
}

/// Minimal subscription helper.
///
/// Notes:
/// - Requires products configured in Google Play Console / App Store Connect.
/// - For real entitlements, verify purchases server-side.
class SubscriptionService {
  static const String contractorProMonthlyProductId =
      'contractor_pro_monthly_11_99';
  static const String contractorEnterpriseMonthlyProductId =
      'contractor_enterprise_monthly_29_99';

  /// All subscription product IDs that should be queried from the store.
  static const Set<String> allSubscriptionProductIds = {
    contractorProMonthlyProductId,
    contractorEnterpriseMonthlyProductId,
  };

  /// Maps tier ID to store product ID.
  static const Map<String, String> tierToProductId = {
    'pro': contractorProMonthlyProductId,
    'enterprise': contractorEnterpriseMonthlyProductId,
  };

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

  Future<SubscriptionVerificationResult> verifyAndActivateContractorPro(
    PurchaseDetails purchase,
  ) async {
    final useCallable =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (!useCallable) {
      throw Exception('Store subscription verification is not supported here.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'verifyContractorSubscriptionPurchase',
    );
    final response = await callable.call(<String, dynamic>{
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'verificationData': purchase.verificationData.serverVerificationData,
      'verificationSource': purchase.verificationData.source,
      'transactionDate': purchase.transactionDate,
    });
    final result = SubscriptionVerificationResult.fromData(response.data);
    if (!result.verified) {
      throw Exception(
        result.message ??
            'The store purchase was received, but the subscription could not be verified yet.',
      );
    }
    return result;
  }
}
