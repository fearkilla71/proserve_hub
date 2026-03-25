import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Crew & Multi-Location Insights — Utilisation per crew, location-based
/// metrics, scheduling conflict detection, crew performance comparison.
/// ---------------------------------------------------------------------------
class CrewMultiLocationAdminTab extends StatefulWidget {
  const CrewMultiLocationAdminTab({super.key});

  @override
  State<CrewMultiLocationAdminTab> createState() =>
      _CrewMultiLocationAdminTabState();
}

class _CrewMultiLocationAdminTabState extends State<CrewMultiLocationAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _crews = [];

  String _search = '';

  // KPIs
  int _totalCrews = 0;
  int _totalMembers = 0;
  int _activeToday = 0;
  double _avgUtilisation = 0;

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
        .collection('crews')
        .snapshots()
        .listen(
          (snap) {
            final docs = snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList();

            int members = 0;
            int active = 0;
            double sumUtil = 0;

            for (final c in docs) {
              final m =
                  (c['memberCount'] as num?)?.toInt() ??
                  (c['members'] as List?)?.length ??
                  0;
              members += m;
              if (c['activeToday'] == true) active++;
              sumUtil += (c['utilisationPercent'] as num?)?.toDouble() ?? 0;
            }

            setState(() {
              _crews = docs;
              _totalCrews = docs.length;
              _totalMembers = members;
              _activeToday = active;
              _avgUtilisation = docs.isEmpty ? 0 : sumUtil / docs.length;
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('crews listen error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _crews;
    final q = _search.toLowerCase();
    return _crews
        .where(
          (c) =>
              (c['name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['location'] ?? '').toString().toLowerCase().contains(q) ||
              (c['ownerName'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;

    return Column(
      children: [
        // KPIs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpi('Crews', '$_totalCrews', AdminColors.accent2),
              _kpi('Members', '$_totalMembers', AdminColors.accent),
              _kpi('Active Today', '$_activeToday', AdminColors.accent3),
              _kpi(
                'Avg Util',
                '${_avgUtilisation.toStringAsFixed(0)}%',
                AdminColors.warning,
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search crews…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No crews found',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    final name = c['name'] ?? 'Unnamed Crew';
                    final owner = c['ownerName'] ?? '';
                    final location = c['location'] ?? '';
                    final memberCount =
                        (c['memberCount'] as num?)?.toInt() ??
                        (c['members'] as List?)?.length ??
                        0;
                    final util =
                        (c['utilisationPercent'] as num?)?.toDouble() ?? 0;
                    final jobsThisWeek =
                        (c['jobsThisWeek'] as num?)?.toInt() ?? 0;
                    final conflicts =
                        (c['schedulingConflicts'] as num?)?.toInt() ?? 0;
                    final isActive = c['activeToday'] == true;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isActive
                                ? AdminColors.accent.withValues(alpha: 0.15)
                                : AdminColors.muted.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.groups,
                              size: 16,
                              color: isActive
                                  ? AdminColors.accent
                                  : AdminColors.muted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                Text(
                                  '${owner.toString().isNotEmpty ? '$owner · ' : ''}$memberCount members${location.toString().isNotEmpty ? ' · $location' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AdminColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${util.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.accent,
                                ),
                              ),
                              Text(
                                '$jobsThisWeek jobs/wk',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AdminColors.muted,
                                ),
                              ),
                            ],
                          ),
                          if (conflicts > 0) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.error.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$conflicts conflicts',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
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
