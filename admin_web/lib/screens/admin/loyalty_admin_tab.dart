import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Loyalty Program Admin — Award / revoke points, view loyalty_events,
/// audit redemptions, and configure tier thresholds.
/// ---------------------------------------------------------------------------
class LoyaltyAdminTab extends StatefulWidget {
  final bool canWrite;
  const LoyaltyAdminTab({super.key, this.canWrite = false});

  @override
  State<LoyaltyAdminTab> createState() => _LoyaltyAdminTabState();
}

class _LoyaltyAdminTabState extends State<LoyaltyAdminTab> {
  StreamSubscription? _eventsSub;
  StreamSubscription? _usersSub;
  bool _loading = true;
  String _filter = 'all'; // all, earn, redeem
  String _search = '';

  List<Map<String, dynamic>> _events = [];
  // ignore: unused_field – kept for future CRM cross-reference
  List<Map<String, dynamic>> _users = [];

  // KPIs
  int _totalPointsIssued = 0;
  int _totalPointsRedeemed = 0;
  int _activeMembers = 0;
  int _totalEvents = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _usersSub?.cancel();
    super.dispose();
  }

  void _listen() {
    _eventsSub = FirebaseFirestore.instance
        .collection('loyalty_events')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();

          int issued = 0, redeemed = 0;
          for (final e in docs) {
            final pts = (e['points'] as num?)?.toInt() ?? 0;
            if (e['type'] == 'redeem') {
              redeemed += pts;
            } else {
              issued += pts;
            }
          }

          setState(() {
            _events = docs;
            _totalPointsIssued = issued;
            _totalPointsRedeemed = redeemed;
            _totalEvents = docs.length;
            _loading = false;
          });
        });

    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .snapshots()
        .listen((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data();
            data['uid'] = d.id;
            return data;
          }).toList();

          int active = 0;
          for (final u in docs) {
            if ((u['loyaltyPoints'] as num?)?.toInt() != null &&
                (u['loyaltyPoints'] as num).toInt() > 0) {
              active++;
            }
          }

          setState(() {
            _users = docs;
            _activeMembers = active;
          });
        });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _events;
    if (_filter != 'all') {
      list = list.where((e) => e['type'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) {
        final uid = (e['uid'] ?? '').toString().toLowerCase();
        final action = (e['action'] ?? '').toString().toLowerCase();
        return uid.contains(q) || action.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // KPIs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpi(
                'Issued',
                NumberFormat.compact().format(_totalPointsIssued),
                AdminColors.accent,
              ),
              _kpi(
                'Redeemed',
                NumberFormat.compact().format(_totalPointsRedeemed),
                AdminColors.accent3,
              ),
              _kpi('Active Members', '$_activeMembers', AdminColors.accent2),
              _kpi('Events', '$_totalEvents', AdminColors.muted),
            ],
          ),
        ),
        const Divider(color: AdminColors.line, height: 1),

        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'earn', label: Text('Earned')),
                  ButtonSegment(value: 'redeem', label: Text('Redeemed')),
                ],
                selected: {_filter},
                onSelectionChanged: (v) => setState(() => _filter = v.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by UID or action…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.canWrite)
                FilledButton.icon(
                  onPressed: () => _showAwardDialog(context),
                  icon: const Icon(Icons.card_giftcard, size: 18),
                  label: const Text('Award Points'),
                ),
            ],
          ),
        ),

        // Events list
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No events',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => _EventRow(data: _filtered[i]),
                ),
        ),
      ],
    );
  }

  // ── Award dialog ──

  void _showAwardDialog(BuildContext context) {
    final uidCtrl = TextEditingController();
    final ptsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Award Loyalty Points'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer UID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ptsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Points',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. Welcome bonus',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = uidCtrl.text.trim();
              final pts = int.tryParse(ptsCtrl.text.trim()) ?? 0;
              if (uid.isEmpty || pts <= 0) return;

              // Add loyalty event
              await FirebaseFirestore.instance
                  .collection('loyalty_events')
                  .add({
                    'uid': uid,
                    'type': 'earn',
                    'action': 'admin_award',
                    'reason': reasonCtrl.text.trim(),
                    'points': pts,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

              // Increment user points
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                    'loyaltyPoints': FieldValue.increment(pts),
                    'totalPointsEarned': FieldValue.increment(pts),
                  });

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Awarded $pts pts to $uid')),
                );
              }
            },
            child: const Text('Award'),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AdminColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event row ──

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EventRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'earn';
    final action = data['action'] ?? '';
    final pts = data['points'] ?? 0;
    final uid = data['uid'] ?? '';
    final reason = data['reason'] ?? '';
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final isEarn = type == 'earn';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.line),
      ),
      child: Row(
        children: [
          Icon(
            isEarn ? Icons.add_circle : Icons.remove_circle,
            color: isEarn ? AdminColors.accent : AdminColors.accent3,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.toString().replaceAll('_', ' '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AdminColors.ink,
                    fontSize: 13,
                  ),
                ),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            uid.toString().substring(0, uid.toString().length.clamp(0, 8)),
            style: const TextStyle(fontSize: 11, color: AdminColors.muted),
          ),
          const SizedBox(width: 12),
          Text(
            '${isEarn ? '+' : '-'}$pts',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isEarn ? AdminColors.accent : AdminColors.accent3,
            ),
          ),
          const SizedBox(width: 12),
          if (ts != null)
            Text(
              DateFormat.MMMd().add_jm().format(ts),
              style: const TextStyle(fontSize: 11, color: AdminColors.muted),
            ),
        ],
      ),
    );
  }
}
