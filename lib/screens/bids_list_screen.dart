import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/marketplace_models.dart';
import '../utils/bottom_sheet_helper.dart';
import '../utils/optimistic_ui.dart';
import '../widgets/skeleton_loader.dart';

class BidsListScreen extends StatelessWidget {
  final String jobId;

  const BidsListScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view bids.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Bids')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bids')
            .where('jobId', isEqualTo: jobId)
            // Required for common security rules patterns (only allow a
            // customer to query their own bids).
            .where('customerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 720 ? 2 : 1;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: crossAxisCount == 1 ? 1.15 : 1.3,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) => const BidCardSkeleton(),
                );
              },
            );
          }

          final docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            Timestamp ts(dynamic v) {
              if (v is Timestamp) return v;
              return Timestamp(0, 0);
            }

            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTs = ts(aData?['createdAt']);
            final bTs = ts(bData?['createdAt']);
            return bTs.compareTo(aTs); // descending
          });

          final bids = docs.map((doc) => Bid.fromFirestore(doc)).toList();

          if (bids.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.request_quote_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text('No bids yet'),
                  SizedBox(height: 8),
                  Text(
                    'Contractors will submit bids soon',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720 ? 2 : 1;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: crossAxisCount == 1 ? 1.15 : 1.3,
                ),
                itemCount: bids.length,
                itemBuilder: (context, index) {
                  final bid = bids[index];
                  return _BidCard(bid: bid, jobId: jobId);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final Bid bid;
  final String jobId;

  const _BidCard({required this.bid, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    Color statusColor;
    IconData statusIcon;
    switch (bid.status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'countered':
        statusColor = Colors.orange;
        statusIcon = Icons.sync_alt;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.contractorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            bid.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('contractors')
                            .doc(bid.contractorId)
                            .get(),
                        builder: (context, snap) {
                          final data =
                              snap.data?.data() as Map<String, dynamic>?;
                          final rating =
                              (data?['averageRating'] as num?)?.toDouble() ??
                              (data?['avgRating'] as num?)?.toDouble() ??
                              0.0;
                          final completedJobs =
                              (data?['completedJobs'] as num?)?.toInt() ?? 0;

                          return Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(rating.toStringAsFixed(1)),
                                ],
                              ),
                              Text('$completedJobs completed'),
                              Text('ETA: ${bid.estimatedDays} days'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '\$${bid.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(bid.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${bid.estimatedDays} days',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat.MMMd().format(bid.createdAt),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            if (user?.uid == bid.customerId && bid.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject'),
                      onPressed: () => _updateBidStatus(context, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Counter'),
                      onPressed: () => _showCounterOfferDialog(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                      onPressed: () => _acceptBid(context),
                    ),
                  ),
                ],
              ),
            ],
            if (bid.counterOfferId != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text('View counter offer'),
                onPressed: () {
                  // Navigate to counter offer
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateBidStatus(BuildContext context, String status) async {
    try {
      await FirebaseFirestore.instance.collection('bids').doc(bid.id).update({
        'status': status,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bid $status')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _acceptBid(BuildContext context) async {
    final confirmed = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Accept Bid',
      message:
          'Accept bid for \$${bid.amount.toStringAsFixed(2)}?\n\nThis will assign the job to ${bid.contractorName}.',
      confirmText: 'Accept',
    );

    if (!confirmed || !context.mounted) return;

    await OptimisticUI.executeWithOptimism(
      context: context,
      action: () async {
        final batch = FirebaseFirestore.instance.batch();

        // Update bid status.
        batch.update(
          FirebaseFirestore.instance.collection('bids').doc(bid.id),
          {'status': 'accepted'},
        );

        // Reject other bids.
        final otherBids = await FirebaseFirestore.instance
            .collection('bids')
            .where('jobId', isEqualTo: jobId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in otherBids.docs) {
          if (doc.id != bid.id) {
            batch.update(doc.reference, {'status': 'rejected'});
          }
        }

        // Update job.
        batch.update(
          FirebaseFirestore.instance.collection('job_requests').doc(jobId),
          {
            'claimed': true,
            'claimedBy': bid.contractorId,
            'status': 'accepted',
            'acceptedBidId': bid.id,
          },
        );

        await batch.commit();
      },
      loadingMessage: 'Accepting bid...',
      successMessage: 'Bid accepted! Job assigned.',
      onSuccess: () {
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _showCounterOfferDialog(BuildContext context) async {
    final amountController = TextEditingController(text: bid.amount.toString());
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Counter Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
              ),
              maxLines: 3,
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
              Navigator.pop(context, {
                'amount': double.tryParse(amountController.text) ?? bid.amount,
                'description': descriptionController.text.trim(),
              });
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      final jobDoc = await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(jobId)
          .get();

      final jobData = jobDoc.data() ?? {};
      final jobStatusSnapshot = {
        'status': jobData['status'],
        'service': jobData['service'],
        'location': jobData['location'],
        'createdAt': jobData['createdAt'],
      };

      // Create counter offer bid
      await FirebaseFirestore.instance.collection('bids').add({
        'jobId': jobId,
        'contractorId': bid.contractorId,
        'contractorName': bid.contractorName,
        'customerId': bid.customerId,
        'jobStatusSnapshot': jobStatusSnapshot,
        'amount': result['amount'],
        'currency': 'USD',
        'description': result['description'].isNotEmpty
            ? result['description']
            : 'Counter offer to original bid',
        'estimatedDays': bid.estimatedDays,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });

      // Mark original as countered
      await FirebaseFirestore.instance.collection('bids').doc(bid.id).update({
        'status': 'countered',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Counter offer sent')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
