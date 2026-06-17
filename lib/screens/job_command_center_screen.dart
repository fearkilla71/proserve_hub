import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../widgets/job_detail_actions.dart';

class JobCommandCenterScreen extends StatelessWidget {
  const JobCommandCenterScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final l10n = AppLocalizations.of(context)!;

    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.signInRequired)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.jobCommandCenterTitle),
        actions: [
          IconButton(
            tooltip: l10n.jobDetailsTooltip,
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
              title: l10n.couldNotLoadJob,
              subtitle: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return _StateCard(
              icon: Icons.work_off_outlined,
              title: l10n.jobNotFoundTitle,
              subtitle: l10n.jobNotFoundSubtitle,
            );
          }

          final state = _JobCommandState(jobId: jobId, uid: uid, data: data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _JobHeader(state: state),
              const SizedBox(height: 12),
              _JobProgressCard(state: state),
              const SizedBox(height: 12),
              _NextActionCard(state: state),
              const SizedBox(height: 12),
              _CommandSection(
                title: l10n.commandSectionWinConfirm,
                children: [
                  _CommandTile(
                    icon: Icons.request_quote_outlined,
                    title: state.isRequester
                        ? l10n.reviewQuotes
                        : l10n.submitQuote,
                    subtitle: state.isRequester
                        ? l10n.reviewQuotesSubtitle
                        : l10n.submitQuoteSubtitle,
                    onTap: () => context.push(
                      state.isRequester
                          ? '/quotes/$jobId'
                          : '/submit-quote/$jobId',
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.how_to_vote_outlined,
                    title: l10n.bids,
                    subtitle: l10n.bidsSubtitle,
                    onTap: () => context.push('/bids/$jobId'),
                  ),
                ],
              ),
              if (state.isContractor) ...[
                const SizedBox(height: 12),
                _CommandSection(
                  title: l10n.commandSectionToolsForJob,
                  children: [
                    _CommandTile(
                      icon: Icons.calculate_outlined,
                      title: l10n.priceThisJob,
                      subtitle: l10n.priceThisJobSubtitle,
                      onTap: () => context.push(
                        '/pricing-calculator',
                        extra: state.toolExtra,
                      ),
                    ),
                    _CommandTile(
                      icon: Icons.folder_copy_outlined,
                      title: l10n.savedEstimates,
                      subtitle: l10n.savedEstimatesJobSubtitle,
                      onTap: () => context.push(
                        '/saved-estimates',
                        extra: state.toolExtra,
                      ),
                    ),
                    _CommandTile(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.aiInvoiceMaker,
                      subtitle: l10n.aiInvoiceMakerJobSubtitle,
                      onTap: () => context.push(
                        '/invoice-maker',
                        extra: state.toolExtra,
                      ),
                    ),
                    _CommandTile(
                      icon: Icons.imagesearch_roller_outlined,
                      title: l10n.createRender,
                      subtitle: l10n.createRenderJobSubtitle,
                      onTap: () =>
                          context.push('/render-tool', extra: state.toolExtra),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _CommandSection(
                title: l10n.commandSectionCommunicateDocument,
                children: [
                  _CommandTile(
                    icon: Icons.chat_bubble_outline,
                    title: state.isRequester
                        ? l10n.chatWithContractor
                        : l10n.chatWithClient,
                    subtitle: state.canChat
                        ? l10n.openJobConversation
                        : l10n.chatOpensAfterClaimed,
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
                    title: l10n.progressPhotos,
                    subtitle: l10n.progressPhotosSubtitle,
                    onTap: () => context.push(
                      '/progress-photos/$jobId',
                      extra: {'canUpload': state.isContractor},
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.timeline_outlined,
                    title: l10n.timeline,
                    subtitle: l10n.timelineSubtitle,
                    onTap: () => context.push('/timeline/$jobId'),
                  ),
                  _CommandTile(
                    icon: Icons.flag_outlined,
                    title: l10n.milestones,
                    subtitle: l10n.milestonesSubtitle,
                    onTap: () => context.push(
                      '/milestones/$jobId',
                      extra: {'isContractor': state.isContractor},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CommandSection(
                title: l10n.commandSectionMoneyCompletion,
                children: [
                  _CommandTile(
                    icon: Icons.verified_user_outlined,
                    title: l10n.status,
                    subtitle: l10n.statusJobSubtitle,
                    onTap: () => context.push('/job-status/$jobId'),
                  ),
                  _CommandTile(
                    icon: Icons.receipt_long_outlined,
                    title: state.isContractor
                        ? l10n.createInvoice
                        : l10n.invoice,
                    subtitle: state.isContractor
                        ? l10n.createInvoiceSubtitle
                        : l10n.invoiceSubtitle,
                    onTap: () => context.push('/invoice/$jobId'),
                  ),
                  if (state.escrowId.isNotEmpty)
                    _CommandTile(
                      icon: Icons.shield_outlined,
                      title: l10n.escrow,
                      subtitle: l10n.escrowSubtitle,
                      onTap: () =>
                          context.push('/escrow-status/${state.escrowId}'),
                    )
                  else
                    _CommandTile(
                      icon: Icons.shield_outlined,
                      title: l10n.escrow,
                      subtitle: l10n.noEscrowAttached,
                      enabled: false,
                    ),
                  _CommandTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: l10n.receiptsExpenses,
                    subtitle: l10n.receiptsExpensesSubtitle,
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
                title: l10n.commandSectionTrustCloseout,
                children: [
                  _CommandTile(
                    icon: Icons.star_outline,
                    title: l10n.review,
                    subtitle: state.canReview
                        ? l10n.reviewCompletedWork
                        : l10n.reviewOpensAfterCompleted,
                    enabled: state.canReview,
                    onTap: () => context.push(
                      '/submit-review/$jobId/${state.claimedBy}',
                    ),
                  ),
                  _CommandTile(
                    icon: Icons.report_problem_outlined,
                    title: state.hasDispute
                        ? l10n.viewDispute
                        : l10n.reportDispute,
                    subtitle: state.hasDispute
                        ? l10n.viewDisputeSubtitle
                        : l10n.reportDisputeSubtitle,
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
                    title: l10n.cancellation,
                    subtitle: state.canCancel
                        ? l10n.cancelRefundEligibility
                        : l10n.cancellationUnavailable,
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

  Map<String, dynamic> get toolExtra => {
    'sourceJobId': jobId,
    'sourceJobData': data,
  };

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

  int get progressIndex {
    if (status == 'completed') return 5;
    if (status == 'completion_requested' || status == 'completion_approved') {
      return 4;
    }
    if (status == 'in_progress') return 4;
    if (escrowId.isNotEmpty || status == 'escrow_funded') return 3;
    if (claimed || status == 'accepted') return 2;
    if (status == 'pending' || status == 'open') return 1;
    return 0;
  }

  String localizedStatus(AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'accepted':
        return l10n.accepted;
      case 'in_progress':
        return l10n.inProgress;
      case 'completion_requested':
        return l10n.completionRequested;
      case 'completion_approved':
        return l10n.completionApproved;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
        return l10n.cancelled;
      case 'escrow_funded':
        return l10n.escrowFunded;
      default:
        return status.isEmpty ? l10n.open : statusLabel;
    }
  }

  String localizedNextActionTitle(AppLocalizations l10n) {
    if (!claimed) {
      return isRequester ? l10n.reviewIncomingQuotes : l10n.submitAQuote;
    }
    if (status == 'accepted') return l10n.startWork;
    if (status == 'in_progress') return l10n.requestCompletion;
    if (status == 'completion_requested' && isRequester) {
      return l10n.approveCompletion;
    }
    if (escrowId.isNotEmpty) return l10n.checkEscrow;
    return l10n.openJobStatus;
  }

  String localizedNextActionSubtitle(AppLocalizations l10n) {
    if (!claimed) {
      return isRequester
          ? l10n.compareBidsChooseContractor
          : l10n.sendClearQuote;
    }
    if (status == 'completion_requested' && isRequester) {
      return l10n.confirmWorkBeforeRelease;
    }
    if (escrowId.isNotEmpty) {
      return l10n.fundsVisibleFromEscrow;
    }
    return l10n.useStatusToAlign;
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.state});

  final _JobCommandState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
                  label: Text(state.localizedStatus(l10n)),
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
                    state.isRequester ? l10n.customerView : l10n.contractorView,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (state.escrowId.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.shield_outlined, size: 18),
                    label: Text(l10n.escrowAttached),
                    visualDensity: VisualDensity.compact,
                  ),
                if (state.hasDispute)
                  Chip(
                    avatar: Icon(
                      Icons.report_problem_outlined,
                      size: 18,
                      color: scheme.error,
                    ),
                    label: Text(l10n.disputeOpen),
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

class _JobProgressCard extends StatelessWidget {
  const _JobProgressCard({required this.state});

  final _JobCommandState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      _ProgressStep(Icons.assignment_outlined, l10n.jobStepRequest),
      _ProgressStep(Icons.request_quote_outlined, l10n.jobStepQuotes),
      _ProgressStep(Icons.handshake_outlined, l10n.jobStepHire),
      _ProgressStep(Icons.shield_outlined, l10n.jobStepEscrow),
      _ProgressStep(Icons.construction_outlined, l10n.jobStepWork),
      _ProgressStep(Icons.star_outline, l10n.jobStepReview),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.customerJourney,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.customerJourneySubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < steps.length; i++)
                  _ProgressPill(
                    step: steps[i],
                    done: i < state.progressIndex,
                    current: i == state.progressIndex,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStep {
  const _ProgressStep(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.step,
    required this.done,
    required this.current,
  });

  final _ProgressStep step;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = done
        ? Colors.green.withValues(alpha: 0.12)
        : current
        ? scheme.primaryContainer.withValues(alpha: 0.75)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final fg = done
        ? Colors.green.shade700
        : current
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: current ? scheme.primary.withValues(alpha: 0.35) : bg,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_outline : step.icon,
            size: 17,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            step.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: done || current ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.state});

  final _JobCommandState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = state.localizedNextActionTitle(l10n);
    final subtitle = state.localizedNextActionSubtitle(l10n);
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
              l10n.nextBestAction,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(title),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(title),
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
