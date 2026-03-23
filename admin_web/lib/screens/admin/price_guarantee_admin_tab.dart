import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Price Guarantee Admin — Configure guarantee thresholds per service,
/// view violations, and audit refunds from `checkPriceGuarantee`.
/// ---------------------------------------------------------------------------
class PriceGuaranteeAdminTab extends StatefulWidget {
  final bool canWrite;
  const PriceGuaranteeAdminTab({super.key, this.canWrite = false});

  @override
  State<PriceGuaranteeAdminTab> createState() => _PriceGuaranteeAdminTabState();
}

class _PriceGuaranteeAdminTabState extends State<PriceGuaranteeAdminTab> {
  StreamSubscription? _rulesSub;
  StreamSubscription? _violationsSub;
  bool _loading = true;
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _violations = [];

  // KPIs
  int _totalRules = 0;
  int _totalViolations = 0;
  double _totalRefunded = 0;
  int _pendingReview = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _rulesSub?.cancel();
    _violationsSub?.cancel();
    super.dispose();
  }

  void _listen() {
    _rulesSub = FirebaseFirestore.instance
        .collection('pricing_rules')
        .snapshots()
        .listen((snap) {
          setState(() {
            _rules = snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList();
            _totalRules = _rules.length;
            _loading = false;
          });
        });

    _violationsSub = FirebaseFirestore.instance
        .collection('price_guarantee_violations')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
          final docs = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();

          double refunded = 0;
          int pending = 0;
          for (final v in docs) {
            refunded += (v['refundAmount'] as num?)?.toDouble() ?? 0;
            if (v['status'] == 'pending') pending++;
          }

          setState(() {
            _violations = docs;
            _totalViolations = docs.length;
            _totalRefunded = refunded;
            _pendingReview = pending;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // KPIs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _kpi('Rules', '$_totalRules', AdminColors.accent2),
                _kpi('Violations', '$_totalViolations', AdminColors.warning),
                _kpi(
                  'Refunded',
                  '\$${NumberFormat.compact().format(_totalRefunded)}',
                  AdminColors.error,
                ),
                _kpi('Pending', '$_pendingReview', AdminColors.accent3),
              ],
            ),
          ),

          const TabBar(
            tabs: [
              Tab(text: 'Pricing Rules'),
              Tab(text: 'Violations'),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [_buildRulesTab(), _buildViolationsTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rules tab ──

  Widget _buildRulesTab() {
    return Column(
      children: [
        if (widget.canWrite)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showRuleDialog(context, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Rule'),
              ),
            ),
          ),
        Expanded(
          child: _rules.isEmpty
              ? Center(
                  child: Text(
                    'No pricing rules configured',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = _rules[i];
                    final service = r['service'] ?? 'Unknown';
                    final threshold = r['guaranteeThresholdPercent'] ?? 15;
                    final minPrice = r['minGuaranteePrice'] ?? 0;
                    final maxPrice = r['maxGuaranteePrice'] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AdminColors.ink,
                                  ),
                                ),
                                Text(
                                  'Threshold: $threshold% · Min: \$$minPrice · Max: \$$maxPrice',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AdminColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.canWrite) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 18,
                                color: AdminColors.accent2,
                              ),
                              onPressed: () => _showRuleDialog(context, r),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: AdminColors.error,
                              ),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('pricing_rules')
                                    .doc(r['id'])
                                    .delete();
                              },
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

  // ── Violations tab ──

  Widget _buildViolationsTab() {
    return _violations.isEmpty
        ? Center(
            child: Text(
              'No violations recorded',
              style: TextStyle(color: AdminColors.muted),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _violations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = _violations[i];
              final jobId = v['jobId'] ?? '';
              final status = v['status'] ?? 'pending';
              final refund = (v['refundAmount'] as num?)?.toDouble() ?? 0;
              final ts = (v['createdAt'] as Timestamp?)?.toDate();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status == 'pending'
                        ? AdminColors.warning.withValues(alpha: 0.4)
                        : AdminColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'resolved'
                          ? Icons.check_circle
                          : Icons.warning_amber,
                      color: status == 'resolved'
                          ? AdminColors.accent
                          : AdminColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job: ${jobId.toString().substring(0, jobId.toString().length.clamp(0, 12))}…',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AdminColors.ink,
                              fontSize: 13,
                            ),
                          ),
                          if (ts != null)
                            Text(
                              DateFormat.yMMMd().add_jm().format(ts),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AdminColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'pending'
                            ? AdminColors.warning.withValues(alpha: 0.15)
                            : AdminColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: status == 'pending'
                              ? AdminColors.warning
                              : AdminColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '\$${refund.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminColors.error,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  // ── Rule dialog ──

  void _showRuleDialog(BuildContext context, Map<String, dynamic>? rule) {
    final serviceCtrl = TextEditingController(
      text: rule?['service'] as String? ?? '',
    );
    final threshCtrl = TextEditingController(
      text: (rule?['guaranteeThresholdPercent'] ?? 15).toString(),
    );
    final minCtrl = TextEditingController(
      text: (rule?['minGuaranteePrice'] ?? 0).toString(),
    );
    final maxCtrl = TextEditingController(
      text: (rule?['maxGuaranteePrice'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rule == null ? 'New Pricing Rule' : 'Edit Rule'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serviceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Service (e.g. interior_painting)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: threshCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Guarantee Threshold %',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min Guarantee Price',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Guarantee Price',
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
              final data = {
                'service': serviceCtrl.text.trim(),
                'guaranteeThresholdPercent':
                    int.tryParse(threshCtrl.text.trim()) ?? 15,
                'minGuaranteePrice': double.tryParse(minCtrl.text.trim()) ?? 0,
                'maxGuaranteePrice': double.tryParse(maxCtrl.text.trim()) ?? 0,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (rule != null) {
                await FirebaseFirestore.instance
                    .collection('pricing_rules')
                    .doc(rule['id'])
                    .update(data);
              } else {
                data['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance
                    .collection('pricing_rules')
                    .add(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(rule == null ? 'Create' : 'Save'),
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
