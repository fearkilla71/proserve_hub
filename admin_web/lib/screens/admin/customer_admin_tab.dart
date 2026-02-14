import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Customer Admin Tab — Real-time customer (homeowner) management
/// ---------------------------------------------------------------------------
class CustomerAdminTab extends StatefulWidget {
  final bool canWrite;
  const CustomerAdminTab({super.key, this.canWrite = false});

  @override
  State<CustomerAdminTab> createState() => _CustomerAdminTabState();
}

class _CustomerAdminTabState extends State<CustomerAdminTab> {
  StreamSubscription? _sub;
  bool _loading = true;
  List<Map<String, dynamic>> _customers = [];
  String _search = '';
  String _sort = 'newest';
  bool _showInactive = false;

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
        .where('role', isEqualTo: 'customer')
        .snapshots()
        .listen((snap) {
          setState(() {
            _customers = snap.docs.map((d) {
              final data = d.data();
              data['uid'] = d.id;
              return data;
            }).toList();
            _loading = false;
          });
        });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_customers);

    if (!_showInactive) {
      list = list.where((u) => u['isDeleted'] != true).toList();
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) {
        final name = (u['displayName'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final zip = (u['zip'] ?? '').toString();
        return name.contains(q) || email.contains(q) || zip.contains(q);
      }).toList();
    }

    switch (_sort) {
      case 'newest':
        list.sort((a, b) {
          final at = a['createdAt'] as Timestamp?;
          final bt = b['createdAt'] as Timestamp?;
          return (bt?.seconds ?? 0).compareTo(at?.seconds ?? 0);
        });
        break;
      case 'oldest':
        list.sort((a, b) {
          final at = a['createdAt'] as Timestamp?;
          final bt = b['createdAt'] as Timestamp?;
          return (at?.seconds ?? 0).compareTo(bt?.seconds ?? 0);
        });
        break;
      case 'name_az':
        list.sort(
          (a, b) => (a['displayName'] ?? '').toString().compareTo(
            (b['displayName'] ?? '').toString(),
          ),
        );
        break;
      case 'name_za':
        list.sort(
          (a, b) => (b['displayName'] ?? '').toString().compareTo(
            (a['displayName'] ?? '').toString(),
          ),
        );
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final total = _customers.where((u) => u['isDeleted'] != true).length;
    final withFcm = _customers
        .where(
          (u) =>
              u['isDeleted'] != true &&
              (u['fcmToken'] ?? '').toString().isNotEmpty,
        )
        .length;
    final recentWeek = _customers.where((u) {
      final t = u['createdAt'] as Timestamp?;
      if (t == null) return false;
      return t.toDate().isAfter(
        DateTime.now().subtract(const Duration(days: 7)),
      );
    }).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Customer Management',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // ── KPI Cards ───────────────────────────────────────────
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _kpiCard('Total Customers', '$total', Icons.people, Colors.blue),
            _kpiCard('New (7d)', '$recentWeek', Icons.person_add, Colors.green),
            _kpiCard(
              'Push Enabled',
              '$withFcm',
              Icons.notifications_active,
              Colors.orange,
            ),
            _kpiCard(
              'Inactive',
              '${_customers.where((u) => u['isDeleted'] == true).length}',
              Icons.person_off,
              Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Filters ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name, email, or ZIP...',
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest first')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
                DropdownMenuItem(value: 'name_az', child: Text('Name A-Z')),
                DropdownMenuItem(value: 'name_za', child: Text('Name Z-A')),
              ],
              onChanged: (v) => setState(() => _sort = v!),
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: const Text('Show inactive'),
              selected: _showInactive,
              onSelected: (v) => setState(() => _showInactive = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${filtered.length} results',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),

        // ── Customer List ────────────────────────────────────────
        ...filtered.map((u) => _customerCard(u)),
      ],
    );
  }

  Widget _customerCard(Map<String, dynamic> u) {
    final name = u['displayName'] ?? 'Unknown';
    final email = u['email'] ?? '';
    final zip = u['zip'] ?? '';
    final city = u['city'] ?? '';
    final phone = u['phone'] ?? '';
    final created = u['createdAt'];
    final createdStr = created is Timestamp
        ? DateFormat.yMMMd().format(created.toDate())
        : '—';
    final hasFcm = (u['fcmToken'] ?? '').toString().isNotEmpty;
    final isDeleted = u['isDeleted'] == true;

    return Card(
      color: isDeleted ? Colors.red.withValues(alpha: 0.05) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDeleted
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.2),
          child: Icon(
            isDeleted ? Icons.person_off : Icons.person,
            color: isDeleted ? Colors.red : Colors.blue,
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(name)),
            if (hasFcm)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.notifications_active,
                  size: 14,
                  color: Colors.orange,
                ),
              ),
            if (isDeleted)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Chip(
                  label: const Text(
                    'ARCHIVED',
                    style: TextStyle(fontSize: 9, color: Colors.red),
                  ),
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$email\n'
          '${city.isNotEmpty ? '$city, ' : ''}$zip'
          '${phone.isNotEmpty ? ' · $phone' : ''}'
          ' · Joined: $createdStr',
        ),
        isThreeLine: true,
        trailing: widget.canWrite
            ? PopupMenuButton<String>(
                onSelected: (action) => _handleAction(action, u),
                itemBuilder: (_) => [
                  if (!isDeleted)
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                  if (isDeleted)
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore'),
                    ),
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View details'),
                  ),
                ],
              )
            : null,
        onTap: () => _showDetailSheet(u),
      ),
    );
  }

  void _handleAction(String action, Map<String, dynamic> user) async {
    final uid = user['uid'] as String;
    switch (action) {
      case 'archive':
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isDeleted': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user['displayName']} archived')),
          );
        }
        break;
      case 'restore':
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isDeleted': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user['displayName']} restored')),
          );
        }
        break;
      case 'view':
        _showDetailSheet(user);
        break;
    }
  }

  void _showDetailSheet(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              u['displayName'] ?? 'Unknown',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _detailRow('UID', u['uid'] ?? ''),
            _detailRow('Email', u['email'] ?? ''),
            _detailRow('Phone', u['phone'] ?? '—'),
            _detailRow('City', u['city'] ?? '—'),
            _detailRow('ZIP', u['zip'] ?? '—'),
            _detailRow('State', u['state'] ?? '—'),
            _detailRow(
              'Created',
              u['createdAt'] is Timestamp
                  ? DateFormat.yMMMd().add_jm().format(
                      (u['createdAt'] as Timestamp).toDate(),
                    )
                  : '—',
            ),
            _detailRow(
              'Last Sign-in',
              u['lastSignIn'] is Timestamp
                  ? DateFormat.yMMMd().add_jm().format(
                      (u['lastSignIn'] as Timestamp).toDate(),
                    )
                  : '—',
            ),
            _detailRow(
              'Push Notifications',
              (u['fcmToken'] ?? '').toString().isNotEmpty
                  ? 'Enabled'
                  : 'Disabled',
            ),
            _detailRow(
              'Status',
              u['isDeleted'] == true ? 'ARCHIVED' : 'Active',
            ),

            const SizedBox(height: 24),
            Text('Job Requests', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Load job requests for this customer
            _CustomerJobsList(customerId: u['uid'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget that loads a customer's job requests
class _CustomerJobsList extends StatelessWidget {
  final String customerId;
  const _CustomerJobsList({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_requests')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text(
            'No job requests yet.',
            style: TextStyle(color: Colors.white54),
          );
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final service = data['serviceType'] ?? 'Service';
            final status = data['status'] ?? 'open';
            final created = data['createdAt'];
            final dateStr = created is Timestamp
                ? DateFormat.yMMMd().format(created.toDate())
                : '—';
            return ListTile(
              dense: true,
              leading: const Icon(Icons.work_outline, size: 18),
              title: Text(service),
              subtitle: Text('$status · $dateStr'),
            );
          }).toList(),
        );
      },
    );
  }
}
