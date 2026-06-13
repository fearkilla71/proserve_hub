import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/stripe_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_error_handler.dart';

class ContractorSubscriptionScreen extends StatefulWidget {
  const ContractorSubscriptionScreen({super.key});

  @override
  State<ContractorSubscriptionScreen> createState() =>
      _ContractorSubscriptionScreenState();
}

class _ContractorSubscriptionScreenState
    extends State<ContractorSubscriptionScreen>
    with WidgetsBindingObserver {
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://proservehub.app/privacy',
  );
  static final Uri _termsOfUseUri = Uri.parse('https://proservehub.app/terms');

  bool _isLoadingStripe = false;
  bool _isLoadingIap = false;
  bool _pendingAutoRefreshAfterStripe = false;
  bool _isAutoRefreshing = false;
  int _autoRefreshAttempts = 0;

  bool get _isIos => Platform.isIOS;

  String _storeName() => Platform.isIOS ? 'Apple' : 'Google Play';

  String _tierName(AppLocalizations l10n, String tierId) {
    switch (tierId) {
      case 'pro':
        return l10n.subscriptionTierPro;
      case 'enterprise':
        return l10n.subscriptionTierEnterprise;
      default:
        return l10n.subscriptionTierBasic;
    }
  }

  String _tierPrice(AppLocalizations l10n, String tierId) {
    switch (tierId) {
      case 'pro':
        return r'$11.99/mo';
      case 'enterprise':
        return r'$29.99/mo';
      default:
        return l10n.subscriptionPriceFree;
    }
  }

  List<String> _tierFeatures(AppLocalizations l10n, String tierId) {
    switch (tierId) {
      case 'pro':
        return [
          l10n.subscriptionFeatureEverythingBasic,
          l10n.subscriptionFeaturePricingCalculator,
          l10n.subscriptionFeatureCostEstimator,
          l10n.subscriptionFeatureAiInvoiceMaker,
          l10n.subscriptionFeatureRenderTool,
        ];
      case 'enterprise':
        return [
          l10n.subscriptionFeatureEverythingPro,
          l10n.subscriptionFeatureProfitLossDashboard,
          l10n.subscriptionFeaturePriorityJobFeed,
          l10n.subscriptionFeatureUnlimitedAi,
          l10n.subscriptionFeatureInvoicePaymentCollection,
          l10n.subscriptionFeatureSubcontractorBoard,
          l10n.subscriptionFeatureCrewRoster,
        ];
      default:
        return [
          l10n.subscriptionFeatureJobFeedAccess,
          l10n.subscriptionFeatureAcceptCustomerBids,
          l10n.subscriptionFeatureCommunityFeed,
        ];
    }
  }

  /// Subscription tiers — ordered from least to most features.
  static const _tiers = <_SubscriptionTier>[
    _SubscriptionTier(id: 'basic'),
    _SubscriptionTier(id: 'pro', recommended: true),
    _SubscriptionTier(id: 'enterprise'),
  ];

  /// Returns the user's current tier from Firestore.
  String _tierFromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return 'basic';
    // Check new tier field first, fall back to legacy booleans.
    final tier = data['subscriptionTier'] as String?;
    if (tier != null && tier.isNotEmpty) return tier;
    if (data['pricingToolsPro'] == true ||
        data['contractorPro'] == true ||
        data['isPro'] == true) {
      return 'pro';
    }
    return 'basic';
  }

  bool _isProFromUserDoc(Map<String, dynamic>? data) {
    final tier = _tierFromUserDoc(data);
    return tier == 'pro' || tier == 'enterprise';
  }

  Future<bool> _fetchIsPro(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.serverAndCache));
    return _isProFromUserDoc(snap.data());
  }

  Future<void> _autoRefreshEntitlement({bool syncStripe = true}) async {
    if (_isAutoRefreshing) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isAutoRefreshing = true;
    _autoRefreshAttempts = 0;

    while (mounted && _autoRefreshAttempts < 6) {
      _autoRefreshAttempts++;
      if (syncStripe) {
        try {
          await StripeService().syncContractorProEntitlement();
        } catch (e) {
          debugPrint('syncEntitlement retry #$_autoRefreshAttempts failed: $e');
        }
      }

      final unlocked = await _fetchIsPro(uid);
      if (unlocked || !mounted) {
        break;
      }

      await Future.delayed(const Duration(seconds: 8));
    }

    _isAutoRefreshing = false;
  }

  final _subs = SubscriptionService();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _iapAvailable = false;

  /// Store products keyed by store product ID.
  Map<String, ProductDetails> _storeProducts = {};
  String? _iapError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _purchaseSub = _subs.purchaseStream.listen(_onPurchases);
    _loadProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingAutoRefreshAfterStripe) {
      _pendingAutoRefreshAfterStripe = false;
      _autoRefreshEntitlement();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _iapError = null;
      _storeProducts = {};
    });

    try {
      final available = await _subs.isAvailable();
      if (!mounted) return;
      setState(() => _iapAvailable = available);
      if (!available) {
        final l10n = AppLocalizations.of(context)!;
        final storeName = _storeName();
        setState(
          () => _iapError = l10n.subscriptionStoreUnavailable(storeName),
        );
        return;
      }

      final resp = await _subs.queryProducts(
        SubscriptionService.allSubscriptionProductIds,
      );
      if (!mounted) return;
      if (resp.error != null) {
        final l10n = AppLocalizations.of(context)!;
        setState(
          () => _iapError = l10n.subscriptionProductLoadFailed(
            resp.error!.message,
          ),
        );
        return;
      }
      if (resp.notFoundIDs.isNotEmpty) {
        final l10n = AppLocalizations.of(context)!;
        setState(
          () => _iapError = l10n.subscriptionMissingProducts(
            resp.notFoundIDs.join(', '),
          ),
        );
      }
      if (resp.productDetails.isEmpty) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _iapError = l10n.subscriptionNoProductsAvailable);
        return;
      }
      final products = <String, ProductDetails>{};
      for (final p in resp.productDetails) {
        products[p.id] = p;
      }
      setState(() => _storeProducts = products);
    } catch (e) {
      if (!mounted) return;
      setState(() => _iapError = e.toString());
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (!mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subscriptionPurchasePending)),
        );
      } else if (purchase.status == PurchaseStatus.error) {
        if (!mounted) continue;
        final msg = purchase.error?.message ?? l10n.subscriptionPurchaseFailed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (!mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subscriptionPurchaseCanceled)),
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          final result = await _subs.verifyAndActivateContractorPro(purchase);
          if (!mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.tier == 'enterprise'
                    ? l10n.subscriptionEnterpriseActivated
                    : l10n.subscriptionProActivated,
              ),
            ),
          );
          await _autoRefreshEntitlement(syncStripe: false);
        } catch (e) {
          if (!mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.subscriptionVerificationFailed(e.toString())),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }

      await _subs.completeIfNeeded(purchase);
    }

    if (mounted) setState(() => _isLoadingIap = false);
  }

  Future<void> _startStripeCheckout(String tierId) async {
    if (_isIos) return;
    if (_isLoadingStripe) return;

    final messenger = ScaffoldMessenger.of(context);
    final checkoutReturnMessage = AppLocalizations.of(
      context,
    )!.subscriptionCheckoutBrowserReturn;
    setState(() => _isLoadingStripe = true);

    try {
      await StripeService().payForContractorSubscription(tier: tierId);
      _pendingAutoRefreshAfterStripe = true;
      _autoRefreshEntitlement();
      messenger.showSnackBar(SnackBar(content: Text(checkoutReturnMessage)));
    } catch (e, st) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      AppError.show(context, e, st, action: 'start Stripe checkout');
    } finally {
      if (mounted) setState(() => _isLoadingStripe = false);
    }
  }

  Future<void> _startStoreSubscription({required String tierId}) async {
    if (_isLoadingIap) return;
    final storeProductId = SubscriptionService.tierToProductId[tierId];
    final product = storeProductId != null
        ? _storeProducts[storeProductId]
        : null;
    if (product == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.subscriptionStoreTierUnavailable(_tierName(l10n, tierId)),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoadingIap = true);
    try {
      await _subs.buy(product);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _isLoadingIap = false);
      AppError.show(context, e, st, action: 'start store subscription');
    }
  }

  Future<void> _openLegalLink(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionPlansTitle)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseAuth.instance.currentUser == null
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final currentTier = _tierFromUserDoc(data);
          final unlocked = _isProFromUserDoc(data);

          // Auto-refresh is now only triggered after a purchase attempt
          // (Stripe checkout return or IAP purchase), not on every build
          // for free-tier users.

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Status card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.subscriptionCurrentPlan,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Chip(
                            label: Text(_tierName(l10n, currentTier)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (!unlocked && _isAutoRefreshing) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.subscriptionUpdatingStatus,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_iapError != null) ...[
                Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _iapError!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _loadProducts,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Tier cards
              ..._tiers.map((tier) {
                final isActive = tier.id == currentTier;
                final isUpgrade = _tierIndex(tier.id) > _tierIndex(currentTier);

                return Card(
                  shape: tier.recommended
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: scheme.primary, width: 2),
                        )
                      : null,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _tierName(l10n, tier.id),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (tier.recommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l10n.subscriptionPopular,
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            if (isActive)
                              Chip(
                                label: Text(l10n.subscriptionCurrent),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tierPrice(l10n, tier.id),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.primary,
                              ),
                        ),
                        if (tier.id != 'basic') ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.subscriptionManagedSettings(
                              Platform.isIOS
                                  ? 'Apple ID Settings'
                                  : 'Google Play subscriptions',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ..._tierFeatures(
                          l10n,
                          tier.id,
                        ).map((f) => _BenefitRow(text: f)),
                        if (isUpgrade && tier.id != 'basic') ...[
                          const SizedBox(height: 16),
                          if (!_isIos) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoadingStripe
                                    ? null
                                    : () => _startStripeCheckout(tier.id),
                                icon: _isLoadingStripe
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.credit_card),
                                label: Text(
                                  _isLoadingStripe
                                      ? l10n.subscriptionOpeningCheckout
                                      : l10n.subscriptionUpgradeWithCard,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Builder(
                            builder: (context) {
                              final storeProductId =
                                  SubscriptionService.tierToProductId[tier.id];
                              final product = storeProductId != null
                                  ? _storeProducts[storeProductId]
                                  : null;
                              final storePrice = product?.price;
                              final storeName = _storeName();
                              final storeLabel = storePrice != null
                                  ? l10n.subscriptionSubscribeWithStorePrice(
                                      storeName,
                                      storePrice,
                                    )
                                  : l10n.subscriptionSubscribeWithStore(
                                      storeName,
                                    );
                              final canBuy = _iapAvailable && product != null;
                              return SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoadingIap || !canBuy
                                      ? null
                                      : () => _startStoreSubscription(
                                          tierId: tier.id,
                                        ),
                                  icon: _isLoadingIap
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.shopping_bag),
                                  label: Text(
                                    _isLoadingIap
                                        ? l10n.subscriptionOpeningStore
                                        : canBuy
                                        ? storeLabel
                                        : l10n.subscriptionStoreUnavailableShort(
                                            storeName,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                Platform.isIOS
                    ? l10n.subscriptionIosManagementCopy
                    : l10n.subscriptionAndroidManagementCopy,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.subscriptionInformation,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.subscriptionAutoRenewInfo(
                          Platform.isIOS
                              ? 'Apple account'
                              : 'Google Play account',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _openLegalLink(_privacyPolicyUri),
                            child: Text(l10n.privacyPolicy),
                          ),
                          TextButton(
                            onPressed: () => _openLegalLink(_termsOfUseUri),
                            child: Text(l10n.termsOfUse),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_iapAvailable)
                TextButton.icon(
                  onPressed: _isLoadingIap
                      ? null
                      : () async {
                          setState(() => _isLoadingIap = true);
                          try {
                            await _subs.restorePurchases();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.subscriptionRestoreComplete),
                              ),
                            );
                            await _autoRefreshEntitlement(syncStripe: false);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.subscriptionRestoreFailed(e.toString()),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoadingIap = false);
                          }
                        },
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.subscriptionRestorePurchases),
                ),
            ],
          );
        },
      ),
    );
  }

  int _tierIndex(String tier) {
    switch (tier) {
      case 'enterprise':
        return 2;
      case 'pro':
        return 1;
      default:
        return 0;
    }
  }
}

class _SubscriptionTier {
  final String id;
  final bool recommended;

  const _SubscriptionTier({required this.id, this.recommended = false});
}

class _BenefitRow extends StatelessWidget {
  final String text;

  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: scheme.tertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
