import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: _PaymentsTab(uid: user.uid),
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
