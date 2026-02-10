import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

class JobAdminTab extends StatefulWidget {
  const JobAdminTab({super.key});

  @override
  State<JobAdminTab> createState() => _JobAdminTabState();
}

class _JobAdminTabState extends State<JobAdminTab> {
  String _statusFilter = 'all';
  String _claimFilter = 'all';
  String _sortBy = 'newest';

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('job_requests').snapshots(),
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
          return const Center(child: CircularProgressIndicator());
        }

        var docs = List<QueryDocumentSnapshot>.of(snap.data!.docs);
        if (_statusFilter != 'all') {
          docs = docs.where((doc) {
            final data =
                (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
            return _status(data) == _statusFilter;
          }).toList();
        }

        if (_claimFilter != 'all') {
          docs = docs.where((doc) {
            final data =
                (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
            final claimed = _isClaimed(data);
            return _claimFilter == 'claimed' ? claimed : !claimed;
          }).toList();
        }

        docs.sort((a, b) {
          final dataA =
              (a.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          final dataB =
              (b.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

          switch (_sortBy) {
            case 'oldest':
              final aCreated = _createdAt(dataA)?.millisecondsSinceEpoch ?? 0;
              final bCreated = _createdAt(dataB)?.millisecondsSinceEpoch ?? 0;
              return aCreated.compareTo(bCreated);
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
              final aCreated = _createdAt(dataA)?.millisecondsSinceEpoch ?? 0;
              final bCreated = _createdAt(dataB)?.millisecondsSinceEpoch ?? 0;
              return bCreated.compareTo(aCreated);
          }
        });

        if (docs.isEmpty) {
          return const Center(child: Text('No jobs found'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
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
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _statusFilter == 'all',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'all');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Open'),
                          selected: _statusFilter == 'open',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'open');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('In progress'),
                          selected: _statusFilter == 'in_progress',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'in_progress');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Completed'),
                          selected: _statusFilter == 'completed',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'completed');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Cancelled'),
                          selected: _statusFilter == 'cancelled',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'cancelled');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All claims'),
                          selected: _claimFilter == 'all',
                          onSelected: (_) {
                            setState(() => _claimFilter = 'all');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Unclaimed'),
                          selected: _claimFilter == 'unclaimed',
                          onSelected: (_) {
                            setState(() => _claimFilter = 'unclaimed');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Claimed'),
                          selected: _claimFilter == 'claimed',
                          onSelected: (_) {
                            setState(() => _claimFilter = 'claimed');
                          },
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
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sortBy = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...docs.map((doc) {
              final data =
                  (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

              final service = data['service'] ?? 'Service';
              final description = data['description'] ?? '';
              final status = _status(data).toUpperCase();

              return Card(
                child: ListTile(
                  title: Text(service.toString()),
                  subtitle: Text(description.toString()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            status,
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: AdminColors.error,
                        ),
                        onPressed: () {
                          doc.reference.delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
