import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:admin_web/services/admin_service.dart';

class ContractorAdminTab extends StatefulWidget {
  const ContractorAdminTab({super.key});

  @override
  State<ContractorAdminTab> createState() => _ContractorAdminTabState();
}

class _ContractorAdminTabState extends State<ContractorAdminTab> {
  bool _isRemovingFreeCredits = false;
  String _roleFilter = 'contractor';
  String _sortBy = 'newest';
  bool _showInactive = false;
  final int _pageSize = 25;
  int _pageLimit = 25;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isActiveAccount(Map<String, dynamic> data) {
    final deleted = data['deleted'] == true || data['isDeleted'] == true;
    final disabled = data['disabled'] == true || data['isDisabled'] == true;
    final activeFlag = data['active'];
    if (activeFlag is bool && activeFlag == false) return false;
    if (deleted || disabled) return false;
    final status = (data['status'] as String?)?.trim().toLowerCase();
    if (status == 'deleted' || status == 'disabled' || status == 'inactive') {
      return false;
    }
    return true;
  }

  DateTime? _createdAt(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['created_at'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _displayName(Map<String, dynamic> data) {
    final company = (data['company'] as String?)?.trim();
    final name = (data['name'] as String?)?.trim();
    if (company != null && company.isNotEmpty) return company;
    if (name != null && name.isNotEmpty) return name;
    return 'Unknown';
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final fields = <String?>[
      data['company'] as String?,
      data['businessName'] as String?,
      data['displayName'] as String?,
      data['name'] as String?,
      data['email'] as String?,
    ];
    return fields.any((f) => (f ?? '').toLowerCase().contains(query));
  }

  Future<void> _updateUserWithAudit({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> updates,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    final batch = FirebaseFirestore.instance.batch();

    batch.set(ref, updates, SetOptions(merge: true));

    final payload = <String, dynamic>{
      'action': action,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (adminUid != null) {
      payload['adminUid'] = adminUid;
    }
    if (details != null && details.isNotEmpty) {
      payload['details'] = details;
    }

    batch.set(ref.collection('auditLog').doc(), payload);
    await batch.commit();
  }

  String _csvEscape(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _csvDate(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate().toIso8601String();
    }
    if (raw is DateTime) {
      return raw.toIso8601String();
    }
    return '';
  }

  String _buildCsv(List<QueryDocumentSnapshot<Object?>> docs) {
    final buffer = StringBuffer();
    buffer.writeln(
      'uid,displayName,company,name,email,role,active,credits,lastActiveAt,profileCompletion,verificationStatus,createdAt',
    );

    for (final doc in docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final displayName = _displayName(data);
      final company = (data['company'] as String?)?.trim() ?? '';
      final name = (data['name'] as String?)?.trim() ?? '';
      final email = (data['email'] as String?)?.trim() ?? '';
      final role = (data['role'] as String?)?.trim() ?? '';
      final active = _isActiveAccount(data) ? 'active' : 'inactive';
      final creditsRaw = data['credits'];
      final credits = creditsRaw is num ? creditsRaw.toInt().toString() : '0';
      final lastActive = _csvDate(data['lastActiveAt']);
      final profileCompletion = (data['profileCompletion'] ?? '').toString();
      final verificationStatus =
          (data['verificationStatus'] as String?)?.trim() ?? '';
      final createdAt = _csvDate(data['createdAt'] ?? data['created_at']);

      final row = <String>[
        doc.id,
        displayName,
        company,
        name,
        email,
        role,
        active,
        credits,
        lastActive,
        profileCompletion,
        verificationStatus,
        createdAt,
      ].map(_csvEscape).join(',');
      buffer.writeln(row);
    }

    return buffer.toString();
  }

  Future<void> _exportCsv({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Object?>> docs,
    required bool shareFile,
    required bool copyToClipboard,
  }) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No users to export.')));
      return;
    }

    final csv = _buildCsv(docs);

    if (copyToClipboard || shareFile) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard.')),
        );
      }
    }
  }

  String _formatDateTime(dynamic raw) {
    if (raw is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(raw.toDate());
    }
    if (raw is DateTime) {
      return DateFormat.yMMMd().add_jm().format(raw);
    }
    return 'Unknown';
  }

  String _formatPercent(dynamic raw) {
    if (raw is num) {
      final value = raw > 1 ? raw / 100 : raw;
      final clamped = value.clamp(0, 1).toDouble();
      return '${(clamped * 100).round()}%';
    }
    return 'Unknown';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showGrantCreditsDialog(
    BuildContext context, {
    required String contractorUid,
    required int currentCredits,
  }) async {
    final controller = TextEditingController(text: '5');

    final delta = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Grant lead credits'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current credits: $currentCredits'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Delta (e.g. 5 or -2)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed == 0) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context, parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (delta == null) return;
    try {
      final result = await AdminService().grantLeadCredits(
        targetUid: contractorUid,
        delta: delta,
      );

      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final credits = result['credits'];
      if (credits is num) {
        messenger.showSnackBar(
          SnackBar(content: Text('Updated credits: ${credits.toInt()}')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Credits updated.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _removeFreeSignupCredits() async {
    if (_isRemovingFreeCredits) return;

    setState(() => _isRemovingFreeCredits = true);
    try {
      final dry = await AdminService().removeFreeSignupCredits(
        freeCredits: 3,
        dryRun: true,
      );

      if (!mounted) return;

      final candidates = (dry['candidates'] is num)
          ? (dry['candidates'] as num).toInt()
          : 0;
      final updated = (dry['updated'] is num)
          ? (dry['updated'] as num).toInt()
          : 0;
      final skippedPurchased = (dry['skippedPurchased'] is num)
          ? (dry['skippedPurchased'] as num).toInt()
          : 0;
      final skippedHasLeadCredits = (dry['skippedHasLeadCredits'] is num)
          ? (dry['skippedHasLeadCredits'] as num).toInt()
          : 0;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Remove free signup credits?'),
            content: Text(
              'This will set legacy credits from 3 -> 0 only for contractors who have never purchased a lead pack.\n\n'
              'Dry run summary:\n'
              '- Candidates (role=contractor, credits=3): $candidates\n'
              '- Will update: $updated\n'
              '- Skipped (has purchases): $skippedPurchased\n'
              '- Skipped (already has leadCredits fields): $skippedHasLeadCredits',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      final result = await AdminService().removeFreeSignupCredits(
        freeCredits: 3,
        dryRun: false,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final didUpdate = (result['updated'] is num)
          ? (result['updated'] as num).toInt()
          : 0;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Removed free credits for $didUpdate contractors.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isRemovingFreeCredits = false);
      }
    }
  }

  Future<void> _archiveUser(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> ref,
    required String label,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove from list?'),
          content: Text(
            'This will hide $label by marking it as deleted. You can still show inactive users to restore it later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _updateUserWithAudit(
        ref: ref,
        updates: {'isDeleted': true, 'deletedAt': FieldValue.serverTimestamp()},
        action: 'archive_user',
        details: {'label': label},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to archive user: $e')));
    }
  }

  Future<void> _confirmHardDelete(
    BuildContext context, {
    required String userId,
    required String label,
  }) async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hard delete user?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This permanently deletes $label from Auth and Firestore. Type DELETE to confirm.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text == 'DELETE');
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (confirm != true) return;

    try {
      await AdminService().hardDeleteUser(targetUid: userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User deleted.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hard delete failed: $e')));
    }
  }

  Future<void> _openUserDetailsSheet(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> ref,
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final notesController = TextEditingController();
    var notesDirty = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  final displayName = _displayName(data);
                  final email = (data['email'] as String?)?.trim();
                  final phone = (data['phone'] as String?)?.trim();
                  final role = (data['role'] as String?)?.trim();
                  final lastActive = data['lastActiveAt'];
                  final profileCompletion = data['profileCompletion'];
                  final verificationStatus =
                      (data['verificationStatus'] as String?)?.trim();

                  final notesRef = ref.collection('adminNotes').doc('summary');

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              label: 'Role',
                              value: role?.isNotEmpty == true ? role! : 'N/A',
                            ),
                            _InfoChip(label: 'User ID', value: userId),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Contact',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Email',
                          value: email?.isNotEmpty == true ? email! : 'Unknown',
                        ),
                        _InfoRow(
                          label: 'Phone',
                          value: phone?.isNotEmpty == true ? phone! : 'Unknown',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Activity',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Last active',
                          value: _formatDateTime(lastActive),
                        ),
                        _InfoRow(
                          label: 'Profile completion',
                          value: _formatPercent(profileCompletion),
                        ),
                        _InfoRow(
                          label: 'Verification',
                          value: verificationStatus?.isNotEmpty == true
                              ? verificationStatus!
                              : 'Unknown',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Admin notes',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: notesRef.snapshots(),
                          builder: (context, notesSnap) {
                            final noteText =
                                (notesSnap.data?.data()?['text'] as String?)
                                    ?.trim() ??
                                '';
                            if (!notesDirty &&
                                noteText != notesController.text) {
                              notesController.text = noteText;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: notesController,
                                  minLines: 3,
                                  maxLines: 6,
                                  onChanged: (_) {
                                    if (!notesDirty) {
                                      setSheetState(() => notesDirty = true);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Add internal notes...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: () async {
                                      final text = notesController.text.trim();
                                      final adminUid = FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid;
                                      final update = <String, dynamic>{
                                        'text': text,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      };
                                      if (adminUid != null) {
                                        update['updatedBy'] = adminUid;
                                      }
                                      await notesRef.set(
                                        update,
                                        SetOptions(merge: true),
                                      );

                                      setSheetState(() => notesDirty = false);
                                    },
                                    child: const Text('Save notes'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Recent activity',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: ref
                              .collection('auditLog')
                              .orderBy('createdAt', descending: true)
                              .limit(5)
                              .snapshots(),
                          builder: (context, logSnap) {
                            if (!logSnap.hasData ||
                                logSnap.data!.docs.isEmpty) {
                              return Text(
                                'No recent activity logged.',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }

                            return Column(
                              children: logSnap.data!.docs.map((entry) {
                                final entryData = entry.data();
                                final action = (entryData['action'] as String?)
                                    ?.trim();
                                final actor = (entryData['adminUid'] as String?)
                                    ?.trim();
                                final createdAt = entryData['createdAt'];

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(action ?? 'Activity'),
                                  subtitle: Text(
                                    '${_formatDateTime(createdAt)} • ${actor ?? 'unknown'}',
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseQuery = (_roleFilter == 'all')
        ? FirebaseFirestore.instance.collection('users')
        : FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: _roleFilter);
    final stream = baseQuery.limit(_pageLimit).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading contractors:\n\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snap.data!.docs.toList();
        var docs = allDocs;
        if (!_showInactive) {
          docs = docs.where((doc) {
            final data =
                (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
            return _isActiveAccount(data);
          }).toList();
        }

        docs = docs.where((doc) {
          final data =
              (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          return _matchesSearch(data);
        }).toList();

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
            case 'name_az':
              return _displayName(
                dataA,
              ).toLowerCase().compareTo(_displayName(dataB).toLowerCase());
            case 'name_za':
              return _displayName(
                dataB,
              ).toLowerCase().compareTo(_displayName(dataA).toLowerCase());
            case 'credits_most':
              final creditsA = (dataA['credits'] is num)
                  ? (dataA['credits'] as num).toInt()
                  : 0;
              final creditsB = (dataB['credits'] is num)
                  ? (dataB['credits'] as num).toInt()
                  : 0;
              return creditsB.compareTo(creditsA);
            case 'credits_least':
              final creditsA = (dataA['credits'] is num)
                  ? (dataA['credits'] as num).toInt()
                  : 0;
              final creditsB = (dataB['credits'] is num)
                  ? (dataB['credits'] as num).toInt()
                  : 0;
              return creditsA.compareTo(creditsB);
            case 'newest':
            default:
              final aCreated = _createdAt(dataA)?.millisecondsSinceEpoch ?? 0;
              final bCreated = _createdAt(dataB)?.millisecondsSinceEpoch ?? 0;
              return bCreated.compareTo(aCreated);
          }
        });

        final totalCount = allDocs.length;
        final activeCount = allDocs.where((doc) {
          final data =
              (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
          return _isActiveAccount(data);
        }).length;
        final inactiveCount = totalCount - activeCount;
        final canLoadMore = allDocs.length >= _pageLimit;

        if (docs.isEmpty) {
          return const Center(child: Text('No matching users found'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Users',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            _AdminStatChip(label: 'Total', value: totalCount),
                            _AdminStatChip(label: 'Active', value: activeCount),
                            _AdminStatChip(
                              label: 'Inactive',
                              value: inactiveCount,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search name, company, or email',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Contractors'),
                          selected: _roleFilter == 'contractor',
                          onSelected: (_) {
                            setState(() {
                              _roleFilter = 'contractor';
                              _pageLimit = _pageSize;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Customers'),
                          selected: _roleFilter == 'customer',
                          onSelected: (_) {
                            setState(() {
                              _roleFilter = 'customer';
                              _pageLimit = _pageSize;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _roleFilter == 'all',
                          onSelected: (_) {
                            setState(() {
                              _roleFilter = 'all';
                              _pageLimit = _pageSize;
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Show inactive'),
                          selected: _showInactive,
                          onSelected: (value) {
                            setState(() => _showInactive = value);
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
                          child: Text('Newest -> Oldest'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Oldest -> Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'name_az',
                          child: Text('Name A -> Z'),
                        ),
                        DropdownMenuItem(
                          value: 'name_za',
                          child: Text('Name Z -> A'),
                        ),
                        DropdownMenuItem(
                          value: 'credits_most',
                          child: Text('Most credits'),
                        ),
                        DropdownMenuItem(
                          value: 'credits_least',
                          child: Text('Least credits'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sortBy = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _exportCsv(
                            context: context,
                            docs: docs,
                            shareFile: true,
                            copyToClipboard: false,
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _exportCsv(
                            context: context,
                            docs: docs,
                            shareFile: false,
                            copyToClipboard: true,
                          ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy CSV'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Credits maintenance'),
                subtitle: const Text(
                  'Remove legacy free signup credits (3) only when the contractor has never purchased a lead pack.',
                ),
                trailing: _isRemovingFreeCredits
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton.icon(
                        onPressed: _removeFreeSignupCredits,
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Run'),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            ...docs.map((doc) {
              final data =
                  (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

              final company = (data['company'] as String?)?.trim();
              final name = (data['name'] as String?)?.trim();
              final approved = data['approved'] == true;
              final featured = data['featured'] == true;
              final creditsRaw = data['credits'];
              final credits = creditsRaw is num ? creditsRaw.toInt() : 0;
              final role = (data['role'] as String?)?.trim() ?? '';
              final isContractor = role == 'contractor';
              final active = _isActiveAccount(data);

              final initials = _displayName(data).trim();

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      initials.isNotEmpty ? initials[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    (company == null || company.isEmpty) ? 'Unknown' : company,
                  ),
                  subtitle: Text(
                    [
                      if ((name ?? '').isNotEmpty) name,
                      if (role.isNotEmpty) role,
                      if (!active) 'inactive',
                    ].whereType<String>().join(' • '),
                  ),
                  onTap: () => _openUserDetailsSheet(
                    context,
                    ref:
                        doc.reference
                            as DocumentReference<Map<String, dynamic>>,
                    userId: doc.id,
                    data: data,
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'C: $credits',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        onSelected: (value) {
                          switch (value) {
                            case 'credits':
                              _showGrantCreditsDialog(
                                context,
                                contractorUid: doc.id,
                                currentCredits: credits,
                              );
                              break;
                            case 'approved':
                              _updateUserWithAudit(
                                ref:
                                    doc.reference
                                        as DocumentReference<
                                          Map<String, dynamic>
                                        >,
                                updates: {'approved': !approved},
                                action: approved
                                    ? 'revoke_approval'
                                    : 'approve_contractor',
                                details: {
                                  'previous': approved,
                                  'next': !approved,
                                },
                              );
                              break;
                            case 'featured':
                              _updateUserWithAudit(
                                ref:
                                    doc.reference
                                        as DocumentReference<
                                          Map<String, dynamic>
                                        >,
                                updates: {'featured': !featured},
                                action: featured
                                    ? 'unfeature_contractor'
                                    : 'feature_contractor',
                                details: {
                                  'previous': featured,
                                  'next': !featured,
                                },
                              );
                              break;
                            case 'archive':
                              _archiveUser(
                                context,
                                ref:
                                    doc.reference
                                        as DocumentReference<
                                          Map<String, dynamic>
                                        >,
                                label: _displayName(data),
                              );
                              break;
                            case 'hard_delete':
                              _confirmHardDelete(
                                context,
                                userId: doc.id,
                                label: _displayName(data),
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (isContractor)
                            const PopupMenuItem(
                              value: 'credits',
                              child: Text('Grant credits'),
                            ),
                          if (isContractor)
                            PopupMenuItem(
                              value: 'approved',
                              child: Text(
                                approved
                                    ? 'Revoke approval'
                                    : 'Approve contractor',
                              ),
                            ),
                          if (isContractor)
                            PopupMenuItem(
                              value: 'featured',
                              child: Text(
                                featured ? 'Unfeature' : 'Feature contractor',
                              ),
                            ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Remove from list'),
                          ),
                          const PopupMenuItem(
                            value: 'hard_delete',
                            child: Text('Hard delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (canLoadMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _pageLimit += _pageSize);
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AdminStatChip extends StatelessWidget {
  const _AdminStatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}
