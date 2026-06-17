import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('job_requests').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.errorLoadingJobs(snap.error.toString()),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data!.docs.toList();
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
          return Center(child: Text(l10n.noJobsFound));
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
                      l10n.filtersAndSorting,
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
                          label: Text(l10n.all),
                          selected: _statusFilter == 'all',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'all');
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.open),
                          selected: _statusFilter == 'open',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'open');
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.inProgress),
                          selected: _statusFilter == 'in_progress',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'in_progress');
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.completed),
                          selected: _statusFilter == 'completed',
                          onSelected: (_) {
                            setState(() => _statusFilter = 'completed');
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.cancelled),
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
                          label: Text(l10n.allClaims),
                          selected: _claimFilter == 'all',
                          onSelected: (_) {
                            setState(() => _claimFilter = 'all');
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.unclaimed),
                          selected: _claimFilter == 'unclaimed',
                          onSelected: (_) {
                            setState(() => _claimFilter = 'unclaimed');
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.claimed),
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
                      decoration: InputDecoration(
                        labelText: l10n.sortBy,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text(l10n.newestToOldest),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text(l10n.oldestToNewest),
                        ),
                        DropdownMenuItem(
                          value: 'service_az',
                          child: Text(l10n.serviceAToZ),
                        ),
                        DropdownMenuItem(
                          value: 'service_za',
                          child: Text(l10n.serviceZToA),
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

              final service = data['service'] ?? l10n.service;
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
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.deleteJobQuestion),
                              content: Text(l10n.deleteJobPermanentWarning),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.cancel),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            doc.reference.delete();
                          }
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
