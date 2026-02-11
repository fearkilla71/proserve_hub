import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../theme/proserve_theme.dart';

import '../services/ai_pricing_service.dart';
import '../services/escrow_service.dart';
import '../services/escrow_stats_service.dart';
import '../widgets/price_lock_timer.dart';
import '../widgets/savings_comparison.dart';
import '../widgets/social_proof_banner.dart';

/// Shown after a job request is submitted.
///
/// Displays the AI-generated price with a breakdown and gives the customer
/// two choices:
///   1. **Accept & Pay** → funds go into escrow
///   2. **Get Contractor Estimates** → traditional flow (recommended page)
class AiPriceOfferScreen extends StatefulWidget {
  final String jobId;
  final String service;
  final String zip;
  final double quantity;
  final bool urgent;
  final Map<String, dynamic> jobDetails;

  const AiPriceOfferScreen({
    super.key,
    required this.jobId,
    required this.service,
    required this.zip,
    required this.quantity,
    this.urgent = false,
    this.jobDetails = const {},
  });

  @override
  State<AiPriceOfferScreen> createState() => _AiPriceOfferScreenState();
}

class _AiPriceOfferScreenState extends State<AiPriceOfferScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _accepting = false;
  String? _error;
  Map<String, dynamic>? _pricing;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _generatePrice();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePrice() async {
    try {
      // Get loyalty discount based on customer's escrow streak
      double loyaltyDiscount = 0.0;
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          loyaltyDiscount = await EscrowStatsService().getLoyaltyDiscount(uid);
        }
      } catch (_) {}

      final pricing = await AiPricingService.instance.generatePrice(
        service: widget.service,
        quantity: widget.quantity,
        zip: widget.zip,
        urgent: widget.urgent,
        jobDetails: widget.jobDetails,
        loyaltyDiscount: loyaltyDiscount,
      );
      if (mounted) {
        setState(() {
          _pricing = pricing;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _acceptPrice() async {
    if (_pricing == null || _accepting) return;
    HapticFeedback.heavyImpact();
    setState(() => _accepting = true);

    try {
      final aiPrice = (_pricing!['aiPrice'] as num).toDouble();
      final priceLockExpiry = DateTime.now().add(const Duration(hours: 24));
      final escrowId = await EscrowService.instance.createOffer(
        jobId: widget.jobId,
        service: widget.service,
        zip: widget.zip,
        aiPrice: aiPrice,
        priceBreakdown: {
          'low': (_pricing!['low'] as num).toDouble(),
          'recommended': (_pricing!['recommended'] as num).toDouble(),
          'premium': (_pricing!['premium'] as num).toDouble(),
        },
        jobDetails: widget.jobDetails,
        priceLockExpiry: priceLockExpiry,
        estimatedMarketPrice: (_pricing!['estimatedMarketPrice'] as num?)
            ?.toDouble(),
        savingsAmount: (_pricing!['savingsAmount'] as num?)?.toDouble(),
        savingsPercent: (_pricing!['savingsPercent'] as num?)?.toDouble(),
        discountPercent: (_pricing!['discountPercent'] as num?)?.toDouble(),
        originalAiPrice: (_pricing!['originalAiPrice'] as num?)?.toDouble(),
      );

      // Simulate payment (in production → Stripe checkout)
      await EscrowService.instance.acceptAndFund(escrowId: escrowId);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.pushReplacement('/escrow-status/$escrowId');
    } catch (e) {
      if (!mounted) return;
      _showPaymentError(e);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _showPaymentError(Object error) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payment, size: 40, color: scheme.error),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Failed',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t process your payment. Please check your payment method and try again.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _acceptPrice();
                  },
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _getEstimatesInstead() {
    context.push('/recommended/${widget.jobId}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Instant Price'), centerTitle: true),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        child: _loading
            ? _buildLoadingState(scheme)
            : _error != null
            ? _buildErrorState(scheme)
            : _buildPriceOffer(scheme),
      ),
    );
  }

  // ───────────────────────────── Loading State ─────────────────────────

  Widget _buildLoadingState(ColorScheme scheme) {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your job...',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI is crunching market data, job complexity,\nand local pricing to find you the best deal.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── Error State ───────────────────────────

  Widget _buildErrorState(ColorScheme scheme) {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Pricing Unavailable',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _getEstimatesInstead,
              icon: const Icon(Icons.people_outline),
              label: const Text('Get Contractor Estimates'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── Price Offer ───────────────────────────

  Widget _buildPriceOffer(ColorScheme scheme) {
    final aiPrice = (_pricing!['aiPrice'] as num).toDouble();
    final platformFee = (_pricing!['platformFee'] as num).toDouble();
    final contractorPayout = (_pricing!['contractorPayout'] as num).toDouble();
    final low = (_pricing!['low'] as num).toDouble();
    final premium = (_pricing!['premium'] as num).toDouble();
    final confidence = (_pricing!['confidence'] as num).toDouble();
    final factors = (_pricing!['factors'] as List<dynamic>?) ?? [];

    // New savings / discount fields
    final estimatedMarketPrice =
        (_pricing!['estimatedMarketPrice'] as num?)?.toDouble() ?? 0;
    final savingsAmount = (_pricing!['savingsAmount'] as num?)?.toDouble() ?? 0;
    final savingsPercent =
        (_pricing!['savingsPercent'] as num?)?.toDouble() ?? 0;
    final discountPercent = (_pricing!['discountPercent'] as num?)?.toDouble();
    final originalAiPrice = (_pricing!['originalAiPrice'] as num?)?.toDouble();
    final priceLockExpiry = DateTime.now().add(const Duration(hours: 24));

    return ListView(
      key: const ValueKey('offer'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── AI badge ──
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.15),
                  scheme.tertiary.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'AI-Powered Fair Market Price',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Savings comparison (shows how much cheaper than contractor) ──
        if (estimatedMarketPrice > 0)
          SavingsComparison(
            aiPrice: aiPrice,
            estimatedMarketPrice: estimatedMarketPrice,
            savingsAmount: savingsAmount,
            savingsPercent: savingsPercent,
            discountPercent: discountPercent,
            originalAiPrice: originalAiPrice,
          ),

        const SizedBox(height: 16),

        // ── Price lock timer (24hr countdown) ──
        PriceLockTimer(
          expiresAt: priceLockExpiry,
          onExpired: () {
            if (mounted) setState(() {});
          },
        ),

        const SizedBox(height: 16),

        // ── Main price card ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.4),
                scheme.tertiaryContainer.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                widget.service,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFmt.format(aiPrice),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recommended Price',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Price range bar
              _priceRangeBar(scheme, low, aiPrice, premium),

              const SizedBox(height: 16),

              // Confidence meter
              _confidenceMeter(scheme, confidence),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Price breakdown ──
        Card(
          elevation: 0,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price Breakdown',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _breakdownRow(
                  'Job Total',
                  _currencyFmt.format(aiPrice),
                  scheme.onSurface,
                ),
                _breakdownRow(
                  'Platform Fee (5%)',
                  '−${_currencyFmt.format(platformFee)}',
                  scheme.error,
                ),
                const Divider(height: 20),
                _breakdownRow(
                  'Contractor Receives',
                  _currencyFmt.format(contractorPayout),
                  scheme.primary,
                  bold: true,
                ),
              ],
            ),
          ),
        ),

        // ── Factors ──
        if (factors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'How we calculated this',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...factors.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Social proof banner ──
        const SocialProofBanner(),

        const SizedBox(height: 16),

        // ── Satisfaction guarantee ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ProServeColors.success.withValues(alpha: 0.08),
                ProServeColors.accent2.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ProServeColors.success.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ProServeColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.verified_user,
                      color: ProServeColors.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ProServe Guarantee',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Not satisfied? Your payment stays in escrow until you confirm the job is done right.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _GuaranteePill(
                    icon: Icons.shield_outlined,
                    label: 'Secure Escrow',
                  ),
                  const SizedBox(width: 8),
                  _GuaranteePill(icon: Icons.undo, label: 'Full Refund'),
                  const SizedBox(width: 8),
                  _GuaranteePill(
                    icon: Icons.support_agent,
                    label: '24/7 Support',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Accept button ──
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _accepting ? null : _acceptPrice,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _accepting
                  ? const SizedBox(
                      key: ValueKey('spinner'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt, key: ValueKey('icon')),
            ),
            label: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _accepting
                    ? 'Processing...'
                    : 'Accept & Pay ${_currencyFmt.format(aiPrice)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Decline / get estimates ──
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _accepting ? null : _getEstimatesInstead,
            icon: const Icon(Icons.people_outline),
            label: const Text(
              'Get Contractor Estimates Instead',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Center(
          child: Text(
            'No charge — contractors will contact you with quotes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────── Price Range Bar ─────────────────────

  Widget _priceRangeBar(
    ColorScheme scheme,
    double low,
    double recommended,
    double premium,
  ) {
    final range = premium - low;
    final position = range > 0 ? (recommended - low) / range : 0.5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _currencyFmt.format(low),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _currencyFmt.format(premium),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final dotX = totalWidth * position.clamp(0.05, 0.95);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [
                            ProServeColors.success,
                            scheme.primary,
                            ProServeColors.warning,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: dotX - 8,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text(
              'Premium',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────── Confidence Meter ────────────────────

  Widget _confidenceMeter(ColorScheme scheme, double confidence) {
    final pct = (confidence * 100).round();
    final label = pct >= 80
        ? 'High confidence'
        : pct >= 60
        ? 'Good confidence'
        : 'Moderate confidence';
    final color = pct >= 80
        ? ProServeColors.success
        : pct >= 60
        ? scheme.primary
        : ProServeColors.warning;

    return Row(
      children: [
        Icon(Icons.insights, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$label ($pct%)',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 60,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: scheme.surfaceContainerHighest,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────── Breakdown Row ───────────────────────

  Widget _breakdownRow(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuaranteePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GuaranteePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: ProServeColors.success, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
