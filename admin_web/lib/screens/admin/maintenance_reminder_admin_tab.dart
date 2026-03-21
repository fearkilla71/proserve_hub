import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Maintenance Reminder Campaigns — Manage push-notification campaigns
/// for recurring maintenance reminders, view delivery stats.
/// ---------------------------------------------------------------------------
class MaintenanceReminderAdminTab extends StatefulWidget {
  final bool canWrite;
  const MaintenanceReminderAdminTab({super.key, this.canWrite = false});

  @override
  State<MaintenanceReminderAdminTab> createState() =>
      _MaintenanceReminderAdminTabState();
}

class _MaintenanceReminderAdminTabState
    extends State<MaintenanceReminderAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _campaigns = [];

  String _filter = 'all'; // all | active | paused | completed
  String _search = '';

  // KPIs
  int _total = 0;
  int _active = 0;
  int _totalSent = 0;
  int _totalConverted = 0;

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
        .collection('maintenance_campaigns')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      int active = 0;
      int sent = 0;
      int converted = 0;
      for (final c in docs) {
        if (c['status'] == 'active') active++;
        sent += (c['remindersSent'] as num?)?.toInt() ?? 0;
        converted += (c['conversions'] as num?)?.toInt() ?? 0;
      }

      setState(() {
        _campaigns = docs;
        _total = docs.length;
        _active = active;
        _totalSent = sent;
        _totalConverted = converted;
        _loading = false;
      });
    });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _campaigns;
    if (_filter != 'all') {
      list = list.where((c) => c['status'] == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((c) =>
              (c['name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['service'] ?? '').toString().toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonLoader();

    final filtered = _filtered;
    final convRate =
        _totalSent == 0 ? 0.0 : (_totalConverted / _totalSent) * 100;

    return Column(
      children: [
        // KPIs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _kpi('Campaigns', '$_total', AdminColors.accent2),
              _kpi('Active', '$_active', AdminColors.accent),
              _kpi('Sent', NumberFormat.compact().format(_totalSent),
                  AdminColors.accent3),
              _kpi('Conv Rate', '${convRate.toStringAsFixed(1)}%',
                  AdminColors.warning),
            ],
          ),
        ),

        // Filter + actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['all', 'active', 'paused', 'completed'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s[0].toUpperCase() + s.substring(1),
                        style: const TextStyle(fontSize: 12)),
                    selected: _filter == s,
                    selectedColor:
                        AdminColors.accent2.withValues(alpha: 0.15),
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                ),
              const Spacer(),
              if (widget.canWrite)
                FilledButton.icon(
                  onPressed: () => _showCampaignDialog(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Campaign'),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
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
                  child: Text('No campaigns found',
                      style: TextStyle(color: AdminColors.muted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    final name = c['name'] ?? 'Untitled';
                    final service = c['service'] ?? '';
                    final status = c['status'] ?? 'active';
                    final sent =
                        (c['remindersSent'] as num?)?.toInt() ?? 0;
                    final conv =
                        (c['conversions'] as num?)?.toInt() ?? 0;
                    final intervalDays =
                        (c['intervalDays'] as num?)?.toInt() ?? 30;

                    Color statusColor;
                    switch (status) {
                      case 'active':
                        statusColor = AdminColors.accent;
                        break;
                      case 'paused':
                        statusColor = AdminColors.warning;
                        break;
                      default:
                        statusColor = AdminColors.muted;
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              size: 18, color: statusColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.ink)),
                                Text(
                                  '${service.toString().isNotEmpty ? '$service · ' : ''}Every $intervalDays days · $sent sent · $conv converted',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AdminColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor),
                            ),
                          ),
                          if (widget.canWrite) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  size: 18, color: AdminColors.muted),
                              onSelected: (val) async {
                                if (val == 'pause' || val == 'resume') {
                                  await FirebaseFirestore.instance
                                      .collection(
                                          'maintenance_campaigns')
                                      .doc(c['id'])
                                      .update({
                                    'status': val == 'pause'
                                        ? 'paused'
                                        : 'active',
                                  });
                                } else if (val == 'delete') {
                                  await FirebaseFirestore.instance
                                      .collection(
                                          'maintenance_campaigns')
                                      .doc(c['id'])
                                      .delete();
                                }
                              },
                              itemBuilder: (_) => [
                                if (status == 'active')
                                  const PopupMenuItem(
                                      value: 'pause',
                                      child: Text('Pause')),
                                if (status == 'paused')
                                  const PopupMenuItem(
                                      value: 'resume',
                                      child: Text('Resume')),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete')),
                              ],
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

  void _showCampaignDialog(
      BuildContext context, Map<String, dynamic>? campaign) {
    final nameCtrl = TextEditingController(
        text: campaign?['name'] as String? ?? '');
    final serviceCtrl = TextEditingController(
        text: campaign?['service'] as String? ?? '');
    final intervalCtrl = TextEditingController(
        text: (campaign?['intervalDays'] ?? 30).toString());
    final messageCtrl = TextEditingController(
        text: campaign?['message'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(campaign == null ? 'New Campaign' : 'Edit Campaign'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Campaign Name',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serviceCtrl,
                decoration: const InputDecoration(
                    labelText: 'Service (e.g. hvac_tune_up)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: intervalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Interval (days)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Reminder Message',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final data = {
                'name': nameCtrl.text.trim(),
                'service': serviceCtrl.text.trim(),
                'intervalDays':
                    int.tryParse(intervalCtrl.text.trim()) ?? 30,
                'message': messageCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (campaign != null) {
                await FirebaseFirestore.instance
                    .collection('maintenance_campaigns')
                    .doc(campaign['id'])
                    .update(data);
              } else {
                data['createdAt'] = FieldValue.serverTimestamp();
                data['status'] = 'active';
                data['remindersSent'] = 0;
                data['conversions'] = 0;
                await FirebaseFirestore.instance
                    .collection('maintenance_campaigns')
                    .add(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(campaign == null ? 'Create' : 'Save'),
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
