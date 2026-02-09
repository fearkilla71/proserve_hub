import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SuggestedProsCard extends StatefulWidget {
  final String jobId;
  final bool canInvite;

  const SuggestedProsCard({
    super.key,
    required this.jobId,
    required this.canInvite,
  });

  @override
  State<SuggestedProsCard> createState() => _SuggestedProsCardState();
}

class _SuggestedProsCardState extends State<SuggestedProsCard> {
  final Set<String> _invitingContractorIds = <String>{};

  Future<void> _inviteToBid({required String contractorId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }

    final safeContractorId = contractorId.trim();
    if (safeContractorId.isEmpty) return;

    setState(() => _invitingContractorIds.add(safeContractorId));

    try {
      final inviteId = '${widget.jobId}_$safeContractorId';
      final ref = FirebaseFirestore.instance
          .collection('bid_invites')
          .doc(inviteId);

      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 14)),
      );

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return;

        tx.set(ref, {
          'jobId': widget.jobId,
          'contractorId': safeContractorId,
          'customerId': user.uid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAt,
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _invitingContractorIds.remove(safeContractorId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canInvite) return const SizedBox.shrink();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    final invitesStream = FirebaseFirestore.instance
        .collection('bid_invites')
        .where('jobId', isEqualTo: widget.jobId)
        .where('customerId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: invitesStream,
      builder: (context, invitesSnap) {
        final invited = <String>{};
        final inviteDocs = invitesSnap.data?.docs ?? const [];
        for (final d in inviteDocs) {
          final data = d.data();
          final cid = (data['contractorId'] as String?)?.trim() ?? '';
          if (cid.isNotEmpty) invited.add(cid);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('job_matches')
              .doc(widget.jobId)
              .collection('candidates')
              .orderBy('matchScore', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, matchesSnap) {
            if (matchesSnap.hasError) {
              return const SizedBox.shrink();
            }

            final docs = matchesSnap.data?.docs ?? const [];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested pros',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!matchesSnap.hasData)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 6),
                      )
                    else if (docs.isEmpty)
                      Text(
                        'No suggestions yet.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      for (final doc in docs)
                        _SuggestedProRow(
                          contractorId: doc.id,
                          candidateData: doc.data(),
                          isInvited: invited.contains(doc.id),
                          isInviting: _invitingContractorIds.contains(doc.id),
                          onInvite: () => _inviteToBid(contractorId: doc.id),
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SuggestedProRow extends StatelessWidget {
  final String contractorId;
  final Map<String, dynamic> candidateData;
  final bool isInvited;
  final bool isInviting;
  final VoidCallback onInvite;

  const _SuggestedProRow({
    required this.contractorId,
    required this.candidateData,
    required this.isInvited,
    required this.isInviting,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    int asPercent(dynamic v) {
      if (v is num) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final matchScore = asPercent(candidateData['matchScore']);
    final distanceMiles = asDouble(candidateData['distanceMiles']);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .get(),
      builder: (context, contractorSnap) {
        final contractor = contractorSnap.data?.data();
        if (contractor == null) return const SizedBox.shrink();

        final name = (contractor['name'] ?? 'Contractor').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.percent, size: 16),
                          label: Text('${matchScore.clamp(0, 100)}% match'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 16),
                          label: Text('${distanceMiles.toStringAsFixed(1)} mi'),
                        ),
                        if (contractor['verified'] == true)
                          const Chip(
                            avatar: Icon(Icons.verified, size: 16),
                            label: Text('Verified'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: (isInvited || isInviting) ? null : onInvite,
                child: Text(
                  isInvited ? 'Invited' : (isInviting ? 'Inviting…' : 'Invite'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
