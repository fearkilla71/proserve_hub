import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/loyalty_service.dart';

/// Loyalty & Rewards screen for homeowners.
/// Shows points balance, earn history, available rewards, and redeem flow.
class LoyaltyRewardsScreen extends StatefulWidget {
  const LoyaltyRewardsScreen({super.key});

  @override
  State<LoyaltyRewardsScreen> createState() => _LoyaltyRewardsScreenState();
}

class _LoyaltyRewardsScreenState extends State<LoyaltyRewardsScreen> {
  Map<String, int>? _points;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final pts = await LoyaltyService.instance.getPoints(uid);
    if (!mounted) {
      return;
    }
    setState(() {
      _points = pts;
      _loading = false;
    });
  }

  Future<void> _redeem(Map<String, dynamic> reward) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final pts = reward['points'] as int;
    final label = reward['label'] as String;
    final current = _points?['current'] ?? 0;

    if (current < pts) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough points')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem Reward'),
        content: Text('Spend $pts points for "$label"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    final success = await LoyaltyService.instance.redeemPoints(
      userId: uid,
      points: pts,
      rewardLabel: label,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('🎉 Redeemed: $label')));
      _loadPoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty & Rewards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Points balance card ──
                _PointsBalanceCard(
                  current: _points?['current'] ?? 0,
                  totalEarned: _points?['totalEarned'] ?? 0,
                  redeemed: _points?['redeemed'] ?? 0,
                  scheme: scheme,
                ),

                const SizedBox(height: 20),

                // ── How to earn ──
                Text(
                  'How to Earn Points',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _EarnRow(
                  icon: Icons.handshake,
                  label: 'Book a job',
                  pts: pointsPerJobBooked,
                ),
                _EarnRow(
                  icon: Icons.star,
                  label: 'Leave a review',
                  pts: pointsPerReviewLeft,
                ),
                _EarnRow(
                  icon: Icons.card_giftcard,
                  label: 'Refer a friend',
                  pts: pointsPerReferral,
                ),
                _EarnRow(
                  icon: Icons.repeat,
                  label: 'Repeat booking (same pro)',
                  pts: pointsPerRepeatBooking,
                ),

                const SizedBox(height: 24),

                // ── Available rewards ──
                Text(
                  'Available Rewards',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...rewardTiers.map((r) {
                  final canRedeem =
                      (_points?['current'] ?? 0) >= (r['points'] as int);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: canRedeem
                            ? Colors.green.withValues(alpha: .15)
                            : scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.redeem,
                          color: canRedeem
                              ? Colors.green
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        r['label'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${r['points']} points'),
                      trailing: FilledButton(
                        onPressed: canRedeem ? () => _redeem(r) : null,
                        child: const Text('Redeem'),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // ── Recent activity ──
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: LoyaltyService.instance.watchEvents(uid),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No activity yet. Book a job to start earning!',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data();
                        final pts = (d['points'] as num?)?.toInt() ?? 0;
                        final isEarn = pts > 0;
                        final desc = d['description'] ?? '';
                        final ts = d['createdAt'] as Timestamp?;
                        return ListTile(
                          leading: Icon(
                            isEarn ? Icons.add_circle : Icons.remove_circle,
                            color: isEarn ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            desc,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: ts != null
                              ? Text(DateFormat('MMM d, y').format(ts.toDate()))
                              : null,
                          trailing: Text(
                            '${isEarn ? '+' : ''}$pts pts',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isEarn ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _PointsBalanceCard extends StatelessWidget {
  final int current;
  final int totalEarned;
  final int redeemed;
  final ColorScheme scheme;
  const _PointsBalanceCard({
    required this.current,
    required this.totalEarned,
    required this.redeemed,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A0E3A), scheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'Loyalty Points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: .8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat('#,###').format(current),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'available points',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: .6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(
                label: 'Total earned',
                value: NumberFormat('#,###').format(totalEarned),
              ),
              const SizedBox(width: 24),
              _MiniStat(
                label: 'Redeemed',
                value: NumberFormat('#,###').format(redeemed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: .5),
          ),
        ),
      ],
    );
  }
}

class _EarnRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int pts;
  const _EarnRow({required this.icon, required this.label, required this.pts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$pts pts',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
