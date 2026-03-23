import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

/// ---------------------------------------------------------------------------
/// Promotions & Deals Admin — CRUD for `promotions` collection,
/// redemption analytics, and campaign scheduling.
/// ---------------------------------------------------------------------------
class PromotionsAdminTab extends StatefulWidget {
  final bool canWrite;
  const PromotionsAdminTab({super.key, this.canWrite = false});

  @override
  State<PromotionsAdminTab> createState() => _PromotionsAdminTabState();
}

class _PromotionsAdminTabState extends State<PromotionsAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _promos = [];
  String _filter = 'all'; // all, active, expired, scheduled

  // KPIs
  int _totalPromos = 0;
  int _activeCount = 0;
  int _expiredCount = 0;
  int _totalRedemptions = 0;

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
        .collection('promotions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
          final now = DateTime.now();
          final docs = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();

          int active = 0, expired = 0, redemptions = 0;
          for (final p in docs) {
            final isActive = p['active'] == true;
            final expiresAt = (p['expiresAt'] as Timestamp?)?.toDate();
            if (isActive && (expiresAt == null || expiresAt.isAfter(now))) {
              active++;
            } else {
              expired++;
            }
            redemptions += (p['redemptionCount'] as int?) ?? 0;
          }

          setState(() {
            _promos = docs;
            _totalPromos = docs.length;
            _activeCount = active;
            _expiredCount = expired;
            _totalRedemptions = redemptions;
            _loading = false;
          });
        });
  }

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    switch (_filter) {
      case 'active':
        return _promos.where((p) {
          final exp = (p['expiresAt'] as Timestamp?)?.toDate();
          return p['active'] == true && (exp == null || exp.isAfter(now));
        }).toList();
      case 'expired':
        return _promos.where((p) {
          final exp = (p['expiresAt'] as Timestamp?)?.toDate();
          return p['active'] != true || (exp != null && exp.isBefore(now));
        }).toList();
      default:
        return _promos;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // KPI row
        _KpiBar(
          total: _totalPromos,
          active: _activeCount,
          expired: _expiredCount,
          redemptions: _totalRedemptions,
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
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(value: 'expired', label: Text('Expired')),
                ],
                selected: {_filter},
                onSelectionChanged: (v) => setState(() => _filter = v.first),
              ),
              const Spacer(),
              if (widget.canWrite)
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Promotion'),
                ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No promotions found',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _PromoCard(
                    data: _filtered[i],
                    canWrite: widget.canWrite,
                    onToggle: () => _toggleActive(_filtered[i]),
                    onEdit: () => _showEditDialog(context, _filtered[i]),
                    onDelete: () => _deletePromo(_filtered[i]['id']),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Actions ──

  Future<void> _toggleActive(Map<String, dynamic> promo) async {
    await FirebaseFirestore.instance
        .collection('promotions')
        .doc(promo['id'])
        .update({'active': !(promo['active'] == true)});
  }

  Future<void> _deletePromo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promotion?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('promotions')
          .doc(id)
          .delete();
    }
  }

  void _showCreateDialog(BuildContext context) {
    _showPromoForm(context, null);
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> promo) {
    _showPromoForm(context, promo);
  }

  void _showPromoForm(BuildContext context, Map<String, dynamic>? promo) {
    final titleCtrl = TextEditingController(
      text: promo?['title'] as String? ?? '',
    );
    final descCtrl = TextEditingController(
      text: promo?['description'] as String? ?? '',
    );
    final discountCtrl = TextEditingController(
      text: (promo?['discountPercent'] ?? '').toString(),
    );
    final services = <String>[];
    if (promo?['services'] is List) {
      services.addAll((promo!['services'] as List).cast<String>());
    }
    DateTime? expiresAt = (promo?['expiresAt'] as Timestamp?)?.toDate();
    bool active = promo?['active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(promo == null ? 'New Promotion' : 'Edit Promotion'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Discount %',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expiresAt != null
                                  ? 'Expires: ${DateFormat.yMMMd().format(expiresAt!)}'
                                  : 'No expiry set',
                              style: TextStyle(color: AdminColors.muted),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    expiresAt ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setLocal(() => expiresAt = picked);
                              }
                            },
                            child: const Text('Pick Date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Active'),
                        value: active,
                        onChanged: (v) => setLocal(() => active = v),
                      ),
                    ],
                  ),
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
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'discountPercent':
                          double.tryParse(discountCtrl.text.trim()) ?? 0,
                      'active': active,
                      'expiresAt': expiresAt != null
                          ? Timestamp.fromDate(expiresAt!)
                          : null,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    if (promo != null) {
                      await FirebaseFirestore.instance
                          .collection('promotions')
                          .doc(promo['id'])
                          .update(data);
                    } else {
                      data['createdAt'] = FieldValue.serverTimestamp();
                      data['redemptionCount'] = 0;
                      await FirebaseFirestore.instance
                          .collection('promotions')
                          .add(data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(promo == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── KPI Bar ──

class _KpiBar extends StatelessWidget {
  final int total, active, expired, redemptions;
  const _KpiBar({
    required this.total,
    required this.active,
    required this.expired,
    required this.redemptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _kpi('Total', '$total', AdminColors.accent2),
          _kpi('Active', '$active', AdminColors.accent),
          _kpi('Expired', '$expired', AdminColors.warning),
          _kpi('Redemptions', '$redemptions', AdminColors.accent3),
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

// ── Promo Card ──

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canWrite;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PromoCard({
    required this.data,
    required this.canWrite,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Untitled';
    final desc = data['description'] ?? '';
    final active = data['active'] == true;
    final discount = data['discountPercent'] ?? 0;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    final redemptions = data['redemptionCount'] ?? 0;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active && !isExpired
              ? AdminColors.accent.withValues(alpha: 0.3)
              : AdminColors.line,
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active && !isExpired
                  ? AdminColors.accent
                  : AdminColors.error,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminColors.ink,
                  ),
                ),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.muted,
                    ),
                  ),
              ],
            ),
          ),

          // Discount badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdminColors.accent3.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$discount% off',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminColors.accent3,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Redemptions
          Column(
            children: [
              Text(
                '$redemptions',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AdminColors.accent2,
                ),
              ),
              const Text(
                'uses',
                style: TextStyle(fontSize: 10, color: AdminColors.muted),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Expiry
          if (expiresAt != null)
            Text(
              DateFormat.MMMd().format(expiresAt),
              style: TextStyle(
                fontSize: 12,
                color: isExpired ? AdminColors.error : AdminColors.muted,
              ),
            ),

          // Actions
          if (canWrite) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: active ? 'Deactivate' : 'Activate',
              icon: Icon(
                active ? Icons.pause_circle : Icons.play_circle,
                color: active ? AdminColors.warning : AdminColors.accent,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(
                Icons.edit,
                color: AdminColors.accent2,
                size: 18,
              ),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(
                Icons.delete,
                color: AdminColors.error,
                size: 18,
              ),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
