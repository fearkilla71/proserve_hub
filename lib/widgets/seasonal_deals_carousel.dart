import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Horizontal carousel showing active seasonal deals & flash offers.
class SeasonalDealsCarousel extends StatelessWidget {
  const SeasonalDealsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('promotions')
          .where('active', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final promos = snap.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: ProServeColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Deals & Offers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ProServeColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'LIMITED TIME',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: ProServeColors.error,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: promos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final data = promos[i].data();
                  return _DealCard(data: data);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DealCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DealCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Special Offer';
    final discount = data['discountPercent'] as num? ?? 0;
    final service = data['service'] as String? ?? '';
    final contractorName = data['contractorName'] as String? ?? '';
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

    final hoursLeft = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inHours
        : 0;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProServeColors.accent.withValues(alpha: 0.12),
            ProServeColors.accent2.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProServeColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (discount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ProServeColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${discount.toInt()}% OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: ProServeColors.accent,
                    ),
                  ),
                ),
              const Spacer(),
              if (hoursLeft > 0 && hoursLeft <= 48)
                Text(
                  '${hoursLeft}h left',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ProServeColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (contractorName.isNotEmpty)
            Text(
              contractorName,
              style: TextStyle(
                fontSize: 11,
                color: ProServeColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (service.isNotEmpty)
            Text(
              service,
              style: TextStyle(fontSize: 10, color: ProServeColors.muted),
            ),
        ],
      ),
    );
  }
}
