import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Verification Tier Admin — Manage contractor tier overrides
/// (none → verified → trusted_pro → elite_pro).
/// ---------------------------------------------------------------------------
class VerificationTierAdminTab extends StatefulWidget {
  final bool canWrite;
  const VerificationTierAdminTab({super.key, this.canWrite = false});

  @override
  State<VerificationTierAdminTab> createState() =>
      _VerificationTierAdminTabState();
}

class _VerificationTierAdminTabState extends State<VerificationTierAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _contractors = [];
  String _tierFilter = 'all';
  String _search = '';

  // KPIs
  int _noneCount = 0;
  int _verifiedCount = 0;
  int _trustedCount = 0;
  int _eliteCount = 0;

  static const _tiers = ['none', 'verified', 'trusted_pro', 'elite_pro'];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    _sub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'contractor')
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['uid'] = d.id;
        return data;
      }).toList();

      int none = 0, verified = 0, trusted = 0, elite = 0;
      for (final c in docs) {
        switch (c['verificationTier'] ?? 'none') {
          case 'verified':
            verified++;
          case 'trusted_pro':
            trusted++;
          case 'elite_pro':
            elite++;
          default:
            none++;
        }
      }

      setState(() {
        _contractors = docs;
        _noneCount = none;
        _verifiedCount = verified;
        _trustedCount = trusted;
        _eliteCount = elite;
        _loading = false;
      });
    });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _contractors;
    if (_tierFilter != 'all') {
      list = list
          .where((c) => (c['verificationTier'] ?? 'none') == _tierFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((c) {
        final name = (c['displayName'] ?? '').toString().toLowerCase();
        final email = (c['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonLoader();

    return Column(
      children: [
        // KPIs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpi('None', '$_noneCount', AdminColors.muted),
              _kpi('Verified', '$_verifiedCount', AdminColors.accent2),
              _kpi('Trusted Pro', '$_trustedCount', AdminColors.accent),
              _kpi('Elite Pro', '$_eliteCount', AdminColors.accent3),
            ],
          ),
        ),
        const Divider(color: AdminColors.line, height: 1),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'none', label: Text('None')),
                  ButtonSegment(value: 'verified', label: Text('Verified')),
                  ButtonSegment(
                      value: 'trusted_pro', label: Text('Trusted')),
                  ButtonSegment(value: 'elite_pro', label: Text('Elite')),
                ],
                selected: {_tierFilter},
                onSelectionChanged: (v) =>
                    setState(() => _tierFilter = v.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text('No contractors found',
                      style: TextStyle(color: AdminColors.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = _filtered[i];
                    return _TierRow(
                      data: c,
                      canWrite: widget.canWrite,
                      onChangeTier: (newTier) =>
                          _setTier(c['uid'], newTier),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _setTier(String uid, String newTier) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'verificationTier': newTier,
      'tierOverriddenByAdmin': true,
      'tierOverrideAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tier updated to $newTier')),
      );
    }
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
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AdminColors.muted)),
          ],
        ),
      ),
    );
  }
}

// ── Row widget ──

class _TierRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canWrite;
  final ValueChanged<String> onChangeTier;

  const _TierRow({
    required this.data,
    required this.canWrite,
    required this.onChangeTier,
  });

  static const _tierLabels = {
    'none': 'None',
    'verified': 'Verified',
    'trusted_pro': 'Trusted Pro',
    'elite_pro': 'Elite Pro',
  };

  static const _tierColors = {
    'none': AdminColors.muted,
    'verified': AdminColors.accent2,
    'trusted_pro': AdminColors.accent,
    'elite_pro': AdminColors.accent3,
  };

  @override
  Widget build(BuildContext context) {
    final name = data['displayName'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final tier = data['verificationTier'] ?? 'none';
    final overridden = data['tierOverriddenByAdmin'] == true;
    final completedJobs = data['completedJobs'] ?? 0;
    final rating = (data['avgRating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.line),
      ),
      child: Row(
        children: [
          // Tier badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (_tierColors[tier] ?? AdminColors.muted).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _tierLabels[tier] ?? tier,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _tierColors[tier] ?? AdminColors.muted,
              ),
            ),
          ),
          if (overridden) ...[
            const SizedBox(width: 6),
            const Tooltip(
              message: 'Admin override',
              child:
                  Icon(Icons.admin_panel_settings, size: 14, color: AdminColors.warning),
            ),
          ],
          const SizedBox(width: 12),

          // Name & email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminColors.ink)),
                Text(email,
                    style: const TextStyle(
                        fontSize: 11, color: AdminColors.muted)),
              ],
            ),
          ),

          // Stats
          _stat('Jobs', '$completedJobs'),
          const SizedBox(width: 16),
          _stat('Rating', rating.toStringAsFixed(1)),
          const SizedBox(width: 16),

          // Promote / demote
          if (canWrite)
            PopupMenuButton<String>(
              tooltip: 'Change tier',
              icon: const Icon(Icons.swap_vert, size: 18),
              onSelected: onChangeTier,
              itemBuilder: (_) => _TierRow._tierLabels.entries
                  .map((e) => PopupMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AdminColors.ink)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AdminColors.muted)),
      ],
    );
  }
}
