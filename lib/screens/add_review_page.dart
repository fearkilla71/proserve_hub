import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class AddReviewPage extends StatefulWidget {
  final String contractorId;
  final String jobId;

  const AddReviewPage({
    super.key,
    required this.contractorId,
    required this.jobId,
  });

  @override
  State<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends State<AddReviewPage> {
  int rating = 5;
  final TextEditingController commentCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> submitReview() async {
    if (loading) return;
    final l10n = AppLocalizations.of(context)!;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewSignInRequired)));
      return;
    }

    setState(() => loading = true);

    final reviewRef = FirebaseFirestore.instance.collection('reviews');

    // Deterministic id prevents duplicate reviews per job per user.
    final reviewDocId = '${widget.jobId}_${user.uid}';

    try {
      await reviewRef.doc(reviewDocId).set({
        'contractorId': widget.contractorId,
        'jobId': widget.jobId,
        // Keep both fields for compatibility with existing reads.
        'reviewerUid': user.uid,
        'customerId': user.uid,
        'rating': rating,
        'comment': commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewSubmitted)));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorWithMessage(msg))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveReviewTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.reviewTrustTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.reviewTrustSubtitle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.rating,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton.filledTonal(
                  onPressed: loading
                      ? null
                      : () => setState(() => rating = value),
                  icon: Icon(
                    value <= rating ? Icons.star : Icons.star_border,
                    color: value <= rating ? Colors.amber.shade700 : null,
                  ),
                  tooltip: l10n.reviewRatingSemantics(value),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reviewRatingHelper(rating),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: commentCtrl,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.reviewCommentLabel,
                hintText: l10n.reviewCommentHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: loading ? null : submitReview,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rate_review_outlined),
              label: Text(loading ? l10n.working : l10n.submitReview),
            ),
          ],
        ),
      ),
    );
  }
}
