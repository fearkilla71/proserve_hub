import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Job Admin Tab — Real-time job management with search, detail view,
/// delete confirmation, status updates, and audit trail.
/// ---------------------------------------------------------------------------
class JobAdminTab extends StatefulWidget {
  const JobAdminTab({super.key, this.canWrite = true});
  final bool canWrite;

  @override
  State<JobAdminTab> createState() => _JobAdminTabState();
}

class _JobAdminTabState extends State<JobAdminTab> {
  String _statusFilter = 'all';
  String _claimFilter = 'all';
  String _sortBy = 'newest';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _dateFmt = DateFormat('MMM d, yyyy h:mm a');

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime? _createdAt(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['created_at'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _status(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.trim().toLowerCase();
    return status?.isNotEmpty == true ? status! : 'open';
  }

  bool _isClaimed(Map<String, dynamic> data) {
    return data['claimed'] == true ||
        ((data['claimedBy'] as String?)?.trim().isNotEmpty ?? false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'in_progress':
      case 'claimed':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading jobs:\n\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) {
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

        var docs = List<QueryDocumentSnapshot>.of(snap.data!.docs);
        final totalJobs = docs.length;

        // Count each status for KPI
        int openCount = 0,
            inProgressCount = 0,
            completedCount = 0,
            cancelledCount = 0;
        for (final doc in docs) {
          final data = (doc.data() as Map<String, dynamic>?) ?? {};
          switch (_status(data)) {
            case 'open':
              openCount++;
              break;
            case 'in_progress':
            case 'claimed':
              inProgressCount++;
              break;
            case 'completed':
              completedCount++;
              break;
            case 'cancelled':
              cancelledCount++;
              break;
          }
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          docs = docs.where((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            final service = (data['service'] ?? data['serviceType'] ?? '')
                .toString()
                .toLowerCase();
            final desc = (data['description'] ?? '').toString().toLowerCase();
            final zip = (data['zip'] ?? '').toString().toLowerCase();
            final custName = (data['customerName'] ?? '')
                .toString()
                .toLowerCase();
            return service.contains(q) ||
                desc.contains(q) ||
                zip.contains(q) ||
                custName.contains(q);
          }).toList();
        }

        // Status filter
        if (_statusFilter != 'all') {
          docs = docs.where((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            return _status(data) == _statusFilter;
          }).toList();
        }

        // Claim filter
        if (_claimFilter != 'all') {
          docs = docs.where((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            final claimed = _isClaimed(data);
            return _claimFilter == 'claimed' ? claimed : !claimed;
          }).toList();
        }

        // Sort
        docs.sort((a, b) {
          final dataA = (a.data() as Map<String, dynamic>?) ?? {};
          final dataB = (b.data() as Map<String, dynamic>?) ?? {};
          switch (_sortBy) {
            case 'oldest':
              return (_createdAt(dataA)?.millisecondsSinceEpoch ?? 0).compareTo(
                _createdAt(dataB)?.millisecondsSinceEpoch ?? 0,
              );
            case 'service_az':
              return (dataA['service'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo((dataB['service'] ?? '').toString().toLowerCase());
            case 'service_za':
              return (dataB['service'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo((dataA['service'] ?? '').toString().toLowerCase());
            case 'newest':
            default:
              return (_createdAt(dataB)?.millisecondsSinceEpoch ?? 0).compareTo(
                _createdAt(dataA)?.millisecondsSinceEpoch ?? 0,
              );
          }
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── KPI Cards ──────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpiCard('Total Jobs', '$totalJobs', Icons.work, Colors.blue),
                _kpiCard('Open', '$openCount', Icons.fiber_new, Colors.cyan),
                _kpiCard(
                  'In Progress',
                  '$inProgressCount',
                  Icons.sync,
                  Colors.orange,
                ),
                _kpiCard(
                  'Completed',
                  '$completedCount',
                  Icons.check_circle,
                  Colors.green,
                ),
                _kpiCard(
                  'Cancelled',
                  '$cancelledCount',
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Search bar ─────────────────────────
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by service, description, ZIP, customer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
            const SizedBox(height: 12),

            // ── Filters & sorting ──────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters & sorting',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in [
                          'all',
                          'open',
                          'in_progress',
                          'completed',
                          'cancelled',
                        ])
                          ChoiceChip(
                            label: Text(
                              s == 'all'
                                  ? 'All'
                                  : s == 'in_progress'
                                  ? 'In progress'
                                  : s[0].toUpperCase() + s.substring(1),
                            ),
                            selected: _statusFilter == s,
                            onSelected: (_) =>
                                setState(() => _statusFilter = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in ['all', 'unclaimed', 'claimed'])
                          ChoiceChip(
                            label: Text(
                              c == 'all'
                                  ? 'All claims'
                                  : c[0].toUpperCase() + c.substring(1),
                            ),
                            selected: _claimFilter == c,
                            onSelected: (_) => setState(() => _claimFilter = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text('Newest → Oldest'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Oldest → Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'service_az',
                          child: Text('Service A → Z'),
                        ),
                        DropdownMenuItem(
                          value: 'service_za',
                          child: Text('Service Z → A'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sortBy = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Results count ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Text(
                '${docs.length} job${docs.length == 1 ? '' : 's'} found',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ),

            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No jobs found')),
              ),

            // ── Job cards ──────────────────────────
            ...docs.map((doc) => _buildJobCard(doc)),
          ],
        );
      },
    );
  }

  Widget _buildJobCard(QueryDocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final service = (data['service'] ?? data['serviceType'] ?? 'Service')
        .toString();
    final description = (data['description'] ?? '').toString();
    final status = _status(data);
    final claimed = _isClaimed(data);
    final zip = (data['zip'] ?? '').toString();
    final created = _createdAt(data);
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showJobDetail(doc.id, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (zip.isNotEmpty)
                          Text(
                            '📍 $zip',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        if (created != null)
                          Text(
                            _dateFmt.format(created),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side chips & actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (claimed)
                    Text(
                      'Claimed',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 11,
                      ),
                    ),
                  if (!claimed)
                    Text(
                      'Unclaimed',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              if (widget.canWrite) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AdminColors.error,
                    size: 20,
                  ),
                  tooltip: 'Delete job',
                  onPressed: () => _confirmDelete(doc),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetail(String docId, Map<String, dynamic> data) {
    final service = (data['service'] ?? data['serviceType'] ?? 'Service')
        .toString();
    final description = (data['description'] ?? '').toString();
    final status = _status(data);
    final zip = (data['zip'] ?? '').toString();
    final created = _createdAt(data);
    final customerId = (data['customerId'] ?? '').toString();
    final claimedBy = (data['claimedBy'] ?? '').toString();
    final price = (data['price'] as num?)?.toDouble();
    final aiPrice = (data['aiPrice'] as num?)?.toDouble();
    final photos = data['photos'] as List<dynamic>? ?? [];
    final address = (data['address'] ?? '').toString();
    final notes = (data['notes'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(service)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(
                  color: _statusColor(status),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    'Description',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  Text(description),
                  const SizedBox(height: 12),
                ],
                _detailRow('Job ID', docId),
                _detailRow('ZIP Code', zip),
                if (address.isNotEmpty) _detailRow('Address', address),
                if (created != null)
                  _detailRow('Created', _dateFmt.format(created)),
                if (customerId.isNotEmpty)
                  _detailRow('Customer ID', customerId),
                if (claimedBy.isNotEmpty) _detailRow('Claimed By', claimedBy),
                if (price != null)
                  _detailRow('Price', '\$${price.toStringAsFixed(2)}'),
                if (aiPrice != null)
                  _detailRow('AI Price', '\$${aiPrice.toStringAsFixed(2)}'),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notes', style: Theme.of(ctx).textTheme.labelMedium),
                  Text(notes),
                ],
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Photos (${photos.length})',
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: photos.take(6).map<Widget>((url) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url.toString(),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e2, st2) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.white10,
                            child: const Icon(Icons.broken_image, size: 30),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (widget.canWrite && status != 'cancelled')
            TextButton(
              onPressed: () {
                _updateJobStatus(docId, 'cancelled');
                Navigator.pop(ctx);
              },
              child: const Text(
                'Cancel Job',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _confirmDelete(QueryDocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final service = (data['service'] ?? data['serviceType'] ?? 'Unknown')
        .toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job?'),
        content: Text(
          'Are you sure you want to permanently delete "$service"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.error),
            onPressed: () {
              // Log audit trail
              FirebaseFirestore.instance.collection('admin_audit_log').add({
                'action': 'job_deleted',
                'jobId': doc.id,
                'service': service,
                'deletedAt': FieldValue.serverTimestamp(),
                'deletedBy': 'admin',
              });
              doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Job "$service" deleted')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _updateJobStatus(String docId, String newStatus) {
    FirebaseFirestore.instance.collection('job_requests').doc(docId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Audit trail
    FirebaseFirestore.instance.collection('admin_audit_log').add({
      'action': 'job_status_changed',
      'jobId': docId,
      'newStatus': newStatus,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': 'admin',
    });
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
