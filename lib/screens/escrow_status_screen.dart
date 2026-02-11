import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/escrow_booking.dart';
import '../services/escrow_service.dart';

/// Real-time escrow status tracker.
///
/// Shows a visual timeline of the escrow lifecycle and allows each party
/// to confirm job completion.
class EscrowStatusScreen extends StatefulWidget {
  final String escrowId;

  const EscrowStatusScreen({super.key, required this.escrowId});

  @override
  State<EscrowStatusScreen> createState() => _EscrowStatusScreenState();
}

class _EscrowStatusScreenState extends State<EscrowStatusScreen> {
  final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  bool _confirming = false;
  bool _cancelling = false;

  Future<void> _confirmCompletion(
    EscrowBooking booking,
    bool isCustomer,
  ) async {
    if (_confirming) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Job Complete?'),
        content: Text(
          isCustomer
              ? 'By confirming, you verify the work was completed satisfactorily. '
                    'Once the contractor also confirms, funds will be released.'
              : 'By confirming, you verify the job has been completed. '
                    'Once the customer also confirms, your payment will be released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Job is Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      if (isCustomer) {
        await EscrowService.instance.customerConfirm(widget.escrowId);
      } else {
        await EscrowService.instance.contractorConfirm(widget.escrowId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Confirmation recorded!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _cancelBooking() async {
    if (_cancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text(
          'This will cancel the escrow booking and refund the payment. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await EscrowService.instance.cancel(widget.escrowId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled & refunded.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escrow Status'), centerTitle: true),
      body: StreamBuilder<EscrowBooking?>(
        stream: EscrowService.instance.watchBooking(widget.escrowId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final booking = snapshot.data;
          if (booking == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Booking not found.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return _buildContent(booking);
        },
      ),
    );
  }

  Widget _buildContent(EscrowBooking booking) {
    final scheme = Theme.of(context).colorScheme;
    final isReleased = booking.status == EscrowStatus.released;
    final isCancelled = booking.status == EscrowStatus.cancelled;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Status header ──
        _statusHeader(booking, scheme),
        const SizedBox(height: 20),

        // ── Payment summary card ──
        _paymentSummaryCard(booking, scheme),
        const SizedBox(height: 16),

        // ── Timeline ──
        _escrowTimeline(booking, scheme),
        const SizedBox(height: 16),

        // ── How it works ──
        if (!isReleased && !isCancelled) ...[
          _howItWorksCard(scheme),
          const SizedBox(height: 16),
        ],

        // ── Action buttons ──
        if (booking.status == EscrowStatus.funded) ...[
          _actionButtons(booking, scheme),
        ] else if (booking.status == EscrowStatus.customerConfirmed) ...[
          _waitingForContractorCard(scheme),
        ] else if (booking.status == EscrowStatus.contractorConfirmed) ...[
          _customerConfirmButton(booking, scheme),
        ] else if (isReleased) ...[
          _completedCard(booking, scheme),
        ] else if (isCancelled) ...[
          _cancelledCard(scheme),
        ],
      ],
    );
  }

  // ───────────────────── Status Header ──────────────────────

  Widget _statusHeader(EscrowBooking booking, ColorScheme scheme) {
    final isReleased = booking.status == EscrowStatus.released;
    final isCancelled = booking.status == EscrowStatus.cancelled;

    final Color statusColor;
    final IconData statusIcon;
    if (isReleased) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isCancelled) {
      statusColor = scheme.error;
      statusIcon = Icons.cancel;
    } else {
      statusColor = scheme.primary;
      statusIcon = Icons.hourglass_top;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.12),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: statusColor),
          const SizedBox(height: 10),
          Text(
            booking.statusLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            booking.service,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            _currencyFmt.format(booking.aiPrice),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Payment Summary ────────────────────

  Widget _paymentSummaryCard(EscrowBooking booking, ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Summary',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _summaryRow('Total Paid', _currencyFmt.format(booking.aiPrice)),
            _summaryRow(
              'Platform Fee (5%)',
              _currencyFmt.format(booking.platformFee),
            ),
            const Divider(height: 16),
            _summaryRow(
              'Contractor Payout',
              _currencyFmt.format(booking.contractorPayout),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Timeline ────────────────────────────

  Widget _escrowTimeline(EscrowBooking booking, ColorScheme scheme) {
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'AI Price Offered',
        subtitle: _formatDate(booking.createdAt),
        done: true,
        icon: Icons.auto_awesome,
      ),
      _TimelineStep(
        title: 'Payment Funded',
        subtitle: booking.fundedAt != null
            ? _formatDate(booking.fundedAt!)
            : 'Awaiting payment',
        done: booking.fundedAt != null,
        icon: Icons.account_balance_wallet,
      ),
      _TimelineStep(
        title: 'Customer Confirmed',
        subtitle: booking.customerConfirmedAt != null
            ? _formatDate(booking.customerConfirmedAt!)
            : 'Pending',
        done: booking.customerConfirmedAt != null,
        icon: Icons.person_outline,
      ),
      _TimelineStep(
        title: 'Contractor Confirmed',
        subtitle: booking.contractorConfirmedAt != null
            ? _formatDate(booking.contractorConfirmedAt!)
            : 'Pending',
        done: booking.contractorConfirmedAt != null,
        icon: Icons.handyman,
      ),
      _TimelineStep(
        title: 'Funds Released',
        subtitle: booking.releasedAt != null
            ? _formatDate(booking.releasedAt!)
            : 'After both confirm',
        done: booking.releasedAt != null,
        icon: Icons.payments_outlined,
      ),
    ];

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escrow Timeline',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...List.generate(steps.length, (i) {
              final step = steps[i];
              final isLast = i == steps.length - 1;
              return _timelineItem(step, isLast, scheme);
            }),
          ],
        ),
      ),
    );
  }

  Widget _timelineItem(_TimelineStep step, bool isLast, ColorScheme scheme) {
    final doneColor = Colors.green;
    final pendingColor = scheme.outlineVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: dot + line
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: step.done
                      ? doneColor.withValues(alpha: 0.15)
                      : pendingColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.done ? Icons.check : step.icon,
                  size: 16,
                  color: step.done ? doneColor : pendingColor,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 32,
                  color: step.done ? doneColor : pendingColor,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Right column: text
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: step.done ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                    color: step.done ? null : scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────── How It Works ────────────────────────

  Widget _howItWorksCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(Icons.info_outline, color: scheme.primary, size: 20),
        title: Text(
          'How Escrow Works',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        children: [
          _howStep('1', 'You pay the AI price — funds are held securely.'),
          _howStep('2', 'A contractor claims your job and completes the work.'),
          _howStep('3', 'Both you and the contractor confirm completion.'),
          _howStep('4', 'Funds are released to the contractor (minus 5% fee).'),
        ],
      ),
    );
  }

  Widget _howStep(String number, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Action Buttons ──────────────────────

  Widget _actionButtons(EscrowBooking booking, ColorScheme scheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _confirming
                ? null
                : () => _confirmCompletion(booking, true),
            icon: _confirming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text(
              'Confirm Job Complete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: _cancelling ? null : _cancelBooking,
            child: Text(
              _cancelling ? 'Cancelling...' : 'Cancel Booking',
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _customerConfirmButton(EscrowBooking booking, ColorScheme scheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The contractor has confirmed. Please confirm to release payment.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _confirming
                ? null
                : () => _confirmCompletion(booking, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text(
              'Confirm & Release Payment',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waitingForContractorCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for Contractor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'You\'ve confirmed completion. Once the contractor also confirms, funds will be released.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedCard(EscrowBooking booking, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.12),
            Colors.green.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration, size: 40, color: Colors.green),
          const SizedBox(height: 10),
          Text(
            'Job Complete!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_currencyFmt.format(booking.contractorPayout)} released to contractor.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _cancelledCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.cancel_outlined, size: 40, color: scheme.error),
          const SizedBox(height: 10),
          Text(
            'Booking Cancelled',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your payment has been refunded.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool done;
  final IconData icon;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.icon,
  });
}
