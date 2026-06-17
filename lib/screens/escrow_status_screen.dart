import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/escrow_booking.dart';
import '../services/escrow_service.dart';
import '../theme/proserve_theme.dart';

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
    HapticFeedback.mediumImpact();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
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
                  color: ProServeColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_outlined,
                  size: 40,
                  color: ProServeColors.success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.confirmJobCompleteQuestion,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                isCustomer
                    ? l10n.customerConfirmReleaseMessage(
                        _currencyFmt.format(booking.contractorPayout),
                      )
                    : l10n.contractorConfirmReleaseMessage(
                        _currencyFmt.format(booking.contractorPayout),
                      ),
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currencyFmt.format(booking.aiPrice),
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      booking.service,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_circle_outline),
                  style: FilledButton.styleFrom(
                    backgroundColor: ProServeColors.success,
                  ),
                  label: Text(
                    l10n.confirmRelease,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.notYet),
              ),
            ],
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: ProServeColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(l10n.confirmationRecorded),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          action: SnackBarAction(
            label: l10n.retry,
            onPressed: () => _confirmCompletion(booking, isCustomer),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _cancelBooking() async {
    if (_cancelling) return;
    HapticFeedback.mediumImpact();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
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
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: scheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.cancelBookingQuestion,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.cancelBookingRefundWarning,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: scheme.error),
                  child: const Text(
                    'Cancel & Refund',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.keepBooking),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await EscrowService.instance.cancel(widget.escrowId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingCancelledRefunded)));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cancellationFailedTryAgain)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.escrowStatusTitle), centerTitle: true),
      body: StreamBuilder<EscrowBooking?>(
        stream: EscrowService.instance.watchBooking(widget.escrowId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton(Theme.of(context).colorScheme);
          }

          final booking = snapshot.data;
          if (booking == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.bookingNotFound,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.bookingNotFoundSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.goBack),
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
    final isPayoutPending = booking.status == EscrowStatus.payoutPending;
    final isPayoutFailed = booking.status == EscrowStatus.payoutFailed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Status header ──
        _statusHeader(booking, scheme),
        const SizedBox(height: 12),

        _statusMeaningCard(booking, scheme),
        const SizedBox(height: 16),

        // ── Payment summary card ──
        _paymentSummaryCard(booking, scheme),
        const SizedBox(height: 16),

        // ── Timeline ──
        _escrowTimeline(booking, scheme),
        const SizedBox(height: 16),

        // ── How it works ──
        if (!isReleased && !isCancelled && !isPayoutFailed) ...[
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
        ] else if (isPayoutPending) ...[
          _payoutPendingCard(booking, scheme),
        ] else if (isPayoutFailed) ...[
          _payoutFailedCard(booking, scheme),
        ] else if (isReleased) ...[
          _completedCard(booking, scheme),
        ] else if (isCancelled) ...[
          _cancelledCard(booking, scheme),
        ],
      ],
    );
  }

  // ───────────────────── Status Header ──────────────────────

  Widget _statusHeader(EscrowBooking booking, ColorScheme scheme) {
    final isReleased = booking.status == EscrowStatus.released;
    final isCancelled = booking.status == EscrowStatus.cancelled;
    final l10n = AppLocalizations.of(context)!;

    final Color statusColor;
    final IconData statusIcon;
    if (isReleased) {
      statusColor = ProServeColors.success;
      statusIcon = Icons.check_circle;
    } else if (isCancelled) {
      statusColor = scheme.error;
      statusIcon = Icons.cancel;
    } else if (booking.status == EscrowStatus.payoutFailed) {
      statusColor = scheme.error;
      statusIcon = Icons.warning_amber_rounded;
    } else if (booking.status == EscrowStatus.payoutPending) {
      statusColor = ProServeColors.warning;
      statusIcon = Icons.pending_actions_outlined;
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
            _localizedEscrowStatus(booking.status, l10n),
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

  Widget _statusMeaningCard(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final status = _statusMessage(booking, l10n);
    return Card(
      elevation: 0,
      color: status.color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: status.color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: status.color.withValues(alpha: 0.14),
              child: Icon(status.icon, color: status.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: status.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(status.body),
                  const SizedBox(height: 10),
                  Text(
                    status.next,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EscrowStatusMessage _statusMessage(
    EscrowBooking booking,
    AppLocalizations l10n,
  ) {
    final payout = _currencyFmt.format(booking.contractorPayout);
    switch (booking.status) {
      case EscrowStatus.offered:
        return _EscrowStatusMessage(
          icon: Icons.price_check_outlined,
          color: Theme.of(context).colorScheme.primary,
          title: l10n.escrowMeaningOfferedTitle,
          body: l10n.escrowMeaningOfferedBody,
          next: l10n.escrowMeaningOfferedNext,
        );
      case EscrowStatus.funded:
        return _EscrowStatusMessage(
          icon: Icons.shield_outlined,
          color: Theme.of(context).colorScheme.primary,
          title: l10n.escrowMeaningFundedTitle,
          body: l10n.escrowMeaningFundedBody,
          next: l10n.escrowMeaningFundedNext,
        );
      case EscrowStatus.customerConfirmed:
        return _EscrowStatusMessage(
          icon: Icons.person_outline,
          color: ProServeColors.warning,
          title: l10n.escrowMeaningCustomerConfirmedTitle,
          body: l10n.escrowMeaningCustomerConfirmedBody,
          next: l10n.escrowMeaningCustomerConfirmedNext,
        );
      case EscrowStatus.contractorConfirmed:
        return _EscrowStatusMessage(
          icon: Icons.handyman_outlined,
          color: ProServeColors.warning,
          title: l10n.escrowMeaningContractorConfirmedTitle,
          body: l10n.escrowMeaningContractorConfirmedBody,
          next: l10n.escrowMeaningContractorConfirmedNext,
        );
      case EscrowStatus.payoutPending:
        return _EscrowStatusMessage(
          icon: Icons.pending_actions_outlined,
          color: ProServeColors.warning,
          title: l10n.escrowMeaningPayoutPendingTitle,
          body: l10n.escrowMeaningPayoutPendingBody(payout),
          next: l10n.escrowMeaningPayoutPendingNext,
        );
      case EscrowStatus.released:
        return _EscrowStatusMessage(
          icon: Icons.check_circle_outline,
          color: ProServeColors.success,
          title: l10n.escrowMeaningReleasedTitle,
          body: l10n.escrowMeaningReleasedBody(payout),
          next: l10n.escrowMeaningReleasedNext,
        );
      case EscrowStatus.payoutFailed:
        return _EscrowStatusMessage(
          icon: Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          title: l10n.escrowMeaningPayoutFailedTitle,
          body: l10n.escrowMeaningPayoutFailedBody,
          next: l10n.escrowMeaningPayoutFailedNext,
        );
      case EscrowStatus.declined:
        return _EscrowStatusMessage(
          icon: Icons.block_outlined,
          color: Theme.of(context).colorScheme.error,
          title: l10n.escrowMeaningDeclinedTitle,
          body: l10n.escrowMeaningDeclinedBody,
          next: l10n.escrowMeaningDeclinedNext,
        );
      case EscrowStatus.cancelled:
        return _EscrowStatusMessage(
          icon: Icons.undo_outlined,
          color: Theme.of(context).colorScheme.error,
          title: l10n.escrowMeaningCancelledTitle,
          body: (booking.refundStatus ?? '').isNotEmpty
              ? l10n.escrowMeaningCancelledRefundBody(booking.refundStatus!)
              : l10n.escrowMeaningCancelledBody,
          next: l10n.escrowMeaningCancelledNext,
        );
    }
  }

  String _localizedEscrowStatus(EscrowStatus status, AppLocalizations l10n) {
    switch (status) {
      case EscrowStatus.offered:
        return l10n.priceOffered;
      case EscrowStatus.funded:
        return l10n.paymentHeldInEscrow;
      case EscrowStatus.customerConfirmed:
        return l10n.customerConfirmed;
      case EscrowStatus.contractorConfirmed:
        return l10n.contractorConfirmed;
      case EscrowStatus.payoutPending:
        return l10n.payoutProcessing;
      case EscrowStatus.released:
        return l10n.fundsReleased;
      case EscrowStatus.payoutFailed:
        return l10n.payoutFailed;
      case EscrowStatus.declined:
        return l10n.declined;
      case EscrowStatus.cancelled:
        return l10n.cancelled;
    }
  }

  // ───────────────────── Payment Summary ────────────────────

  Widget _paymentSummaryCard(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.paymentSummary,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _summaryRow(l10n.totalPaid, _currencyFmt.format(booking.aiPrice)),
            _summaryRow(
              l10n.platformFeePercent,
              _currencyFmt.format(booking.platformFee),
            ),
            const Divider(height: 16),
            _summaryRow(
              l10n.contractorPayout,
              _currencyFmt.format(booking.contractorPayout),
              bold: true,
            ),
            if ((booking.payoutStatus ?? '').isNotEmpty)
              _summaryRow(l10n.payoutStatus, booking.payoutStatus!),
            if ((booking.refundStatus ?? '').isNotEmpty)
              _summaryRow(l10n.refundStatus, booking.refundStatus!),
            if ((booking.stripeTransferId ?? '').isNotEmpty)
              _summaryRow(l10n.stripeTransfer, booking.stripeTransferId!),
            if ((booking.stripeRefundId ?? '').isNotEmpty)
              _summaryRow(l10n.stripeRefund, booking.stripeRefundId!),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Timeline ────────────────────────────

  Widget _escrowTimeline(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: l10n.aiPriceOffered,
        subtitle: _formatDate(booking.createdAt),
        done: true,
        icon: Icons.auto_awesome,
      ),
      _TimelineStep(
        title: l10n.paymentFunded,
        subtitle: booking.fundedAt != null
            ? _formatDate(booking.fundedAt!)
            : l10n.awaitingPayment,
        done: booking.fundedAt != null,
        icon: Icons.account_balance_wallet,
      ),
      _TimelineStep(
        title: l10n.customerConfirmed,
        subtitle: booking.customerConfirmedAt != null
            ? _formatDate(booking.customerConfirmedAt!)
            : l10n.pending,
        done: booking.customerConfirmedAt != null,
        icon: Icons.person_outline,
      ),
      _TimelineStep(
        title: l10n.contractorConfirmed,
        subtitle: booking.contractorConfirmedAt != null
            ? _formatDate(booking.contractorConfirmedAt!)
            : l10n.pending,
        done: booking.contractorConfirmedAt != null,
        icon: Icons.handyman,
      ),
      _TimelineStep(
        title: l10n.fundsReleased,
        subtitle: booking.releasedAt != null
            ? _formatDate(booking.releasedAt!)
            : l10n.afterBothConfirm,
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
              l10n.escrowTimeline,
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
    final doneColor = ProServeColors.success;
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(Icons.info_outline, color: scheme.primary, size: 20),
        title: Text(
          l10n.howEscrowWorks,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        children: [
          _howStep('1', l10n.howEscrowStepOne),
          _howStep('2', l10n.howEscrowStepTwo),
          _howStep('3', l10n.howEscrowStepThree),
          _howStep('4', l10n.howEscrowStepFour),
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
    final l10n = AppLocalizations.of(context)!;
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
            label: Text(
              l10n.confirmJobComplete,
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
              _cancelling ? l10n.cancelling : l10n.cancelBooking,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _customerConfirmButton(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ProServeColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: ProServeColors.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.contractorConfirmedPleaseRelease,
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
            label: Text(
              l10n.confirmReleasePayment,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waitingForContractorCard(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.waitingForContractor,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.waitingForContractorSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProServeColors.success.withValues(alpha: 0.12),
            ProServeColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ProServeColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.celebration,
            size: 40,
            color: ProServeColors.success,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.jobCompleteExclamation,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: ProServeColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.releasedToContractor(
              _currencyFmt.format(booking.contractorPayout),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // ── Rate your experience (post-job rating) ──
          if (!booking.hasRating) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => context.push('/escrow-rating/${booking.id}'),
                icon: const Icon(Icons.star_outline),
                label: Text(
                  l10n.rateAiPrice,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.rateAiPriceSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ProServeColors.accent2.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(
                    booking.priceFairnessRating ?? 0,
                    (_) => const Icon(
                      Icons.star,
                      size: 18,
                      color: ProServeColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.youRatedThisPrice,
                    style: TextStyle(
                      color: ProServeColors.accent2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            label: Text(l10n.backToHome),
          ),
        ],
      ),
    );
  }

  Widget _payoutPendingCard(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.pending_actions_outlined,
              size: 40,
              color: ProServeColors.warning,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.payoutProcessing,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: ProServeColors.warning,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.payoutProcessingMessage(
                _currencyFmt.format(booking.contractorPayout),
              ),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payoutFailedCard(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.32),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 40, color: scheme.error),
            const SizedBox(height: 10),
            Text(
              l10n.payoutNeedsAdminReview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.payoutNeedsAdminReviewMessage,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
            if ((booking.payoutError ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                booking.payoutError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cancelledCard(EscrowBooking booking, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.bookingCancelled,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (booking.refundStatus ?? '').isNotEmpty
                ? l10n.refundStatusValue(booking.refundStatus!)
                : l10n.paymentRefunded,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
            label: Text(l10n.backToHome),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  Widget _buildLoadingSkeleton(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Status header skeleton
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Payment summary skeleton
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        // Timeline skeleton
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
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

class _EscrowStatusMessage {
  const _EscrowStatusMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.next,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String next;
}
