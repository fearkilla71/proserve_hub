import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import 'dart:convert';

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

  bool _isProFromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['pricingToolsPro'] == true ||
        data['contractorPro'] == true ||
        data['isPro'] == true;
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

  Future<void> _debugStripeStatus() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'debugContractorProStatus',
      );
      final response = await callable.call(<String, dynamic>{});
      final data = response.data;
      if (!mounted) return;

      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stripe diagnostics'),
          content: SingleChildScrollView(child: SelectableText(pretty)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Diagnostics failed: $e')));
    }
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

  Future<void> _startStripeCheckout() async {
    if (_isLoadingStripe) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoadingStripe = true);

    try {
      await StripeService().payForContractorSubscription();
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
    final storeTitle = _monthlyProduct?.title;
    final storeLabel = _iapAvailable
        ? (storePrice == null
              ? 'Subscribe with Google Play'
              : 'Subscribe with Google Play ($storePrice)')
        : 'Google Play subscription unavailable';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro Subscription'),
        actions: [
          IconButton(
            tooltip: 'Stripe diagnostics',
            icon: const Icon(Icons.bug_report),
            onPressed: _debugStripeStatus,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data();
              final unlocked = _isProFromUserDoc(data);
              if (!unlocked) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _autoRefreshEntitlement();
                });
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Status',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Chip(
                            label: Text(unlocked ? 'Active' : 'Not active'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unlocked
                            ? 'Your Pro tools are unlocked in the app.'
                            : 'After paying, activation is automatic and should update shortly.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (!unlocked) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (_isAutoRefreshing)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            if (_isAutoRefreshing) const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isAutoRefreshing
                                    ? 'Updating status…'
                                    : 'Waiting for Stripe confirmation…',
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
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contractor Pro',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r'$11.99 / month',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unlock the Pricing Calculator and Cost Estimator tools.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const _BenefitRow(text: 'Pricing Calculator'),
                  const _BenefitRow(text: 'Cost Estimator'),
                  if (storeTitle != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      storeTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_iapError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _iapError!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_isLoadingIap || !_iapAvailable)
                          ? null
                          : _startStoreSubscription,
                      icon: _isLoadingIap
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_bag),
                      label: Text(
                        _isLoadingIap ? 'Opening store…' : storeLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingStripe ? null : _startStripeCheckout,
                      icon: _isLoadingStripe
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.credit_card),
                      label: Text(
                        _isLoadingStripe
                            ? 'Opening checkout…'
                            : 'Subscribe with Card (Stripe)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tip: Google Play is best for mobile subscriptions. Stripe is a flexible fallback and works outside the app store flow.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
