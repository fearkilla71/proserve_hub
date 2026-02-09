import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'job_detail_page.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment History')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Payments'),
              Tab(text: 'Escrow'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PaymentsTab(uid: user.uid),
            _EscrowTab(uid: user.uid),
          ],
        ),
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final String uid;

  const _PaymentsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PaymentsSection(
          title: 'As Customer',
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('customerId', isEqualTo: uid)
              .snapshots(),
          emptyText: 'No customer payments yet.',
        ),
        const SizedBox(height: 16),
        _PaymentsSection(
          title: 'As Contractor',
          stream: FirebaseFirestore.instance
              .collection('payments')
              .where('contractorId', isEqualTo: uid)
              .snapshots(),
          emptyText: 'No contractor payments yet.',
        ),
      ],
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;

  const _PaymentsSection({
    required this.title,
    required this.stream,
    required this.emptyText,
  });

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    }
    return '';
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'tip':
        return Icons.thumb_up;
      case 'escrow':
        return Icons.lock;
      default:
        return Icons.payments;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading payments');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final ad = a.data();
                  final bd = b.data();
                  final at = ad['createdAt'];
                  final bt = bd['createdAt'];
                  final aMs = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                  final bMs = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                  return bMs.compareTo(aMs);
                });

                if (docs.isEmpty) {
                  return Text(emptyText);
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final type = (data['type'] ?? 'payment').toString();
                    final status = (data['status'] ?? 'unknown').toString();
                    final jobId = (data['jobId'] ?? '').toString();
                    final amountRaw = data['amount'];
                    final amount = amountRaw is num ? amountRaw.toDouble() : 0;
                    final createdAt = _formatTimestamp(data['createdAt']);

                    final subtitleParts = <String>[];
                    subtitleParts.add('Status: $status');
                    if (jobId.trim().isNotEmpty) {
                      subtitleParts.add('Job: $jobId');
                    }
                    if (createdAt.isNotEmpty) {
                      subtitleParts.add('Created: $createdAt');
                    }

                    return ListTile(
                      leading: Icon(_iconForType(type)),
                      title: Text(
                        '${type.toUpperCase()} • \$${amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(subtitleParts.join('\n')),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EscrowTab extends StatelessWidget {
  final String uid;

  const _EscrowTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _EscrowJobsSection(
          title: 'My Jobs (Customer)',
          stream: FirebaseFirestore.instance
              .collection('job_requests')
              .where('requesterUid', isEqualTo: uid)
              .snapshots(),
          emptyText: 'No funded or completed jobs yet.',
        ),
        const SizedBox(height: 16),
        _EscrowJobsSection(
          title: 'My Jobs (Contractor)',
          stream: FirebaseFirestore.instance
              .collection('job_requests')
              .where('claimedBy', isEqualTo: uid)
              .snapshots(),
          emptyText: 'No funded or completed jobs yet.',
        ),
      ],
    );
  }
}

class _EscrowJobsSection extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;

  const _EscrowJobsSection({
    required this.title,
    required this.stream,
    required this.emptyText,
  });

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat.yMMMd().add_jm().format(ts.toDate());
    }
    return '';
  }

  bool _isEscrowRelevant(Map<String, dynamic> job) {
    final escrowStatus =
        (job['escrowStatus'] as String?)?.trim().toLowerCase() ?? '';
    if (escrowStatus == 'funded' || escrowStatus == 'released') {
      return true;
    }
    if (job['fundedAt'] is Timestamp) {
      return true;
    }
    if ((job['paymentIntentId'] as String?)?.trim().isNotEmpty == true) {
      return true;
    }
    return false;
  }

  Widget? _escrowChip(BuildContext context, Map<String, dynamic> job) {
    final escrowStatus =
        (job['escrowStatus'] as String?)?.trim().toLowerCase() ?? '';
    final disputeStatus = (job['disputeStatus'] as String?)?.trim() ?? '';
    final hasDispute = disputeStatus.isNotEmpty;

    if (escrowStatus == 'frozen' || hasDispute) {
      return Chip(
        label: const Text('Escrow frozen'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (escrowStatus == 'released') {
      return Chip(
        label: const Text('Paid out'),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (escrowStatus == 'funded' || job['fundedAt'] is Timestamp) {
      return Chip(
        label: const Text('Funds secured'),
        avatar: Icon(
          Icons.check,
          size: 18,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading jobs');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final ad = a.data();
                  final bd = b.data();
                  final at = ad['createdAt'];
                  final bt = bd['createdAt'];
                  final aMs = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                  final bMs = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                  return bMs.compareTo(aMs);
                });

                final relevant = docs
                    .where((d) => _isEscrowRelevant(d.data()))
                    .toList();
                if (relevant.isEmpty) {
                  return Text(emptyText);
                }

                return Column(
                  children: relevant.map((doc) {
                    final data = doc.data();
                    final status = (data['status'] ?? '').toString();
                    final escrowStatus = (data['escrowStatus'] ?? '')
                        .toString();
                    final service = (data['service'] ?? 'Service').toString();
                    final priceRaw = data['price'];
                    final price = priceRaw is num ? priceRaw.toDouble() : 0;
                    final fundedAt = _formatTimestamp(data['fundedAt']);
                    final completedAt = _formatTimestamp(data['completedAt']);

                    final chip = _escrowChip(context, data);

                    final subtitleParts = <String>[];
                    if (status.trim().isNotEmpty) {
                      subtitleParts.add('Status: $status');
                    }
                    if (escrowStatus.trim().isNotEmpty) {
                      subtitleParts.add('Escrow: $escrowStatus');
                    }
                    subtitleParts.add('Protected by ProServe Hub escrow');
                    if (fundedAt.isNotEmpty) {
                      subtitleParts.add('Funded: $fundedAt');
                    }
                    if (completedAt.isNotEmpty) {
                      subtitleParts.add('Completed: $completedAt');
                    }

                    return ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text('$service • \$${price.toStringAsFixed(0)}'),
                      subtitle: Text(subtitleParts.join('\n')),
                      trailing: chip,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                JobDetailPage(jobId: doc.id, jobData: data),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
