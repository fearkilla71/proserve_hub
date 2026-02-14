import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';

import '../services/stripe_service.dart';
import '../services/subscription_service.dart';

class ContractorSubscriptionScreen extends StatefulWidget {
  const ContractorSubscriptionScreen({super.key});

  @override
  State<ContractorSubscriptionScreen> createState() =>
      _ContractorSubscriptionScreenState();
}

class _ContractorSubscriptionScreenState
    extends State<ContractorSubscriptionScreen>
    with WidgetsBindingObserver {
  bool _isLoadingStripe = false;
  bool _isLoadingIap = false;
  bool _pendingAutoRefreshAfterStripe = false;
  bool _isAutoRefreshing = false;
  int _autoRefreshAttempts = 0;

  /// Subscription tiers — ordered from least to most features.
  static const _tiers = <_SubscriptionTier>[
    _SubscriptionTier(
      id: 'basic',
      name: 'Basic',
      price: r'Free',
      features: ['Job feed access', 'Accept customer bids', 'Community feed'],
    ),
    _SubscriptionTier(
      id: 'pro',
      name: 'Pro',
      price: r'$11.99/mo',
      features: [
        'Everything in Basic',
        'Pricing Calculator',
        'Cost Estimator',
        'AI Invoice Maker',
        'Render Tool',
      ],
      recommended: true,
    ),
    _SubscriptionTier(
      id: 'enterprise',
      name: 'Enterprise',
      price: r'$29.99/mo',
      features: [
        'Everything in Pro',
        'Profit & Loss Dashboard',
        'Priority job feed (30 min early)',
        'Unlimited AI estimates & renders',
        'Invoice payment collection',
        'Subcontractor board',
        'Crew roster & scheduling',
      ],
    ),
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

  Future<void> _autoRefreshEntitlement() async {
    if (_isAutoRefreshing) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isAutoRefreshing = true;
    _autoRefreshAttempts = 0;

    while (mounted && _autoRefreshAttempts < 6) {
      _autoRefreshAttempts++;
      try {
        await StripeService().syncContractorProEntitlement();
      } catch (_) {
        // Best-effort: ignore and retry.
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
  ProductDetails? _monthlyProduct;
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
      _monthlyProduct = null;
    });

    try {
      final available = await _subs.isAvailable();
      if (!mounted) return;
      setState(() => _iapAvailable = available);
      if (!available) return;

      final resp = await _subs.queryProducts({
        SubscriptionService.contractorProMonthlyProductId,
      });
      if (!mounted) return;
      if (resp.error != null) {
        setState(() => _iapError = resp.error!.message);
        return;
      }
      if (resp.productDetails.isEmpty) {
        setState(
          () => _iapError =
              'Subscription not configured in the store yet (missing product id: ${SubscriptionService.contractorProMonthlyProductId}).',
        );
        return;
      }
      setState(() => _monthlyProduct = resp.productDetails.first);
    } catch (e) {
      if (!mounted) return;
      setState(() => _iapError = e.toString());
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty) return;

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        // UI already shows loading state; keep going.
      } else if (purchase.status == PurchaseStatus.error) {
        if (!mounted) continue;
        final msg = purchase.error?.message ?? 'Purchase failed.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _subs.verifyAndActivateContractorPro(purchase);
        if (!mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase received. Activation may take a moment.'),
          ),
        );
      }

      await _subs.completeIfNeeded(purchase);
    }

    if (mounted) setState(() => _isLoadingIap = false);
  }

  Future<void> _startStripeCheckout(String tierId) async {
    if (_isLoadingStripe) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoadingStripe = true);

    try {
      await StripeService().payForContractorSubscription(tier: tierId);
      _pendingAutoRefreshAfterStripe = true;
      _autoRefreshEntitlement();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Complete checkout in the browser, then return to the app. We will update your status automatically.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoadingStripe = false);
    }
  }

  Future<void> _startStoreSubscription() async {
    if (_isLoadingIap) return;
    final product = _monthlyProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store subscription not available yet.')),
      );
      return;
    }

    setState(() => _isLoadingIap = true);
    try {
      await _subs.buy(product);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingIap = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final storePrice = _monthlyProduct?.price;
    final storeLabel = _iapAvailable
        ? (storePrice == null
              ? 'Subscribe with Google Play'
              : 'Subscribe with Google Play ($storePrice)')
        : 'Google Play subscription unavailable';

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Plans')),
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

          if (!unlocked) {
            // Only trigger once, not every rebuild
            if (!_isAutoRefreshing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _autoRefreshEntitlement();
              });
            }
          }

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
                              'Current Plan',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Chip(
                            label: Text(
                              currentTier[0].toUpperCase() +
                                  currentTier.substring(1),
                            ),
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
                                'Updating status…',
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
                    child: Text(
                      _iapError!,
                      style: TextStyle(color: scheme.onErrorContainer),
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
                                tier.name,
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
                                  'POPULAR',
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            if (isActive)
                              Chip(
                                label: const Text('CURRENT'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tier.price,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.primary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        ...tier.features.map((f) => _BenefitRow(text: f)),
                        if (isUpgrade && tier.id != 'basic') ...[
                          const SizedBox(height: 16),
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
                                    ? 'Opening checkout…'
                                    : 'Upgrade with Card',
                              ),
                            ),
                          ),
                          if (_iapAvailable) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoadingIap
                                    ? null
                                    : _startStoreSubscription,
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
                                  _isLoadingIap ? 'Opening store…' : storeLabel,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Tip: Google Play is best for mobile subscriptions. '
                'Stripe is a flexible fallback and works outside the app store flow.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                              const SnackBar(
                                content: Text(
                                  'Restore complete. Subscription status will update shortly.',
                                ),
                              ),
                            );
                            _autoRefreshEntitlement();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Restore failed: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoadingIap = false);
                          }
                        },
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore Purchases'),
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
  final String name;
  final String price;
  final List<String> features;
  final bool recommended;

  const _SubscriptionTier({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
    this.recommended = false,
  });
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
