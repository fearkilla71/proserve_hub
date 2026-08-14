import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/marketplace_models.dart';
import '../utils/app_error_handler.dart';
import '../utils/bottom_sheet_helper.dart';
import '../utils/optimistic_ui.dart';
import '../widgets/skeleton_loader.dart';

class BidsListScreen extends StatelessWidget {
  final String jobId;

  const BidsListScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.bidsSignInRequired)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.compareBids)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bids')
            .where('jobId', isEqualTo: jobId)
            // Required for common security rules patterns (only allow a
            // customer to query their own bids).
            .where('customerId', isEqualTo: uid)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                AppError.message(snapshot.error, action: 'load bids'),
              ),
            );
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.request_quote_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.noBidsYet),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noBidsYetSubtitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720 ? 2 : 1;

              if (crossAxisCount == 1) {
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: bids.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _BidCard(bid: bids[index], jobId: jobId),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: bids.length,
                itemBuilder: (context, index) =>
                    _BidCard(bid: bids[index], jobId: jobId),
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
    final l10n = AppLocalizations.of(context)!;
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
                              (data?['completedJobs'] as num?)?.toInt() ??
                              (data?['totalJobsCompleted'] as num?)?.toInt() ??
                              0;

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
                              Text(l10n.completedJobsCount(completedJobs)),
                              Text(l10n.etaDays(bid.estimatedDays)),
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
                      label: Text(l10n.reject),
                      onPressed: () => _updateBidStatus(context, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: Text(l10n.counter),
                      onPressed: () => _showCounterOfferDialog(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(l10n.accept),
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
                label: Text(l10n.viewCounterOffer),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.bidStatusUpdated(status),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      }
    }
  }

  Future<void> _acceptBid(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await BottomSheetHelper.showConfirmation(
      context: context,
      title: l10n.acceptBid,
      message: l10n.acceptBidMessage(
        '\$${bid.amount.toStringAsFixed(2)}',
        bid.contractorName,
      ),
      confirmText: l10n.accept,
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
      loadingMessage: l10n.acceptingBid,
      successMessage: l10n.bidAcceptedJobAssigned,
      onSuccess: () {
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _showCounterOfferDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController(text: bid.amount.toString());
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.counterOffer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: l10n.amount,
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: l10n.messageOptional),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, {
                'amount': double.tryParse(amountController.text) ?? bid.amount,
                'description': descriptionController.text.trim(),
              });
            },
            child: Text(l10n.send),
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
            : l10n.counterOfferDefaultDescription,
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
        ).showSnackBar(SnackBar(content: Text(l10n.counterOfferSent)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      }
    }
  }
}
