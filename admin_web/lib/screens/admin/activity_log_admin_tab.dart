import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// Real-time activity / audit log for all admin-visible events:
/// logins, user actions, escrow events, disputes, verifications, payments, etc.
class ActivityLogAdminTab extends StatefulWidget {
  const ActivityLogAdminTab({super.key});

  @override
  State<ActivityLogAdminTab> createState() => _ActivityLogAdminTabState();
}

class _ActivityLogAdminTabState extends State<ActivityLogAdminTab> {
  final _db = FirebaseFirestore.instance;
  final _dateFmt = DateFormat('MMM d, yyyy h:mm:ss a');

  bool _loading = true;
  String _typeFilter = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _logs = [];

  // Live streams
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> allLogs = [];

      // 1) Admin login logs
      final loginSnap = await _db
          .collection('admin_login_log')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      for (final doc in loginSnap.docs) {
        final d = doc.data();
        allLogs.add({
          'id': doc.id,
          'type': 'admin_login',
          'icon': Icons.admin_panel_settings,
          'color': AdminColors.accent3,
          'title': 'Admin Login',
          'detail': d['email'] ?? d['uid'] ?? 'Unknown',
          'status': d['status'] ?? 'success',
          'timestamp': d['timestamp'] as Timestamp?,
          'meta': d,
        });
      }

      // 2) Escrow events (status changes)
      final escrowSnap = await _db
          .collection('escrow_bookings')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      for (final doc in escrowSnap.docs) {
        final d = doc.data();
        final status = d['status'] as String? ?? '';
        allLogs.add({
          'id': doc.id,
          'type': 'escrow',
          'icon': Icons.account_balance_wallet,
          'color': AdminColors.accent,
          'title': 'Escrow ${_capitalize(status)}',
          'detail':
              '${d['service'] ?? 'Unknown'} — \$${(d['aiPrice'] as num?)?.toStringAsFixed(2) ?? '0'}',
          'status': status,
          'timestamp': d['createdAt'] as Timestamp?,
          'meta': d,
        });
      }

      // 3) Dispute events
      final disputeSnap = await _db
          .collection('disputes')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      for (final doc in disputeSnap.docs) {
        final d = doc.data();
        allLogs.add({
          'id': doc.id,
          'type': 'dispute',
          'icon': Icons.gavel,
          'color': AdminColors.error,
          'title': 'Dispute: ${d['reason'] ?? 'Unknown'}',
          'detail': d['description'] ?? '',
          'status': d['status'] ?? '',
          'timestamp': d['createdAt'] as Timestamp?,
          'meta': d,
        });
      }

      // 4) Verification submissions
      final verifySnap = await _db
          .collection('contractors')
          .where('idVerificationStatus', isEqualTo: 'pending')
          .limit(50)
          .get();
      for (final doc in verifySnap.docs) {
        final d = doc.data();
        allLogs.add({
          'id': doc.id,
          'type': 'verification',
          'icon': Icons.verified_user,
          'color': AdminColors.warning,
          'title': 'Verification Pending',
          'detail': d['businessName'] ?? d['name'] ?? 'Unknown',
          'status': 'pending',
          'timestamp': d['createdAt'] as Timestamp?,
          'meta': d,
        });
      }

      // 5) New user registrations (last 100)
      final usersSnap = await _db
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      for (final doc in usersSnap.docs) {
        final d = doc.data();
        allLogs.add({
          'id': doc.id,
          'type': 'user_signup',
          'icon': Icons.person_add,
          'color': AdminColors.accent2,
          'title': 'New User Signup',
          'detail': d['displayName'] ?? d['name'] ?? d['email'] ?? 'Unknown',
          'status': 'registered',
          'timestamp': d['createdAt'] as Timestamp?,
          'meta': d,
        });
      }

      // 6) New contractor registrations (last 100)
      final contractorsSnap = await _db
          .collection('contractors')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      for (final doc in contractorsSnap.docs) {
        final d = doc.data();
        allLogs.add({
          'id': doc.id,
          'type': 'contractor_signup',
          'icon': Icons.engineering,
          'color': const Color(0xFF4CAF50),
          'title': 'New Contractor',
          'detail': d['businessName'] ?? d['name'] ?? 'Unknown',
          'status': 'registered',
          'timestamp': d['createdAt'] as Timestamp?,
          'meta': d,
        });
      }

      // 7) Job creations (last 100)
      final jobsSnap = await _db
          .collection('jobs')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      for (final doc in jobsSnap.docs) {
        final d = doc.data();
        allLogs.add({
          'id': doc.id,
          'type': 'job',
          'icon': Icons.work,
          'color': AdminColors.accent2,
          'title': 'Job: ${d['title'] ?? d['service'] ?? 'Unknown'}',
          'detail': 'Status: ${d['status'] ?? 'unknown'} — ${d['zip'] ?? ''}',
          'status': d['status'] ?? '',
          'timestamp': d['createdAt'] as Timestamp?,
          'meta': d,
        });
      }

      // Sort all by timestamp descending
      allLogs.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      setState(() {
        _logs = allLogs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading activity log: $e');
      setState(() => _loading = false);
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  List<Map<String, dynamic>> get _filteredLogs {
    var filtered = _logs;
    if (_typeFilter != 'all') {
      filtered = filtered.where((l) => l['type'] == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((l) {
        final title = (l['title'] as String? ?? '').toLowerCase();
        final detail = (l['detail'] as String? ?? '').toLowerCase();
        final id = (l['id'] as String? ?? '').toLowerCase();
        return title.contains(q) || detail.contains(q) || id.contains(q);
      }).toList();
    }
    return filtered;
  }

  Map<String, int> get _typeCounts {
    final counts = <String, int>{};
    for (final l in _logs) {
      final t = l['type'] as String? ?? 'unknown';
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildSkeleton();

    final counts = _typeCounts;
    final filtered = _filteredLogs;

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Title ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Log',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                children: [
                  Text(
                    '${filtered.length} events',
                    style: TextStyle(color: AdminColors.muted, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadLogs,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Type filter chips ──
          _buildTypeFilters(counts),
          const SizedBox(height: 12),

          // ── Search ──
          TextField(
            decoration: InputDecoration(
              hintText: 'Search events...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AdminColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 16),

          // ── Timeline ──
          ...filtered.map(_buildLogEntry),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.event_note, size: 48, color: AdminColors.muted),
                    const SizedBox(height: 12),
                    Text(
                      'No activity found',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeFilters(Map<String, int> counts) {
    final types = [
      {
        'key': 'all',
        'label': 'All',
        'icon': Icons.list,
        'color': AdminColors.ink,
      },
      {
        'key': 'admin_login',
        'label': 'Logins',
        'icon': Icons.admin_panel_settings,
        'color': AdminColors.accent3,
      },
      {
        'key': 'escrow',
        'label': 'Escrow',
        'icon': Icons.account_balance_wallet,
        'color': AdminColors.accent,
      },
      {
        'key': 'dispute',
        'label': 'Disputes',
        'icon': Icons.gavel,
        'color': AdminColors.error,
      },
      {
        'key': 'verification',
        'label': 'Verify',
        'icon': Icons.verified_user,
        'color': AdminColors.warning,
      },
      {
        'key': 'user_signup',
        'label': 'Users',
        'icon': Icons.person_add,
        'color': AdminColors.accent2,
      },
      {
        'key': 'contractor_signup',
        'label': 'Contractors',
        'icon': Icons.engineering,
        'color': const Color(0xFF4CAF50),
      },
      {
        'key': 'job',
        'label': 'Jobs',
        'icon': Icons.work,
        'color': AdminColors.accent2,
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: types.map((t) {
        final key = t['key'] as String;
        final label = t['label'] as String;
        final icon = t['icon'] as IconData;
        final color = t['color'] as Color;
        final count = key == 'all' ? _logs.length : (counts[key] ?? 0);
        final selected = _typeFilter == key;

        return FilterChip(
          selected: selected,
          avatar: Icon(
            icon,
            size: 16,
            color: selected ? color : AdminColors.muted,
          ),
          label: Text('$label ($count)'),
          selectedColor: color.withValues(alpha: 0.15),
          checkmarkColor: color,
          onSelected: (_) => setState(() => _typeFilter = key),
        );
      }).toList(),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final icon = log['icon'] as IconData? ?? Icons.info;
    final color = log['color'] as Color? ?? AdminColors.muted;
    final title = log['title'] as String? ?? '';
    final detail = log['detail'] as String? ?? '';
    final ts = (log['timestamp'] as Timestamp?)?.toDate();

    final now = DateTime.now();
    final timeAgo = ts != null ? _timeAgo(now.difference(ts)) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showLogDetail(log),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot + line
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 2, height: 50, color: AdminColors.line),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AdminColors.ink,
                              ),
                            ),
                            if (detail.isNotEmpty)
                              Text(
                                detail,
                                style: TextStyle(
                                  color: AdminColors.muted,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: AdminColors.muted,
                              fontSize: 10,
                            ),
                          ),
                          if (ts != null)
                            Text(
                              _dateFmt.format(ts),
                              style: TextStyle(
                                color: AdminColors.muted.withValues(alpha: 0.5),
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return '${(d.inDays / 30).floor()}mo ago';
  }

  void _showLogDetail(Map<String, dynamic> log) {
    final meta = log['meta'] as Map<String, dynamic>? ?? {};
    final title = log['title'] as String? ?? '';
    final color = log['color'] as Color? ?? AdminColors.muted;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  ...meta.entries.map((e) {
                    String val;
                    if (e.value is Timestamp) {
                      val = _dateFmt.format((e.value as Timestamp).toDate());
                    } else {
                      val = e.value?.toString() ?? '';
                    }
                    if (val.length > 200) val = '${val.substring(0, 200)}...';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              e.key,
                              style: TextStyle(
                                color: AdminColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              val,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonLoader(
              width: 160,
              height: 22,
              borderRadius: BorderRadius.circular(6),
            ),
            SkeletonLoader(
              width: 70,
              height: 22,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: List.generate(
            6,
            (_) => SkeletonLoader(
              width: 90,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          8,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SkeletonLoader(
              width: double.infinity,
              height: 60,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
