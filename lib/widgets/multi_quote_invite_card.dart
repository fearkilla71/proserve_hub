import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Multi-contractor auto-invite card with 24hr countdown.
///
/// Shows top 3 matched contractors and a countdown timer for responses.
class MultiQuoteInviteCard extends StatelessWidget {
  final String jobId;
  final int candidateCount;
  final DateTime? expiresAt;

  const MultiQuoteInviteCard({
    super.key,
    required this.jobId,
    this.candidateCount = 3,
    this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProServeColors.accent2.withValues(alpha: 0.08),
            ProServeColors.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ProServeColors.accent2.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ProServeColors.accent2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.groups,
                  color: ProServeColors.accent2,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Getting $candidateCount Quotes for You',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Contractor avatars stream
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('job_matches')
                .doc(jobId)
                .collection('candidates')
                .orderBy('totalScore', descending: true)
                .limit(candidateCount)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Row(
                  children: List.generate(
                    candidateCount,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: ProServeColors.card,
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: ProServeColors.muted,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final candidates = snap.data!.docs;
              return Row(
                children: [
                  // Avatar stack
                  SizedBox(
                    width: 50.0 + (candidates.length - 1) * 20,
                    height: 40,
                    child: Stack(
                      children: candidates.asMap().entries.map((entry) {
                        final i = entry.key;
                        final data = entry.value.data();
                        final name =
                            data['contractorName'] as String? ?? '?';

                        return Positioned(
                          left: i * 20.0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: [
                              ProServeColors.accent,
                              ProServeColors.accent2,
                              ProServeColors.accent3,
                            ][i % 3],
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${candidates.length} pros invited',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ProServeColors.muted,
                    ),
                  ),
                ],
              );
            },
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 10),
            _CountdownBar(expiresAt: expiresAt!),
          ],
        ],
      ),
    );
  }
}

class _CountdownBar extends StatefulWidget {
  final DateTime expiresAt;

  const _CountdownBar({required this.expiresAt});

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(
      const Duration(seconds: 60),
      (i) => i,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, _) {
        final remaining = widget.expiresAt.difference(DateTime.now());
        if (remaining.isNegative) {
          return Text(
            'Quote window closed',
            style: TextStyle(
              fontSize: 11,
              color: ProServeColors.error,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        final totalHours = 24;
        final elapsed = totalHours - hours;
        final progress =
            (elapsed / totalHours).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: ProServeColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  '${hours}h ${minutes}m remaining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ProServeColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: ProServeColors.line,
                color: hours <= 4
                    ? ProServeColors.error
                    : ProServeColors.warning,
              ),
            ),
          ],
        );
      },
    );
  }
}
