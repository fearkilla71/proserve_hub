import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proserve_hub/services/job_claim_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:proserve_hub/services/lead_service.dart';
import 'package:proserve_hub/services/stripe_service.dart';

import 'submit_review_screen.dart';
import 'bids_list_screen.dart';
import 'chat_screen.dart';
import 'job_status_screen.dart';
import 'add_tip_screen.dart';
import 'invoice_screen.dart';
import 'dispute_screen.dart';
import 'quotes_screen.dart';
import 'project_milestones_screen.dart';
import 'progress_photos_screen.dart';
import 'project_timeline_screen.dart';
import '../services/conversation_service.dart';
import 'expenses/expenses_list_page.dart';
import '../utils/optimistic_ui.dart';
import '../utils/bottom_sheet_helper.dart';
import 'cancellation_screen.dart';
import '../widgets/suggested_pros_card.dart';

class JobDetailPage extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic>? jobData;

  const JobDetailPage({super.key, required this.jobId, this.jobData});

  Future<void> _openChatFromJobDetail({
    required BuildContext context,
    required String requesterUid,
    required String claimedBy,
    required bool isRequester,
  }) async {
    final otherUserId = isRequester ? claimedBy : requesterUid;
    if (otherUserId.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    String otherUserName = isRequester ? 'Contractor' : 'Client';
    try {
      if (isRequester) {
        // Customer -> Contractor
        // Prefer name stored on the job doc (set during claim), otherwise use
        // the public-ish contractor profile (readable by signed-in users).
        final jobDoc = await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(jobId)
            .get();
        final claimedByName = (jobDoc.data()?['claimedByName'] as String?)
            ?.trim();
        if (claimedByName != null && claimedByName.isNotEmpty) {
          otherUserName = claimedByName;
        } else {
          final contractorDoc = await FirebaseFirestore.instance
              .collection('contractors')
              .doc(otherUserId)
              .get();
          final contractorName =
              (contractorDoc.data()?['name'] as String?)?.trim() ??
              (contractorDoc.data()?['displayName'] as String?)?.trim();
          if (contractorName != null && contractorName.isNotEmpty) {
            otherUserName = contractorName;
          }
        }
      } else {
        // Contractor -> Customer
        // Use the job private contact name (allowed once claimed/unlocked);
        // do NOT read /users/{uid} (blocked by rules).
        try {
          final contactDoc = await FirebaseFirestore.instance
              .collection('job_requests')
              .doc(jobId)
              .collection('private')
              .doc('contact')
              .get();
          final contactName = (contactDoc.data()?['name'] as String?)?.trim();
          if (contactName != null && contactName.isNotEmpty) {
            otherUserName = contactName;
          }
        } catch (_) {
          // If rules block contact details (lead not unlocked/claimed yet),
          // still allow opening chat with a generic display name.
        }
      }

      final conversationId = await ConversationService.getOrCreateConversation(
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        jobId: jobId,
      );

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            jobId: jobId,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open chat: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _openLatestDispute(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('disputes')
          .where('jobId', isEqualTo: jobId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No dispute found for this job.')),
        );
        return;
      }

      final disputeId = snap.docs.first.id;
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DisputeDetailScreen(disputeId: disputeId),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Error loading dispute: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> claimJob(BuildContext context) async {
    final confirmed = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Claim Job',
      message:
          'Claim this job now? You\'ll be assigned as the contractor and can proceed to chat and next steps.',
      confirmText: 'Claim Job',
    );

    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context);
    final service = JobClaimService();

    await OptimisticUI.executeWithOptimism(
      context: context,
      action: () => service.claimJob(jobId),
      loadingMessage: 'Claiming job...',
      successMessage: 'Job claimed successfully.',
      onSuccess: () {
        if (context.mounted) navigator.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('job_requests')
          .doc(jobId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? jobData;
        if (data == null) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Error loading job')),
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final claimed = data['claimed'] == true;
        final claimedBy = (data['claimedBy'] as String?)?.trim() ?? '';
        final requesterUid = (data['requesterUid'] as String?)?.trim() ?? '';
        final disputeStatus = (data['disputeStatus'] as String?)?.trim() ?? '';

        final paidByRaw = data['paidBy'];
        final paidBy = paidByRaw is List
            ? paidByRaw.map((e) => e?.toString() ?? '').toList()
            : <String>[];

        final status =
            (data['status'] as String?)?.trim().toLowerCase() ?? 'open';

        final acceptedQuoteId =
            (data['acceptedQuoteId'] as String?)?.trim() ?? '';
        final acceptedBidId = (data['acceptedBidId'] as String?)?.trim() ?? '';
        final hasMutualAgreement =
            acceptedQuoteId.isNotEmpty || acceptedBidId.isNotEmpty;

        final leadUnlockedBy =
            (data['leadUnlockedBy'] as String?)?.trim() ?? '';

        // Legacy fields (older jobs). Kept for fallback display until migration removes them.
        final legacyEmail = (data['requesterEmail'] as String?)?.trim() ?? '';
        final legacyPhone = (data['requesterPhone'] as String?)?.trim() ?? '';

        final priceRaw = data['price'];
        final price = priceRaw is num ? priceRaw.toDouble() : 0.0;

        final isRequester =
            currentUid != null &&
            requesterUid.isNotEmpty &&
            currentUid == requesterUid;
        final isClaimedByMe =
            currentUid != null &&
            claimedBy.isNotEmpty &&
            claimedBy == currentUid;
        final hasUnlockedLead =
            currentUid != null && paidBy.contains(currentUid);
        final hasExclusiveLead =
            currentUid != null &&
            leadUnlockedBy.isNotEmpty &&
            leadUnlockedBy == currentUid;
        final canSeeContact =
            isRequester || isClaimedByMe || hasUnlockedLead || hasExclusiveLead;

        final canChat =
            currentUid != null &&
            claimed &&
            claimedBy.isNotEmpty &&
            (isRequester || isClaimedByMe);

        final canLeaveReview =
            claimed &&
            claimedBy.isNotEmpty &&
            currentUid != null &&
            isRequester &&
            status == 'completed';

        // Prevent "free claiming" of marketplace leads.
        // A contractor can only claim a job once there is a mutual agreement
        // (accepted bid/quote recorded on the job).
        final canClaim =
            !claimed &&
            currentUid != null &&
            !isRequester &&
            hasMutualAgreement;

        final canViewDispute =
            (isRequester || isClaimedByMe) &&
            claimed &&
            disputeStatus.isNotEmpty;

        final canReportDispute =
            (isRequester || isClaimedByMe) &&
            claimed &&
            claimedBy.isNotEmpty &&
            disputeStatus.isEmpty &&
            hasMutualAgreement;

        final canSeeExpenses =
            currentUid != null && (isRequester || isClaimedByMe);

        Future<void> showActionsSheet() async {
          final actions = <ActionItem<String>>[];

          if (canChat) {
            actions.add(
              ActionItem<String>(
                title: isRequester
                    ? 'Chat with Contractor'
                    : 'Chat with Client',
                subtitle: 'Send messages and updates',
                icon: Icons.chat_bubble_outline,
                value: 'chat',
              ),
            );
          }

          if (canSeeExpenses) {
            actions.add(
              const ActionItem<String>(
                title: 'Receipts & Expenses',
                subtitle: 'Track and export receipts',
                icon: Icons.receipt_long,
                value: 'expenses',
              ),
            );
          }

          if (canViewDispute) {
            actions.add(
              const ActionItem<String>(
                title: 'View Dispute',
                subtitle: 'See dispute status and updates',
                icon: Icons.report_problem_outlined,
                value: 'view_dispute',
              ),
            );
          }

          if (canReportDispute) {
            actions.add(
              ActionItem<String>(
                title: 'Report Dispute',
                subtitle: 'Freeze escrow and start dispute',
                icon: Icons.report_problem,
                value: 'report_dispute',
              ),
            );
          }

          // Cancel job — available when the job is still active (not completed/cancelled).
          final canCancel =
              isRequester && status != 'completed' && status != 'cancelled';
          if (canCancel) {
            actions.add(
              const ActionItem<String>(
                title: 'Cancel Job',
                subtitle: 'Cancel and check refund eligibility',
                icon: Icons.cancel_outlined,
                value: 'cancel_job',
              ),
            );
          }

          if (actions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No actions available right now.')),
            );
            return;
          }

          final selected = await BottomSheetHelper.showActionList<String>(
            context: context,
            title: 'Actions',
            actions: actions,
          );
          if (!context.mounted || selected == null) return;

          switch (selected) {
            case 'chat':
              await _openChatFromJobDetail(
                context: context,
                requesterUid: requesterUid,
                claimedBy: claimedBy,
                isRequester: isRequester,
              );
              break;
            case 'expenses':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpensesListPage(
                    jobId: jobId,
                    canAdd: true,
                    createdByRole: isRequester ? 'customer' : 'contractor',
                  ),
                ),
              );
              break;
            case 'view_dispute':
              await _openLatestDispute(context);
              break;
            case 'report_dispute':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DisputeScreen(jobId: jobId)),
              );
              break;
            case 'cancel_job':
              // Parse scheduled date from data, fall back to 7 days from now.
              DateTime scheduledDate;
              final rawDate = data['preferredDate'] ?? data['scheduledDate'];
              if (rawDate is Timestamp) {
                scheduledDate = rawDate.toDate();
              } else if (rawDate is String) {
                scheduledDate =
                    DateTime.tryParse(rawDate) ??
                    DateTime.now().add(const Duration(days: 7));
              } else {
                scheduledDate = DateTime.now().add(const Duration(days: 7));
              }
              final jobPrice = (data['price'] as num?)?.toDouble() ?? 0;
              final jobTitle = (data['service'] as String?) ?? 'Job';

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CancellationScreen(
                    jobId: jobId,
                    collection: 'job_requests',
                    scheduledDate: scheduledDate,
                    jobPrice: jobPrice,
                    jobTitle: jobTitle,
                  ),
                ),
              );
              break;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Job Details'),
            actions: [
              IconButton(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_vert),
                onPressed: showActionsSheet,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['service'] ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text("Location: ${data['location']}"),
                const SizedBox(height: 8),
                const Text('Description:'),
                const SizedBox(height: 4),
                Text(data['description'] ?? ''),

                const SizedBox(height: 16),
                if (isRequester && !claimed) ...[
                  const SizedBox(height: 16),
                  SuggestedProsCard(jobId: jobId, canInvite: true),
                ],

                if (canSeeContact) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('job_requests')
                        .doc(jobId)
                        .collection('private')
                        .doc('contact')
                        .snapshots(),
                    builder: (context, contactSnap) {
                      final contactData = contactSnap.data?.data();
                      final name =
                          (contactData?['name'] as String?)?.trim() ?? '';
                      final email =
                          (contactData?['email'] as String?)?.trim() ?? '';
                      final phone =
                          (contactData?['phone'] as String?)?.trim() ?? '';

                      if (email.isEmpty && phone.isEmpty) {
                        // Fallback for legacy jobs that stored contact info on the public job doc.
                        // Once migration runs, legacy fields will be removed and this fallback will
                        // naturally disappear.
                        if (legacyEmail.isEmpty && legacyPhone.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contact:'),
                            if (name.isNotEmpty) Text('Name: $name'),
                            if (legacyEmail.isNotEmpty)
                              Text('Email: $legacyEmail'),
                            if (legacyPhone.isNotEmpty)
                              Text('Phone: $legacyPhone'),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contact:'),
                          if (name.isNotEmpty) Text('Name: $name'),
                          if (email.isNotEmpty) Text('Email: $email'),
                          if (phone.isNotEmpty) Text('Phone: $phone'),
                        ],
                      );
                    },
                  ),
                ],
                if (!canSeeContact && currentUid != null && !isRequester) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client contact (locked)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: 0.45,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Email: ********@****.com'),
                                Text('Phone: (***) ***-****'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Non-exclusive: any contractor can purchase contact access.\nExclusive: first buyer locks the lead so no one else can purchase or see it.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUid)
                                .snapshots(),
                            builder: (context, userSnap) {
                              final userData = userSnap.data?.data() ?? {};
                              final neRaw =
                                  userData['leadCredits'] ??
                                  userData['credits'];
                              final neCredits = neRaw is num
                                  ? neRaw.toInt()
                                  : 0;
                              final exRaw = userData['exclusiveLeadCredits'];
                              final exCredits = exRaw is num
                                  ? exRaw.toInt()
                                  : 0;

                              Future<void> showLeadPackSheet() async {
                                final chosen = await showModalBottomSheet<String>(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (context) {
                                    final scheme = Theme.of(
                                      context,
                                    ).colorScheme;

                                    Widget packButton({
                                      required String id,
                                      required String title,
                                      required String subtitle,
                                      bool primary = false,
                                      String? badge,
                                    }) {
                                      Widget? badgeWidget(String? text) {
                                        final t = (text ?? '').trim();
                                        if (t.isEmpty) return null;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primary
                                                ? scheme.onPrimary.withValues(
                                                    alpha: 0.16,
                                                  )
                                                : scheme.primary.withValues(
                                                    alpha: 0.12,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            t,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: primary
                                                      ? scheme.onPrimary
                                                            .withValues(
                                                              alpha: 0.9,
                                                            )
                                                      : scheme.primary,
                                                ),
                                          ),
                                        );
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: primary
                                              ? FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        id,
                                                      ),
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 14,
                                                        ),
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    title,
                                                                    style: Theme.of(context)
                                                                        .textTheme
                                                                        .titleMedium
                                                                        ?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w800,
                                                                        ),
                                                                  ),
                                                                ),
                                                                if (badgeWidget(
                                                                      badge,
                                                                    ) !=
                                                                    null) ...[
                                                                  const SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  badgeWidget(
                                                                    badge,
                                                                  )!,
                                                                ],
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              subtitle,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: scheme
                                                                        .onPrimary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.85,
                                                                        ),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Icon(
                                                        Icons.arrow_forward_ios,
                                                        size: 16,
                                                        color: scheme.onPrimary
                                                            .withValues(
                                                              alpha: 0.85,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : FilledButton.tonal(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        id,
                                                      ),
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 14,
                                                        ),
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    title,
                                                                    style: Theme.of(context)
                                                                        .textTheme
                                                                        .titleMedium
                                                                        ?.copyWith(
                                                                          fontWeight:
                                                                              FontWeight.w800,
                                                                        ),
                                                                  ),
                                                                ),
                                                                if (badgeWidget(
                                                                      badge,
                                                                    ) !=
                                                                    null) ...[
                                                                  const SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  badgeWidget(
                                                                    badge,
                                                                  )!,
                                                                ],
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              subtitle,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: scheme
                                                                        .onSurfaceVariant,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Icon(
                                                        Icons.arrow_forward_ios,
                                                        size: 16,
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      );
                                    }

                                    return SafeArea(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const ListTile(
                                              title: Text(
                                                'Buy leads',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Choose non-exclusive (\$50) or exclusive (\$80).',
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 16,
                                                right: 16,
                                                top: 8,
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Non-exclusive',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            packButton(
                                              id: 'ne_1',
                                              title: '1 lead — \$50',
                                              subtitle:
                                                  'Multiple contractors may purchase',
                                            ),
                                            packButton(
                                              id: 'ne_10',
                                              title: '10 leads — \$450',
                                              subtitle:
                                                  '10 non-exclusive credits',
                                              badge: 'Popular',
                                            ),
                                            packButton(
                                              id: 'ne_20',
                                              title: '20 leads — \$850',
                                              subtitle:
                                                  '20 non-exclusive credits',
                                              badge: 'Best value',
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 16,
                                                right: 16,
                                                top: 8,
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Exclusive',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            packButton(
                                              id: 'ex_1',
                                              title: '1 lead — \$80',
                                              subtitle:
                                                  'Locks lead so only you can see it',
                                              primary: true,
                                            ),
                                            packButton(
                                              id: 'ex_10',
                                              title: '10 leads — \$720',
                                              subtitle: '10 exclusive credits',
                                              primary: true,
                                              badge: 'Popular',
                                            ),
                                            packButton(
                                              id: 'ex_20',
                                              title: '20 leads — \$1360',
                                              subtitle: '20 exclusive credits',
                                              primary: true,
                                              badge: 'Best value',
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );

                                if (chosen == null || chosen.trim().isEmpty) {
                                  return;
                                }
                                try {
                                  await StripeService().buyLeadPack(
                                    packId: chosen,
                                  );

                                  if (!context.mounted) return;
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Complete checkout to add lead credits.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final message = e
                                      .toString()
                                      .replaceFirst('Exception: ', '')
                                      .trim();
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Non-exclusive credits: $neCredits'),
                                  const SizedBox(height: 4),
                                  Text('Exclusive credits: $exCredits'),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        try {
                                          if (neCredits <= 0 &&
                                              exCredits <= 0) {
                                            await showLeadPackSheet();
                                            return;
                                          }

                                          bool exclusive;
                                          if (neCredits > 0 && exCredits > 0) {
                                            final choice = await showModalBottomSheet<bool>(
                                              context: context,
                                              showDragHandle: true,
                                              builder: (context) {
                                                return SafeArea(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const ListTile(
                                                        title: Text(
                                                          'Unlock lead',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          'Choose non-exclusive or exclusive.',
                                                        ),
                                                      ),
                                                      ListTile(
                                                        title: const Text(
                                                          'Non-exclusive (1 credit)',
                                                        ),
                                                        subtitle: const Text(
                                                          'Other contractors may also purchase',
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              context,
                                                              false,
                                                            ),
                                                      ),
                                                      ListTile(
                                                        title: const Text(
                                                          'Exclusive (1 credit)',
                                                        ),
                                                        subtitle: const Text(
                                                          'Locks lead so only you can access it',
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              context,
                                                              true,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );

                                            if (choice == null) return;
                                            exclusive = choice;
                                          } else {
                                            exclusive = neCredits <= 0;
                                          }

                                          await LeadService().unlockLead(
                                            jobId: jobId,
                                            exclusive: exclusive,
                                          );
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Lead unlocked. Contact details are now available.',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          final message = e
                                              .toString()
                                              .replaceFirst('Exception: ', '')
                                              .trim();
                                          messenger.showSnackBar(
                                            SnackBar(content: Text(message)),
                                          );
                                        }
                                      },
                                      child: Text(
                                        (neCredits > 0 || exCredits > 0)
                                            ? 'Unlock lead'
                                            : 'Buy leads',
                                      ),
                                    ),
                                  ),
                                  if (neCredits > 0 || exCredits > 0)
                                    TextButton(
                                      onPressed: showLeadPackSheet,
                                      child: const Text('Buy more leads'),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Job Status Tracking (for both customer and contractor)
                if ((isRequester || isClaimedByMe) && claimed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.timeline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobStatusScreen(jobId: jobId),
                          ),
                        );
                      },
                      label: const Text('View Job Status'),
                    ),
                  ),
                ],
                if (canLeaveReview) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('reviews')
                        .where('jobId', isEqualTo: jobId)
                        .snapshots(),
                    builder: (context, reviewSnap) {
                      if (!reviewSnap.hasData) {
                        return const SizedBox.shrink();
                      }

                      final uid = currentUid;
                      final alreadyReviewed = reviewSnap.data!.docs.any((d) {
                        final data = d.data();
                        final customerId =
                            (data['customerId'] as String?)?.trim() ?? '';
                        return customerId == uid;
                      });

                      if (alreadyReviewed) {
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Review Submitted'),
                          ),
                        );
                      }

                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubmitReviewScreen(
                                  contractorId: claimedBy,
                                  jobId: jobId,
                                ),
                              ),
                            );
                          },
                          child: const Text('Leave a Review'),
                        ),
                      );
                    },
                  ),
                ],
                // Add Tip button (for completed jobs)
                if (isRequester &&
                    claimed &&
                    claimedBy.isNotEmpty &&
                    status == 'completed' &&
                    data['tipAmount'] == null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.thumb_up),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTipScreen(
                              jobId: jobId,
                              contractorId: claimedBy,
                              jobAmount: price.toDouble(),
                            ),
                          ),
                        );
                      },
                      label: const Text('Add a Tip'),
                    ),
                  ),
                ],
                // View Invoice button (for funded/completed jobs)
                if ((isRequester || isClaimedByMe) &&
                    status == 'completed') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceScreen(jobId: jobId),
                          ),
                        );
                      },
                      label: const Text('View Invoice'),
                    ),
                  ),
                ],
                // View Quotes button (for customers)
                if (isRequester) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.request_quote),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuotesScreen(jobId: jobId),
                          ),
                        );
                      },
                      label: const Text('View Quotes'),
                    ),
                  ),
                ],
                // Submit Quote button (for contractors)
                if (!claimed && currentUid != null && !isRequester) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubmitQuoteScreen(jobId: jobId),
                          ),
                        );
                      },
                      label: const Text('Submit a Quote'),
                    ),
                  ),
                ],
                // View Bids button (for customers - legacy)
                if (isRequester) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.gavel),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BidsListScreen(jobId: jobId),
                          ),
                        );
                      },
                      label: const Text('View Bids (Legacy)'),
                    ),
                  ),
                ],
                // Phase 7 - Project Management
                // Milestones button (for claimed jobs)
                if (claimed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectMilestonesScreen(
                              jobId: jobId,
                              isContractor: isClaimedByMe,
                            ),
                          ),
                        );
                      },
                      label: const Text('Project Milestones'),
                    ),
                  ),
                ],
                // Progress Photos button (for claimed jobs)
                if (claimed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgressPhotosScreen(
                              jobId: jobId,
                              canUpload: isClaimedByMe,
                            ),
                          ),
                        );
                      },
                      label: const Text('Progress Photos'),
                    ),
                  ),
                ],
                // Timeline button (for claimed jobs)
                if (claimed) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.timeline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectTimelineScreen(jobId: jobId),
                          ),
                        );
                      },
                      label: const Text('View Timeline'),
                    ),
                  ),
                ],

                if (canSeeExpenses) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpensesListPage(
                              jobId: jobId,
                              canAdd: true,
                              createdByRole: isRequester
                                  ? 'customer'
                                  : 'contractor',
                            ),
                          ),
                        );
                      },
                      label: const Text('Receipts & Expenses'),
                    ),
                  ),
                ],

                if (canChat) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _openChatFromJobDetail(
                        context: context,
                        requesterUid: requesterUid,
                        claimedBy: claimedBy,
                        isRequester: isRequester,
                      ),
                      child: Text(
                        isRequester ? 'Message Contractor' : 'Message Client',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!isRequester && (claimed || canClaim))
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canClaim ? () => claimJob(context) : null,
                      child: Text(claimed ? 'Already Claimed' : 'Accept Job'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
