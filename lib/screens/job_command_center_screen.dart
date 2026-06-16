import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/job_detail_actions.dart';

class JobCommandCenterScreen extends StatelessWidget {
  const JobCommandCenterScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Command Center'),
        actions: [
          IconButton(
            tooltip: 'Job details',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/job/$jobId'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('job_requests')
            .doc(jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StateCard(
              icon: Icons.error_outline,
              title: 'Could not load job',
              subtitle: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const _StateCard(
              icon: Icons.work_off_outlined,
              title: 'Job not found',
              subtitle: 'This job may have been removed or is unavailable.',
            );
          }

          final state = _JobCommandState(jobId: jobId, uid: uid, data: data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _JobHeader(state: state),
              const SizedBox(height: 12),
              _NextActionCard(state: state),
              const SizedBox(height: 12),
              _CommandSection(
                title: 'Win & confirm work',
                children: [
                  _CommandTile(
                    icon: Icons.request_quote_outlined,
                    title: state.isRequester ? 'Review quotes' : 'Submit quote',
                    subtitle: state.isRequester
                        ? 'Compare contractor pricing and terms.'
                        : 'Send pricing, notes, and scope for this job.',
                    onTap: () => context.push(
                      state.isRequester
                          ? '/quotes/$jobId'
                          : '/submit-quote/$jobId',
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.how_to_vote_outlined,
                    title: 'Bids',
                    subtitle: 'View bids and acceptance status.',
                    onTap: () => context.push('/bids/$jobId'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CommandSection(
                title: 'Communicate & document',
                children: [
                  _CommandTile(
                    icon: Icons.chat_bubble_outline,
                    title: state.isRequester
                        ? 'Chat with contractor'
                        : 'Chat with client',
                    subtitle: state.canChat
                        ? 'Open the job conversation.'
                        : 'Chat opens after the job is claimed.',
                    enabled: state.canChat,
                    onTap: () => JobDetailActions.openChat(
                      context: context,
                      jobId: jobId,
                      requesterUid: state.requesterUid,
                      claimedBy: state.claimedBy,
                      isRequester: state.isRequester,
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Progress photos',
                    subtitle: 'Upload and review job photos.',
                    onTap: () => context.push(
                      '/progress-photos/$jobId',
                      extra: {'canUpload': state.isContractor},
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.timeline_outlined,
                    title: 'Timeline',
                    subtitle: 'See updates, milestones, and activity.',
                    onTap: () => context.push('/timeline/$jobId'),
                  ),
                  _CommandTile(
                    icon: Icons.flag_outlined,
                    title: 'Milestones',
                    subtitle: 'Track major job checkpoints.',
                    onTap: () => context.push(
                      '/milestones/$jobId',
                      extra: {'isContractor': state.isContractor},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CommandSection(
                title: 'Money & completion',
                children: [
                  _CommandTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Status',
                    subtitle: 'Start work, request completion, or approve it.',
                    onTap: () => context.push('/job-status/$jobId'),
                  ),
                  _CommandTile(
                    icon: Icons.receipt_long_outlined,
                    title: state.isContractor ? 'Create invoice' : 'Invoice',
                    subtitle: state.isContractor
                        ? 'Create or update the customer invoice.'
                        : 'Review invoice details for this job.',
                    onTap: () => context.push('/invoice/$jobId'),
                  ),
                  if (state.escrowId.isNotEmpty)
                    _CommandTile(
                      icon: Icons.shield_outlined,
                      title: 'Escrow',
                      subtitle: 'View secured funds and release status.',
                      onTap: () =>
                          context.push('/escrow-status/${state.escrowId}'),
                    )
                  else
                    const _CommandTile(
                      icon: Icons.shield_outlined,
                      title: 'Escrow',
                      subtitle: 'No escrow has been attached to this job yet.',
                      enabled: false,
                    ),
                  _CommandTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Receipts & expenses',
                    subtitle: 'Track materials, labor, and reimbursements.',
                    onTap: () => context.push(
                      '/expenses/$jobId',
                      extra: {
                        'canAdd': state.isRequester || state.isContractor,
                        'createdByRole': state.isContractor
                            ? 'contractor'
                            : 'customer',
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CommandSection(
                title: 'Trust & closeout',
                children: [
                  _CommandTile(
                    icon: Icons.star_outline,
                    title: 'Review',
                    subtitle: state.canReview
                        ? 'Rate the completed contractor work.'
                        : 'Reviews open after the job is completed.',
                    enabled: state.canReview,
                    onTap: () => context.push(
                      '/submit-review/$jobId/${state.claimedBy}',
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.report_problem_outlined,
                    title: state.hasDispute ? 'View dispute' : 'Report dispute',
                    subtitle: state.hasDispute
                        ? 'Open the latest dispute details.'
                        : 'Report an issue with this job.',
                    enabled: state.isRequester || state.isContractor,
                    onTap: () {
                      if (state.hasDispute) {
                        JobDetailActions.openLatestDispute(context, jobId);
                      } else {
                        context.push('/dispute/$jobId');
                      }
                    },
                  ),
                  _CommandTile(
                    icon: Icons.cancel_outlined,
                    title: 'Cancellation',
                    subtitle: state.canCancel
                        ? 'Cancel and check refund eligibility.'
                        : 'Cancellation is unavailable for this status.',
                    enabled: state.canCancel,
                    onTap: () => context.push(
                      '/cancellation/$jobId',
                      extra: {
                        'collection': 'job_requests',
                        'scheduledDate': state.scheduledDate,
                        'jobPrice': state.price,
                        'jobTitle': state.service,
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobCommandState {
  _JobCommandState({
    required this.jobId,
    required this.uid,
    required this.data,
  });

  final String jobId;
  final String uid;
  final Map<String, dynamic> data;

  String get service => (data['service'] ?? data['title'] ?? 'Job').toString();
  String get location => (data['location'] ?? data['address'] ?? '').toString();
  String get description => (data['description'] ?? '').toString();
  String get requesterUid => (data['requesterUid'] ?? '').toString();
  String get claimedBy => (data['claimedBy'] ?? '').toString();
  String get escrowId => (data['escrowId'] ?? '').toString();
  String get disputeStatus => (data['disputeStatus'] ?? '').toString();
  String get status => (data['status'] ?? 'open').toString().toLowerCase();
  bool get claimed => data['claimed'] == true || claimedBy.isNotEmpty;
  bool get isRequester => requesterUid == uid;
  bool get isContractor => claimedBy == uid;
  bool get canChat => claimed && (isRequester || isContractor);
  bool get hasDispute => disputeStatus.trim().isNotEmpty;
  bool get canReview =>
      isRequester && claimedBy.isNotEmpty && status == 'completed';
  bool get canCancel =>
      isRequester && status != 'completed' && status != 'cancelled';
  double get price => (data['price'] as num?)?.toDouble() ?? 0;

  DateTime get scheduledDate {
    final raw = data['preferredDate'] ?? data['scheduledDate'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      return DateTime.tryParse(raw) ??
          DateTime.now().add(const Duration(days: 7));
    }
    return DateTime.now().add(const Duration(days: 7));
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completion_requested':
        return 'Completion Requested';
      case 'completion_approved':
        return 'Completion Approved';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'escrow_funded':
        return 'Escrow Funded';
      default:
        return status.isEmpty
            ? 'Open'
            : status
                  .split('_')
                  .map(
                    (word) => word.isEmpty
                        ? word
                        : '${word[0].toUpperCase()}${word.substring(1)}',
                  )
                  .join(' ');
    }
  }

  Color statusColor(ColorScheme scheme) {
    switch (status) {
      case 'completed':
      case 'completion_approved':
        return Colors.green;
      case 'cancelled':
        return scheme.error;
      case 'completion_requested':
        return Colors.deepOrange;
      case 'in_progress':
        return Colors.purple;
      case 'escrow_funded':
        return Colors.teal;
      default:
        return scheme.primary;
    }
  }

  String get nextActionTitle {
    if (!claimed) {
      return isRequester ? 'Review incoming quotes' : 'Submit a quote';
    }
    if (status == 'accepted') return 'Start work';
    if (status == 'in_progress') return 'Request completion';
    if (status == 'completion_requested' && isRequester) {
      return 'Approve completion';
    }
    if (escrowId.isNotEmpty) return 'Check escrow';
    return 'Open job status';
  }

  String get nextActionSubtitle {
    if (!claimed) {
      return isRequester
          ? 'Compare bids, chat with pros, and choose the right contractor.'
          : 'Send a clear quote so the customer can approve the work.';
    }
    if (status == 'completion_requested' && isRequester) {
      return 'Confirm the work before payment release continues.';
    }
    if (escrowId.isNotEmpty) {
      return 'Funds and release state are visible from escrow status.';
    }
    return 'Use status to keep both sides aligned.';
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.state});

  final _JobCommandState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  child: Text(
                    state.service,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(state.statusLabel),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: state
                      .statusColor(scheme)
                      .withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: state.statusColor(scheme),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (state.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 18, color: scheme.outline),
                  const SizedBox(width: 6),
                  Expanded(child: Text(state.location)),
                ],
              ),
            ],
            if (state.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                state.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(
                    state.isRequester ? 'Customer view' : 'Contractor view',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (state.escrowId.isNotEmpty)
                  const Chip(
                    avatar: Icon(Icons.shield_outlined, size: 18),
                    label: Text('Escrow attached'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (state.hasDispute)
                  Chip(
                    avatar: Icon(
                      Icons.report_problem_outlined,
                      size: 18,
                      color: scheme.error,
                    ),
                    label: const Text('Dispute open'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: scheme.errorContainer,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.state});

  final _JobCommandState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next best action',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(state.nextActionTitle),
            const SizedBox(height: 4),
            Text(state.nextActionSubtitle),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(state.nextActionTitle),
                onPressed: () {
                  if (!state.claimed) {
                    context.push(
                      state.isRequester
                          ? '/quotes/${state.jobId}'
                          : '/submit-quote/${state.jobId}',
                    );
                    return;
                  }
                  if (state.escrowId.isNotEmpty &&
                      state.status != 'accepted' &&
                      state.status != 'in_progress' &&
                      state.status != 'completion_requested') {
                    context.push('/escrow-status/${state.escrowId}');
                    return;
                  }
                  context.push('/job-status/${state.jobId}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(enabled ? Icons.chevron_right : Icons.lock_outline),
      onTap: enabled ? onTap : null,
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
