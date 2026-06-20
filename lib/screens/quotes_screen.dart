import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../utils/optimistic_ui.dart';
import '../utils/app_error_handler.dart';

class QuotesScreen extends StatefulWidget {
  final String jobId;

  const QuotesScreen({super.key, required this.jobId});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final Map<String, Map<String, dynamic>?> _contractorCache = {};

  Future<void> _preloadContractors(List<String> ids) async {
    final toFetch = ids
        .where((id) => !_contractorCache.containsKey(id))
        .toSet()
        .toList();
    if (toFetch.isEmpty) return;
    final db = FirebaseFirestore.instance;
    for (var i = 0; i < toFetch.length; i += 10) {
      final chunk = toFetch.sublist(i, (i + 10).clamp(0, toFetch.length));
      final snap = await db
          .collection('contractors')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        _contractorCache[doc.id] = doc.data();
      }
      // Mark missing ones as null so we don't re-fetch.
      for (final id in chunk) {
        _contractorCache.putIfAbsent(id, () => null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.compareQuotes)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quotes')
            .where('jobId', isEqualTo: widget.jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(l10n.errorWithMessage(snapshot.error.toString())),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final quotes = snapshot.data!.docs.toList()
            ..sort((a, b) {
              Timestamp ts(dynamic v) {
                if (v is Timestamp) return v;
                return Timestamp(0, 0);
              }

              final aData = a.data() as Map<String, dynamic>?;
              final bData = b.data() as Map<String, dynamic>?;
              final aTs = ts(aData?['submittedAt']);
              final bTs = ts(bData?['submittedAt']);
              return aTs.compareTo(bTs); // ascending
            });

          if (quotes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noQuotesYet,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.noQuotesYetSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final contractorIds = quotes
              .map(
                (q) =>
                    ((q.data() as Map<String, dynamic>)['contractorId']
                        as String?) ??
                    '',
              )
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
          return FutureBuilder<void>(
            future: _preloadContractors(contractorIds),
            builder: (context, _) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: quotes.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final quoteData = quotes
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();
                  final prices =
                      quoteData
                          .map((q) => (q['price'] as num?)?.toDouble())
                          .whereType<double>()
                          .toList()
                        ..sort();
                  final lowPrice = prices.isEmpty ? null : prices.first;
                  if (index == 0) {
                    return _buildDecisionHeader(quoteData);
                  }

                  final quoteDoc = quotes[index - 1];
                  final quote = quoteDoc.data() as Map<String, dynamic>;
                  return _buildQuoteCard(
                    quoteDoc.id,
                    quote,
                    lowPrice: lowPrice,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDecisionHeader(List<Map<String, dynamic>> quotes) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final pending = quotes
        .where((q) => (q['status'] as String? ?? 'pending') == 'pending')
        .length;
    final accepted = quotes.any((q) => q['status'] == 'accepted');
    final prices =
        quotes
            .map((q) => (q['price'] as num?)?.toDouble())
            .whereType<double>()
            .toList()
          ..sort();
    final low = prices.isEmpty ? 0.0 : prices.first;
    final high = prices.isEmpty ? 0.0 : prices.last;

    return Card(
      color: accepted
          ? Colors.green.withValues(alpha: 0.08)
          : scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  accepted
                      ? Icons.check_circle_outline
                      : Icons.compare_arrows_outlined,
                  color: accepted ? Colors.green : scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    accepted ? l10n.quoteAccepted : l10n.chooseTheRightPro,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              accepted
                  ? l10n.quoteAcceptedHeaderBody
                  : l10n.compareQuotesHeaderBody,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip('${quotes.length}', l10n.quotesLower),
                if (!accepted) _metricChip('$pending', l10n.pendingLower),
                if (prices.isNotEmpty)
                  _metricChip(
                    '\$${low.toStringAsFixed(0)}-\$${high.toStringAsFixed(0)}',
                    l10n.rangeLower,
                  ),
                Chip(
                  avatar: const Icon(Icons.shield_outlined, size: 18),
                  label: Text(l10n.escrowAfterApproval),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (accepted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: Text(l10n.openJobCommandCenter),
                  onPressed: () =>
                      context.pushReplacement('/job-command/${widget.jobId}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String value, String label) {
    return Chip(
      label: Text('$value $label'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildQuoteCard(
    String quoteId,
    Map<String, dynamic> quote, {
    required double? lowPrice,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final contractorId = quote['contractorId'] as String;
    final price = (quote['price'] as num).toDouble();
    final estimatedDuration = quote['estimatedDuration'] as String?;
    final notes = quote['notes'] as String?;
    final sowUrl = quote['sowUrl'] as String?;
    final revisionNumber = (quote['revisionNumber'] as num?)?.toInt() ?? 0;
    final expiresAt = quote['expiresAt'] as Timestamp?;
    final pricingMode = (quote['pricingMode'] as String?)?.trim() ?? 'manual';
    final adjustmentExplanation =
        (quote['aiAdjustmentExplanation'] as String?)?.trim() ?? '';
    final submittedAt = quote['submittedAt'] as Timestamp?;
    final status = quote['status'] as String? ?? 'pending';
    final warranty = (quote['warranty'] as String?)?.trim() ?? '';
    final exclusions = (quote['exclusions'] as String?)?.trim() ?? '';
    final deposit =
        (quote['depositRequired'] as num?)?.toDouble() ??
        (quote['deposit'] as num?)?.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contractor Info (from cache)
            Builder(
              builder: (context) {
                final hasContractorRecord = _contractorCache.containsKey(
                  contractorId,
                );
                final contractor = _contractorCache[contractorId];
                if (!hasContractorRecord) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final name =
                    contractor?['name']?.toString() ?? l10n.unknownContractor;
                final rating =
                    (contractor?['averageRating'] as num?)?.toDouble() ??
                    (contractor?['avgRating'] as num?)?.toDouble() ??
                    0.0;
                final reviewCount =
                    (contractor?['reviewCount'] as num?)?.toInt() ??
                    (contractor?['totalReviews'] as num?)?.toInt() ??
                    0;
                final completedJobs =
                    (contractor?['completedJobs'] as num?)?.toInt() ??
                    (contractor?['totalJobsCompleted'] as num?)?.toInt() ??
                    0;
                final profileImageUrl =
                    contractor?['profileImageUrl'] as String?;
                final verified =
                    contractor?['verificationStatus'] == 'verified' ||
                    contractor?['verified'] == true;
                final insured = contractor?['insured'] == true;
                final licensed = contractor?['licensed'] == true;
                final valueTagged =
                    lowPrice != null && verified && price <= lowPrice * 1.15;
                final lowestTagged =
                    lowPrice != null && (price - lowPrice).abs() < 0.01;
                final trustedTagged = rating >= 4.7 && reviewCount >= 10;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: profileImageUrl != null
                              ? CachedNetworkImageProvider(profileImageUrl)
                              : null,
                          child: profileImageUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
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
                                      Text(
                                        '${rating.toStringAsFixed(1)} ($reviewCount)',
                                      ),
                                    ],
                                  ),
                                  Text(l10n.completedJobsCount(completedJobs)),
                                  Text(
                                    l10n.quoteEtaValue(
                                      estimatedDuration?.trim().isNotEmpty ==
                                              true
                                          ? estimatedDuration!.trim()
                                          : '—',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _proofChip(
                          verified,
                          Icons.verified_user_outlined,
                          l10n.verifiedPro,
                        ),
                        _proofChip(
                          insured,
                          Icons.health_and_safety_outlined,
                          l10n.insured,
                        ),
                        _proofChip(
                          licensed,
                          Icons.badge_outlined,
                          l10n.licensed,
                        ),
                        Chip(
                          avatar: const Icon(Icons.reviews_outlined, size: 16),
                          label: Text(l10n.reviewCountShort(reviewCount)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (valueTagged || lowestTagged || trustedTagged) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (valueTagged)
                            _decisionTag(
                              Icons.workspace_premium_outlined,
                              l10n.quoteTagBestValue,
                              Colors.green,
                            ),
                          if (lowestTagged)
                            _decisionTag(
                              Icons.sell_outlined,
                              l10n.quoteTagLowestPrice,
                              Colors.blue,
                            ),
                          if (trustedTagged)
                            _decisionTag(
                              Icons.verified_outlined,
                              l10n.quoteTagMostTrusted,
                              Colors.teal,
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.price,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (pricingMode != 'manual') ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (pricingMode == 'ai_accept')
                    Chip(
                      avatar: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(l10n.aiPrice),
                    )
                  else if (pricingMode == 'ai_adjust')
                    Chip(
                      avatar: const Icon(Icons.tune, size: 16),
                      label: Text(l10n.adjustedFromAi),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (revisionNumber > 0)
                  Chip(
                    avatar: const Icon(Icons.edit_note, size: 16),
                    label: Text(l10n.revisionNumber(revisionNumber)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (expiresAt != null)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 16),
                    label: Text(
                      l10n.expiresDate(
                        DateFormat.MMMd().format(expiresAt.toDate()),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (sowUrl != null && sowUrl.trim().isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.attach_file, size: 16),
                    label: Text(l10n.scopeAttached),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  avatar: const Icon(Icons.lock_outline, size: 16),
                  label: Text(l10n.protectedPaymentPath),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 12),
            _buildQuoteTrustPanel(
              l10n: l10n,
              scheme: scheme,
              hasScope: sowUrl != null && sowUrl.trim().isNotEmpty,
              hasWarranty: warranty.isNotEmpty,
              hasExclusions: exclusions.isNotEmpty,
              deposit: deposit,
            ),

            if (pricingMode == 'ai_adjust' &&
                adjustmentExplanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                l10n.adjustment,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(adjustmentExplanation),
            ],

            if (notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.notes,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(notes.trim()),
            ],

            if (submittedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.submittedDate(
                  DateFormat.yMMMd().add_jm().format(submittedAt.toDate()),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              const SizedBox(height: 12),
            ],

            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineQuote(quoteId),
                      child: Text(l10n.decline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _acceptQuote(quoteId, quote),
                      child: Text(l10n.acceptQuote),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'accepted') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: Text(l10n.continueJob),
                  onPressed: () => context.push('/job-command/${widget.jobId}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String label;

    switch (status) {
      case 'accepted':
        color = Colors.green;
        label = l10n.accepted;
        break;
      case 'declined':
        color = Colors.red;
        label = l10n.declined;
        break;
      default:
        color = Colors.orange;
        label = l10n.pending;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
    );
  }

  Widget _proofChip(bool active, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        active ? icon : Icons.help_outline,
        size: 16,
        color: active ? Colors.green.shade700 : scheme.onSurfaceVariant,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: active ? Colors.green.withValues(alpha: 0.10) : null,
    );
  }

  Widget _decisionTag(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.11),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }

  Widget _buildQuoteTrustPanel({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required bool hasScope,
    required bool hasWarranty,
    required bool hasExclusions,
    required double? deposit,
  }) {
    final depositLabel = deposit != null && deposit > 0
        ? l10n.depositRequiredAmount('\$${deposit.toStringAsFixed(0)}')
        : l10n.depositNotListed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.beforeYouAccept,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _trustRow(
            hasScope,
            l10n.scopeOfWork,
            hasScope ? l10n.scopeAttached : l10n.scopeMissing,
          ),
          _trustRow(
            hasWarranty,
            l10n.warranty,
            hasWarranty ? l10n.warrantyIncluded : l10n.warrantyNotListed,
          ),
          _trustRow(
            hasExclusions,
            l10n.exclusions,
            hasExclusions ? l10n.exclusionsListed : l10n.exclusionsNotListed,
          ),
          _trustRow(deposit != null && deposit > 0, l10n.deposit, depositLabel),
        ],
      ),
    );
  }

  Widget _trustRow(bool positive, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_circle_outline : Icons.info_outline,
            size: 17,
            color: positive ? Colors.green.shade700 : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptQuote(String quoteId, Map<String, dynamic> quote) async {
    final l10n = AppLocalizations.of(context)!;
    final contractorId = quote['contractorId'] as String;
    final price = (quote['price'] as num).toDouble();
    final contractorName =
        _contractorCache[contractorId]?['name']?.toString() ??
        l10n.unknownContractor;

    final confirmed = await _showAcceptQuoteSheet(
      amount: '\$${price.toStringAsFixed(0)}',
      contractorName: contractorName,
      quote: quote,
    );

    if (!confirmed || !mounted) return;

    await OptimisticUI.executeWithOptimism(
      context: context,
      action: () async {
        // Update quote status
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(quoteId)
            .update({
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });

        // Decline other quotes
        final otherQuotes = await FirebaseFirestore.instance
            .collection('quotes')
            .where('jobId', isEqualTo: widget.jobId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in otherQuotes.docs) {
          if (doc.id != quoteId) {
            await doc.reference.update({'status': 'declined'});
          }
        }

        // Update job request
        await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .update({
              'claimed': true,
              'contractorId': contractorId,
              'claimedBy': contractorId,
              'price': price,
              'status': 'accepted',
              'claimedAt': FieldValue.serverTimestamp(),
              'acceptedQuoteId': quoteId,
              'quoteAcceptedAt': FieldValue.serverTimestamp(),
              'customerNextAction': 'open_job_command_center',
              'customerNextActionLabel': l10n.openJobCommandCenter,
            });
      },
      loadingMessage: l10n.acceptingQuote,
      successMessage: l10n.quoteAcceptedJobAssigned,
      onSuccess: () {
        if (mounted) context.pushReplacement('/job-command/${widget.jobId}');
      },
    );
  }

  Future<bool> _showAcceptQuoteSheet({
    required String amount,
    required String contractorName,
    required Map<String, dynamic> quote,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final warranty = (quote['warranty'] as String?)?.trim();
    final exclusions = (quote['exclusions'] as String?)?.trim();
    final deposit =
        (quote['depositRequired'] as num?)?.toDouble() ??
        (quote['deposit'] as num?)?.toDouble();
    final hasScope = ((quote['sowUrl'] as String?) ?? '').trim().isNotEmpty;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.acceptQuote,
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.acceptQuoteMessage(amount, contractorName),
                  style: Theme.of(sheetContext).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _acceptanceRow(
                        Icons.shield_outlined,
                        l10n.protectedPaymentPath,
                        l10n.escrowAfterApproval,
                      ),
                      _acceptanceRow(
                        Icons.dashboard_customize_outlined,
                        l10n.openJobCommandCenter,
                        l10n.quoteAcceptedHeaderBody,
                      ),
                      _acceptanceRow(
                        hasScope
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        l10n.scopeOfWork,
                        hasScope ? l10n.scopeAttached : l10n.scopeMissing,
                      ),
                      _acceptanceRow(
                        warranty?.isNotEmpty == true
                            ? Icons.verified_outlined
                            : Icons.info_outline,
                        l10n.warranty,
                        warranty?.isNotEmpty == true
                            ? l10n.warrantyIncluded
                            : l10n.warrantyNotListed,
                      ),
                      _acceptanceRow(
                        exclusions?.isNotEmpty == true
                            ? Icons.rule_outlined
                            : Icons.info_outline,
                        l10n.exclusions,
                        exclusions?.isNotEmpty == true
                            ? l10n.exclusionsListed
                            : l10n.exclusionsNotListed,
                      ),
                      _acceptanceRow(
                        deposit != null && deposit > 0
                            ? Icons.payments_outlined
                            : Icons.info_outline,
                        l10n.deposit,
                        deposit != null && deposit > 0
                            ? l10n.depositRequiredAmount(
                                '\$${deposit.toStringAsFixed(0)}',
                              )
                            : l10n.depositNotListed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.accept),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Widget _acceptanceRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _declineQuote(String quoteId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await FirebaseFirestore.instance.collection('quotes').doc(quoteId).update(
        {'status': 'declined', 'declinedAt': FieldValue.serverTimestamp()},
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.quoteDeclined)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      }
    }
  }
}

class SubmitQuoteScreen extends StatefulWidget {
  final String jobId;

  const SubmitQuoteScreen({super.key, required this.jobId});

  @override
  State<SubmitQuoteScreen> createState() => _SubmitQuoteScreenState();
}

class _SubmitQuoteScreenState extends State<SubmitQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  final _aiExplainController = TextEditingController();
  bool _loadingAiEstimate = false;
  String _pricingMode = 'manual'; // manual | ai_accept | ai_adjust

  bool _isSubmitting = false;

  // --- New fields: expiration, SOW, revision ---
  DateTime? _expiresAt;
  PlatformFile? _sowAttachment;
  String? _existingQuoteId; // non-null when revising

  @override
  void initState() {
    super.initState();
    _checkExistingQuote();
  }

  Future<void> _checkExistingQuote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('quotes')
          .where('jobId', isEqualTo: widget.jobId)
          .where('contractorId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        final data = snap.docs.first.data();
        setState(() {
          _existingQuoteId = snap.docs.first.id;
          _priceController.text =
              (data['price'] as num?)?.toStringAsFixed(0) ?? '';
          _durationController.text =
              (data['estimatedDuration'] as String?) ?? '';
          _notesController.text = (data['notes'] as String?) ?? '';
          final expiresRaw = data['expiresAt'];
          if (expiresRaw is Timestamp) {
            _expiresAt = expiresRaw.toDate();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _priceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    _aiExplainController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Map<String, dynamic>? _readAiEstimateFromJob(Map<String, dynamic>? job) {
    final raw = job?['aiEstimate'];
    if (raw is Map) return raw.cast<String, dynamic>();
    return null;
  }

  Future<void> _generateAiEstimate() async {
    if (_loadingAiEstimate) return;

    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    setState(() => _loadingAiEstimate = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('estimateJob');
      await callable.call({'jobId': widget.jobId});

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('AI estimate updated.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'AI estimate failed.')),
      );
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'AI estimate');
    } finally {
      if (mounted) setState(() => _loadingAiEstimate = false);
    }
  }

  Future<void> _submitQuote() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic>? aiEstimate;
      if (_pricingMode != 'manual') {
        final jobSnap = await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .get();
        aiEstimate = _readAiEstimateFromJob(jobSnap.data());
        if (aiEstimate == null) {
          throw Exception('AI estimate is not available yet.');
        }
      }

      if (_pricingMode == 'ai_adjust' &&
          _aiExplainController.text.trim().isEmpty) {
        throw Exception('Please explain why you adjusted the AI price.');
      }

      // Check if already submitted — allow revision instead of blocking.
      final existing = await FirebaseFirestore.instance
          .collection('quotes')
          .where('jobId', isEqualTo: widget.jobId)
          .where('contractorId', isEqualTo: user.uid)
          .get();

      String? sowUrl;
      // Upload SOW attachment if provided.
      if (_sowAttachment != null && _sowAttachment!.bytes != null) {
        try {
          final ref = FirebaseStorage.instance.ref(
            'quotes/${user.uid}/${widget.jobId}/sow_${DateTime.now().millisecondsSinceEpoch}.${_sowAttachment!.extension}',
          );
          await ref.putData(_sowAttachment!.bytes!);
          sowUrl = await ref.getDownloadURL();
        } catch (_) {
          // SOW upload failure is non-blocking.
        }
      }

      final quoteData = <String, dynamic>{
        'jobId': widget.jobId,
        'contractorId': user.uid,
        'price': double.parse(_priceController.text),
        'estimatedDuration': _durationController.text.trim(),
        'notes': _notesController.text.trim(),
        'pricingMode': _pricingMode,
        if (aiEstimate != null) 'aiEstimateSnapshot': aiEstimate,
        if (_pricingMode == 'ai_adjust')
          'aiAdjustmentExplanation': _aiExplainController.text.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        if (_expiresAt != null) 'expiresAt': Timestamp.fromDate(_expiresAt!),
        if (sowUrl != null) 'sowUrl': sowUrl,
      };

      if (existing.docs.isNotEmpty) {
        // Revision: update the existing quote document.
        final existingDoc = existing.docs.first;
        final prevRevision =
            (existingDoc.data()['revisionNumber'] as int?) ?? 0;
        quoteData['revisionNumber'] = prevRevision + 1;
        quoteData['revisedAt'] = FieldValue.serverTimestamp();
        await existingDoc.reference.update(quoteData);
      } else {
        quoteData['revisionNumber'] = 0;
        await FirebaseFirestore.instance.collection('quotes').add(quoteData);

        // Update job with quote count (only for new quotes).
        await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .update({
              'quoteCount': FieldValue.increment(1),
              'lastQuoteAt': FieldValue.serverTimestamp(),
            });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting quote: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Quote')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Provide Your Quote',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a competitive quote to win this job',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('job_requests')
                  .doc(widget.jobId)
                  .snapshots(),
              builder: (context, jobSnap) {
                final job = jobSnap.data?.data();
                final ai = _readAiEstimateFromJob(job);

                final prices =
                    (ai?['prices'] as Map?)?.cast<String, dynamic>() ?? {};
                final low = _asDouble(prices['low']);
                final rec = _asDouble(prices['recommended']);
                final high = _asDouble(prices['premium']);
                final conf = _asDouble(ai?['confidence']);
                final unit = (ai?['unit'] ?? '').toString();
                final qty = _asDouble(ai?['quantity']);
                final aiNotes = (ai?['notes'] ?? '').toString().trim();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'AI estimate',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _loadingAiEstimate
                                  ? null
                                  : _generateAiEstimate,
                              child: Text(
                                _loadingAiEstimate
                                    ? 'Generating…'
                                    : (ai == null ? 'Generate' : 'Refresh'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (ai == null)
                          Text(
                            'No AI estimate yet. Generate one to quickly price this job using a range and confidence score.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        else ...[
                          Text(
                            'Estimated range: \$${low.toStringAsFixed(0)} – \$${high.toStringAsFixed(0)}',
                          ),
                          Text('Suggested price: \$${rec.toStringAsFixed(0)}'),
                          const SizedBox(height: 6),
                          Text(
                            'Confidence: ${(conf * 100).toStringAsFixed(0)}%',
                          ),
                          if (qty > 0)
                            Text(
                              'Assumed: ${qty.toStringAsFixed(0)} ${unit.isEmpty ? "units" : unit}',
                            ),
                          if (aiNotes.isNotEmpty) Text('Notes: $aiNotes'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _pricingMode = 'ai_accept';
                                      _aiExplainController.clear();
                                      _priceController.text = rec
                                          .toStringAsFixed(0);
                                    });
                                  },
                                  child: const Text('Accept AI price'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _pricingMode = 'ai_adjust';
                                      if (_priceController.text
                                          .trim()
                                          .isEmpty) {
                                        _priceController.text = rec
                                            .toStringAsFixed(0);
                                      }
                                    });
                                  },
                                  child: const Text('Adjust & explain'),
                                ),
                              ),
                            ],
                          ),
                          if (_pricingMode == 'ai_adjust') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _aiExplainController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Why are you adjusting the AI price? *',
                                hintText:
                                    'E.g., materials quality, access difficulty, extra prep work...',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (_pricingMode != 'ai_adjust') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please add a brief explanation';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price *',
                hintText: '0.00',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                helperText: 'Your quoted price for this job',
              ),
              keyboardType: TextInputType.number,
              readOnly: _pricingMode == 'ai_accept',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Price must be greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Estimated Duration',
                hintText: '2-3 hours',
                border: OutlineInputBorder(),
                helperText: 'How long will it take? (optional)',
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Tell the customer about your approach...',
                border: OutlineInputBorder(),
                helperText: 'Materials, approach, guarantees, etc. (optional)',
              ),
              maxLines: 5,
            ),

            const SizedBox(height: 16),

            // Expiration Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(
                _expiresAt == null
                    ? 'Set quote expiration (optional)'
                    : 'Expires: ${DateFormat.yMMMd().format(_expiresAt!)}',
              ),
              trailing: _expiresAt != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiresAt = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _expiresAt ??
                      DateTime.now().add(const Duration(days: 14)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _expiresAt = picked);
              },
            ),

            const SizedBox(height: 8),

            // SOW Attachment
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(
                _sowAttachment == null
                    ? 'Attach scope of work (optional)'
                    : _sowAttachment!.name,
              ),
              trailing: _sowAttachment != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _sowAttachment = null),
                    )
                  : null,
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  setState(() => _sowAttachment = result.files.first);
                }
              },
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSubmitting ? null : _submitQuote,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _existingQuoteId != null
                          ? 'Revise Quote'
                          : 'Submit Quote',
                    ),
            ),

            const SizedBox(height: 16),

            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tips for winning quotes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Price competitively\n'
                      '• Provide detailed estimates\n'
                      '• Respond quickly\n'
                      '• Highlight your experience\n'
                      '• Offer guarantees or warranties',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
