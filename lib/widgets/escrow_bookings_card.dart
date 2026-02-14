import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/escrow_booking.dart';
import '../services/escrow_service.dart';
import '../theme/proserve_theme.dart';

/// A compact card that lists active escrow bookings.
///
/// Designed to embed inside the Customer Portal or Contractor Portal.
class EscrowBookingsCard extends StatelessWidget {
  /// Whether to show customer bookings (`true`) or contractor bookings (`false`).
  final bool isCustomer;

  const EscrowBookingsCard({super.key, required this.isCustomer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stream = isCustomer
        ? EscrowService.instance.watchCustomerBookings()
        : EscrowService.instance.watchContractorBookings();

    return StreamBuilder<List<EscrowBooking>>(
      stream: stream,
      builder: (context, snapshot) {
        // Show subtle placeholder while loading to prevent layout jump
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final bookings = snapshot.data ?? [];
        final active = bookings.where((b) => _isActive(b.status)).toList();

        if (active.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: scheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Escrow Bookings',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${active.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...active.map((b) => _bookingTile(context, b, scheme)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bookingTile(
    BuildContext context,
    EscrowBooking booking,
    ColorScheme scheme,
  ) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final statusColor = _statusColor(booking.status, scheme);

    return InkWell(
      onTap: () => context.push('/escrow-status/${booking.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                _statusIcon(booking.status),
                size: 18,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.service,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    booking.statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              fmt.format(booking.aiPrice),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  bool _isActive(EscrowStatus status) {
    return status == EscrowStatus.funded ||
        status == EscrowStatus.customerConfirmed ||
        status == EscrowStatus.contractorConfirmed ||
        status == EscrowStatus.offered;
  }

  Color _statusColor(EscrowStatus status, ColorScheme scheme) {
    switch (status) {
      case EscrowStatus.offered:
        return ProServeColors.warning;
      case EscrowStatus.funded:
        return scheme.primary;
      case EscrowStatus.customerConfirmed:
      case EscrowStatus.contractorConfirmed:
      case EscrowStatus.payoutPending:
        return ProServeColors.accent2;
      case EscrowStatus.released:
        return ProServeColors.success;
      case EscrowStatus.payoutFailed:
      case EscrowStatus.declined:
      case EscrowStatus.cancelled:
        return scheme.error;
    }
  }

  IconData _statusIcon(EscrowStatus status) {
    switch (status) {
      case EscrowStatus.offered:
        return Icons.auto_awesome;
      case EscrowStatus.funded:
        return Icons.account_balance_wallet;
      case EscrowStatus.customerConfirmed:
        return Icons.person_outline;
      case EscrowStatus.contractorConfirmed:
        return Icons.handyman;
      case EscrowStatus.payoutPending:
        return Icons.hourglass_top;
      case EscrowStatus.released:
        return Icons.check_circle;
      case EscrowStatus.payoutFailed:
        return Icons.error_outline;
      case EscrowStatus.declined:
      case EscrowStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}
