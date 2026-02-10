import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';

class VerificationAdminTab extends StatefulWidget {
  const VerificationAdminTab({super.key});

  @override
  State<VerificationAdminTab> createState() => _VerificationAdminTabState();
}

class _VerificationAdminTabState extends State<VerificationAdminTab> {
  String _typeFilter = 'all';
  String _statusFilter = 'pending';
  String _sortBy = 'newest';

  Map<String, dynamic>? _verificationFor(
    Map<String, dynamic> contractor,
    String type,
  ) {
    return contractor[type] as Map<String, dynamic>?;
  }

  DateTime? _submittedAt(Map<String, dynamic>? verification) {
    final raw = verification?['submittedAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  Iterable<String> _types() sync* {
    yield 'idVerification';
    yield 'licenseVerification';
    yield 'insuranceVerification';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'idVerification':
        return 'ID Verification';
      case 'licenseVerification':
        return 'License Verification';
      case 'insuranceVerification':
        return 'Insurance Verification';
      default:
        return type;
    }
  }

  Future<void> _approveVerification(
    BuildContext context,
    String contractorId,
    String type,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .update({
            '$type.status': 'approved',
            '$type.approvedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Verification approved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectVerification(
    BuildContext context,
    String contractorId,
    String type,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .update({
            '$type.status': 'rejected',
            '$type.rejectedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Verification rejected')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('contractors').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading verifications:\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var contractors = snapshot.data!.docs.toList();
        contractors = contractors.where((doc) {
          final contractor = doc.data() as Map<String, dynamic>;
          final types = _typeFilter == 'all' ? _types() : <String>[_typeFilter];

          for (final type in types) {
            final verification = _verificationFor(contractor, type);
            final status = (verification?['status'] as String?)
                ?.trim()
                .toLowerCase();
            if (_statusFilter == 'all') {
              if (status != null && status.isNotEmpty) return true;
              continue;
            }
            if (status == _statusFilter) return true;
          }
          return false;
        }).toList();

        contractors.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          DateTime? pickSubmitted(Map<String, dynamic> data) {
            final types = _typeFilter == 'all'
                ? _types()
                : <String>[_typeFilter];
            final dates = types
                .map((type) => _submittedAt(_verificationFor(data, type)))
                .whereType<DateTime>()
                .toList();
            if (dates.isEmpty) return null;
            dates.sort();
            return dates.last;
          }

          switch (_sortBy) {
            case 'oldest':
              final aMs = pickSubmitted(dataA)?.millisecondsSinceEpoch ?? 0;
              final bMs = pickSubmitted(dataB)?.millisecondsSinceEpoch ?? 0;
              return aMs.compareTo(bMs);
            case 'name_az':
              return (dataA['businessName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo(
                    (dataB['businessName'] ?? '').toString().toLowerCase(),
                  );
            case 'name_za':
              return (dataB['businessName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo(
                    (dataA['businessName'] ?? '').toString().toLowerCase(),
                  );
            case 'newest':
            default:
              final aMs = pickSubmitted(dataA)?.millisecondsSinceEpoch ?? 0;
              final bMs = pickSubmitted(dataB)?.millisecondsSinceEpoch ?? 0;
              return bMs.compareTo(aMs);
          }
        });

        if (contractors.isEmpty) {
          return const Center(child: Text('No matching verifications'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: contractors.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
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
                            label: const Text('All types'),
                            selected: _typeFilter == 'all',
                            onSelected: (_) {
                              setState(() => _typeFilter = 'all');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('ID'),
                            selected: _typeFilter == 'idVerification',
                            onSelected: (_) {
                              setState(() => _typeFilter = 'idVerification');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('License'),
                            selected: _typeFilter == 'licenseVerification',
                            onSelected: (_) {
                              setState(
                                () => _typeFilter = 'licenseVerification',
                              );
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Insurance'),
                            selected: _typeFilter == 'insuranceVerification',
                            onSelected: (_) {
                              setState(
                                () => _typeFilter = 'insuranceVerification',
                              );
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
                            label: const Text('Pending'),
                            selected: _statusFilter == 'pending',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'pending');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Approved'),
                            selected: _statusFilter == 'approved',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'approved');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Rejected'),
                            selected: _statusFilter == 'rejected',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'rejected');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('All status'),
                            selected: _statusFilter == 'all',
                            onSelected: (_) {
                              setState(() => _statusFilter = 'all');
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
                            value: 'name_az',
                            child: Text('Name A → Z'),
                          ),
                          DropdownMenuItem(
                            value: 'name_za',
                            child: Text('Name Z → A'),
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
              );
            }

            final contractor =
                contractors[index - 1].data() as Map<String, dynamic>;
            final contractorId = contractors[index - 1].id;
            final businessName = contractor['businessName'] ?? 'Unknown';

            final types = _typeFilter == 'all'
                ? _types()
                : <String>[_typeFilter];

            final sections = <Widget>[];
            for (final type in types) {
              final verification = _verificationFor(contractor, type);
              final status = (verification?['status'] as String?)
                  ?.trim()
                  .toLowerCase();
              if (_statusFilter != 'all' && status != _statusFilter) {
                continue;
              }

              if (verification == null) continue;

              if (type == 'idVerification') {
                sections.addAll([
                  const Divider(),
                  ListTile(
                    title: Text(_typeLabel(type)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submitted: ${_formatDate(verification['submittedAt'])}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildImagePreview(
                                context,
                                'Front',
                                verification['frontUrl'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildImagePreview(
                                context,
                                'Back',
                                verification['backUrl'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]);
              } else if (type == 'licenseVerification') {
                sections.addAll([
                  const Divider(),
                  ListTile(
                    title: Text(_typeLabel(type)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'License #: ${verification['licenseNumber'] ?? 'N/A'}',
                        ),
                        Text('Expires: ${verification['expiryDate'] ?? 'N/A'}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildImagePreview(
                                context,
                                'Front',
                                verification['frontUrl'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildImagePreview(
                                context,
                                'Back',
                                verification['backUrl'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]);
              } else if (type == 'insuranceVerification') {
                sections.addAll([
                  const Divider(),
                  ListTile(
                    title: Text(_typeLabel(type)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Provider: ${verification['provider'] ?? 'N/A'}'),
                        Text(
                          'Policy #: ${verification['policyNumber'] ?? 'N/A'}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildImagePreview(
                                context,
                                'Front',
                                verification['frontUrl'],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildImagePreview(
                                context,
                                'Back',
                                verification['backUrl'],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]);
              }

              sections.add(
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminColors.error,
                          ),
                          onPressed: () =>
                              _rejectVerification(context, contractorId, type),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          onPressed: () =>
                              _approveVerification(context, contractorId, type),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (sections.isEmpty) {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: CircleAvatar(child: Text(businessName[0])),
                title: Text(businessName),
                subtitle: Text('Contractor ID: $contractorId'),
                children: sections,
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return DateFormat.yMMMd().format(value.toDate());
    }
    if (value is DateTime) {
      return DateFormat.yMMMd().format(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return 'Unknown';
  }

  Widget _buildImagePreview(BuildContext context, String label, String? url) {
    if (url == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _showFullImage(context, url),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.lineStrong),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) =>
          Dialog(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}
