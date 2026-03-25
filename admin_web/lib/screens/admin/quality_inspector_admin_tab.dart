import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Quality Inspector Admin — QA submission queue, approval/rejection workflow,
/// quality metrics per contractor, photographic evidence review.
/// ---------------------------------------------------------------------------
class QualityInspectorAdminTab extends StatefulWidget {
  final bool canWrite;
  const QualityInspectorAdminTab({super.key, this.canWrite = false});

  @override
  State<QualityInspectorAdminTab> createState() =>
      _QualityInspectorAdminTabState();
}

class _QualityInspectorAdminTabState extends State<QualityInspectorAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _submissions = [];

  String _filter = 'all'; // all | pending | approved | rejected
  String _search = '';

  // KPIs
  int _total = 0;
  int _pending = 0;
  int _approved = 0;
  double _avgScore = 0;

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
        .collection('quality_submissions')
        .orderBy('submittedAt', descending: true)
        .limit(300)
        .snapshots()
        .listen(
          (snap) {
            final docs = snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList();

            int pending = 0;
            int approved = 0;
            double sumScore = 0;
            int scored = 0;

            for (final s in docs) {
              final st = s['status'] ?? 'pending';
              if (st == 'pending') pending++;
              if (st == 'approved') approved++;
              final score = (s['qualityScore'] as num?)?.toDouble();
              if (score != null) {
                sumScore += score;
                scored++;
              }
            }

            setState(() {
              _submissions = docs;
              _total = docs.length;
              _pending = pending;
              _approved = approved;
              _avgScore = scored == 0 ? 0 : sumScore / scored;
              _loading = false;
            });
          },
          onError: (e) {
            debugPrint('quality_submissions listen error: $e');
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _submissions;
    if (_filter != 'all') {
      list = list.where((s) => s['status'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (s) =>
                (s['contractorName'] ?? '').toString().toLowerCase().contains(
                  q,
                ) ||
                (s['jobId'] ?? '').toString().toLowerCase().contains(q) ||
                (s['service'] ?? '').toString().toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  Future<void> _updateStatus(String id, String status, {double? score}) async {
    final data = <String, dynamic>{
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    };
    if (score != null) data['qualityScore'] = score;
    await FirebaseFirestore.instance
        .collection('quality_submissions')
        .doc(id)
        .update(data);
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
              _kpi('Submissions', '$_total', AdminColors.accent2),
              _kpi('Pending', '$_pending', AdminColors.warning),
              _kpi('Approved', '$_approved', AdminColors.accent),
              _kpi(
                'Avg Score',
                _avgScore.toStringAsFixed(1),
                AdminColors.accent3,
              ),
            ],
          ),
        ),

        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['all', 'pending', 'approved', 'rejected'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      s[0].toUpperCase() + s.substring(1),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _filter == s,
                    selectedColor: AdminColors.accent2.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search…',
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
                    'No submissions found',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    final contractor = s['contractorName'] ?? 'Unknown';
                    final service = s['service'] ?? '';
                    final status = s['status'] ?? 'pending';
                    final score = s['qualityScore'] as num?;
                    final photos = (s['photoUrls'] as List?)?.length ?? 0;
                    final ts = (s['submittedAt'] as Timestamp?)?.toDate();

                    Color statusColor;
                    switch (status) {
                      case 'approved':
                        statusColor = AdminColors.accent;
                        break;
                      case 'rejected':
                        statusColor = AdminColors.error;
                        break;
                      default:
                        statusColor = AdminColors.warning;
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: status == 'pending'
                              ? AdminColors.warning.withValues(alpha: 0.3)
                              : AdminColors.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            size: 18,
                            color: statusColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contractor.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (service.toString().isNotEmpty)
                                      Text(
                                        '$service · ',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AdminColors.muted,
                                        ),
                                      ),
                                    Text(
                                      '$photos photos',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AdminColors.muted,
                                      ),
                                    ),
                                    if (ts != null)
                                      Text(
                                        ' · ${DateFormat.MMMd().format(ts)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AdminColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (score != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.accent3.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${score.toStringAsFixed(1)}★',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.accent3,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (widget.canWrite && status == 'pending') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                size: 18,
                                color: AdminColors.accent,
                              ),
                              tooltip: 'Approve',
                              onPressed: () => _updateStatus(
                                s['id'],
                                'approved',
                                score: 5.0,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: AdminColors.error,
                              ),
                              tooltip: 'Reject',
                              onPressed: () =>
                                  _updateStatus(s['id'], 'rejected'),
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
