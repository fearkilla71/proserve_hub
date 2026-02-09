import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to leave a review.')),
      );
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
      ).showSnackBar(const SnackBar(content: Text('Review submitted')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Rating', style: TextStyle(fontSize: 18)),
            ),
            Slider(
              value: rating.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: rating.toString(),
              onChanged: loading
                  ? null
                  : (v) => setState(() => rating = v.toInt()),
            ),
            TextField(
              controller: commentCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : submitReview,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
