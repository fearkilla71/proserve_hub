import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/dispute_screen.dart';
import '../services/conversation_service.dart';
import '../services/job_claim_service.dart';
import '../utils/bottom_sheet_helper.dart';
import '../utils/optimistic_ui.dart';

/// Helper methods extracted from [JobDetailPage] to reduce god-class size.
class JobDetailActions {
  const JobDetailActions._();

  /// Opens a chat between the current user and the other party on the job.
  static Future<void> openChat({
    required BuildContext context,
    required String jobId,
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
          // If rules block contact details, fall back to generic name.
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

  /// Opens the latest dispute for a job.
  static Future<void> openLatestDispute(
    BuildContext context,
    String jobId,
  ) async {
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

  /// Confirm + optimistic claim job flow.
  static Future<void> claimJob(BuildContext context, String jobId) async {
    final confirmed = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Claim Job',
      message:
          'Claim this job now? You\'ll be assigned as the contractor and can '
          'proceed to chat and next steps.',
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
}
