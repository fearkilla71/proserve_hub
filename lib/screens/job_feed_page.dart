import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:proserve_hub/services/lead_iap_service.dart';
import 'package:proserve_hub/services/stripe_service.dart';
import 'package:proserve_hub/widgets/page_header.dart';
import 'package:proserve_hub/widgets/animated_states.dart';
import '../constants/service_types.dart';
import '../constants/service_guidance.dart';
import '../constants/service_intake.dart';
import '../constants/launch_regions.dart';
import '../l10n/app_localizations.dart';
import '../widgets/skeleton_loader.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';
import '../utils/app_error_handler.dart';
import '../theme/proserve_theme.dart';
import '../widgets/lead_pack_purchase_sheet.dart';

class JobFeedPage extends StatelessWidget {
  const JobFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _JobFeedBody();
  }
}

class _LeadMarketStatusRow extends StatelessWidget {
  const _LeadMarketStatusRow({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? scheme.error : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: warning ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadSignalChip extends StatelessWidget {
  const _LeadSignalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadCreditActivityTile extends StatelessWidget {
  const _LeadCreditActivityTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final type = (data['type'] ?? 'activity').toString();
    final creditType = (data['creditType'] ?? 'shared').toString();
    final deltaRaw = data['delta'];
    final delta = deltaRaw is num ? deltaRaw.toInt() : 0;
    final jobId = (data['jobId'] ?? '').toString();
    final packId = (data['packId'] ?? '').toString();
    final createdAt = data['createdAt'];
    final date = createdAt is Timestamp
        ? DateFormat.MMMd().add_jm().format(createdAt.toDate())
        : l10n.pending;

    final isDebit = delta < 0 || type == 'used';
    final icon = isDebit
        ? Icons.local_activity_outlined
        : Icons.add_circle_outline;
    final color = isDebit ? scheme.error : ProServeColors.accent;
    final title = switch (type) {
      'purchased' => l10n.leadCreditActivityPurchased,
      'used' => l10n.leadCreditActivityUsed,
      'refunded' => l10n.leadCreditActivityRefunded,
      'failed' => l10n.leadCreditActivityFailed,
      _ => l10n.leadCreditActivityGeneric,
    };
    final reference = jobId.isNotEmpty
        ? l10n.leadCreditActivityJobRef(
            jobId.length > 8 ? jobId.substring(0, 8) : jobId,
          )
        : (packId.isNotEmpty
              ? l10n.leadCreditActivityPackRef(packId)
              : l10n.leadCreditActivityLeadCreditsRef);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('$reference · $creditType · $date'),
      trailing: Text(
        delta == 0 ? '—' : '${delta > 0 ? '+' : ''}$delta',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _JobFeedBody extends StatefulWidget {
  const _JobFeedBody();

  @override
  State<_JobFeedBody> createState() => _JobFeedBodyState();
}

class _JobFeedBodyState extends State<_JobFeedBody> {
  static const int _pageSize = 25;
  DocumentSnapshot? _oldestLoadedJobDoc;
  final List<DocumentSnapshot> _olderJobs = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _useSimpleQuery = false;
  bool _distanceEnabled = true;
  double _distanceMiles = 30;
  String? _currentZip;
  bool _loadingLocation = false;

  // ─── My services filter ──
  List<String> _myServices = [];
  bool _matchMyServices = true; // ON by default – only show relevant leads

  // ─── Advanced filters ──
  String? _serviceFilter;
  double? _minPrice;
  double? _maxPrice;
  int _datePostedDays = 0; // 0 = any, 1/3/7/30 = within N days

  static const List<String> _serviceTypes = [
    'Painting',
    ...kContractorServiceCatalog,
  ];

  Future<QuerySnapshot<Map<String, dynamic>>>? _diagnoseFetch;

  bool _isNavigatingToDetail = false;

  @override
  void initState() {
    super.initState();
    _loadProfileZip();
  }

  Future<void> _loadProfileZip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      final contractorDoc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();
      final contractorData = contractorDoc.data() ?? <String, dynamic>{};
      final zip = (data['zip'] as String?)?.trim();
      final services = contractorServicesFromData({...data, ...contractorData});
      final profileRadius =
          (contractorData['radius'] as num?)?.toDouble() ??
          (data['radius'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        _myServices = services;
        // If the contractor has no services selected, disable the filter
        // so they still see all leads.
        if (services.isEmpty) _matchMyServices = false;
        // Use contractor's configured radius, default 30 mi.
        if (profileRadius != null && profileRadius > 0) {
          _distanceMiles = profileRadius.clamp(5.0, 100.0);
        }
      });
      if (zip != null && zip.isNotEmpty) {
        setState(() {
          _currentZip = zip;
          _distanceEnabled = true;
        });
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _useMyLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);
    try {
      final result = await LocationService().getCurrentZipAndCity();
      if (!mounted) return;
      if (result == null || result.zip.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read your location.')),
        );
        return;
      }
      setState(() {
        _currentZip = result.zip.trim();
        _distanceEnabled = true;
      });
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'find your location');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _retryFeed() {
    // Best-effort: if Firestore network was disabled or the client is offline,
    // this can help recover without restarting the app.
    try {
      FirebaseFirestore.instance.enableNetwork();
    } catch (_) {
      // Best-effort.
    }

    setState(() {
      _useSimpleQuery = false;
      _olderJobs.clear();
      _oldestLoadedJobDoc = null;
      _hasMore = true;
      _isLoadingMore = false;
      _diagnoseFetch = null;
    });
  }

  String _prettyFirestoreError(Object error) {
    if (error is FirebaseException) {
      final code = error.code.trim();
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return 'Firestore error ($code): $message';
      }
      return 'Firestore error ($code)';
    }
    return error.toString();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _runDiagnosticFetch() {
    return _baseQuery()
        .limit(_pageSize)
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 10));
  }

  String _formatLeadAnswer(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    return value.toString().trim();
  }

  /// Load multiple job docs by ID without letting one unreadable doc fail a section.
  Future<Map<String, Map<String, dynamic>>> _batchLoadJobs(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final db = FirebaseFirestore.instance;
    final results = <String, Map<String, dynamic>>{};

    // A batched `whereIn` read fails the whole query if any referenced job is
    // no longer readable under rules. Fall back to isolated reads so stale
    // invite/quote references do not break the visible lead sections.
    for (final id in ids.toSet()) {
      try {
        final doc = await db.collection('job_requests').doc(id).get();
        final data = doc.data();
        if (data != null) results[doc.id] = data;
      } catch (error) {
        debugPrint('Skipping unreadable lead reference $id: $error');
      }
    }
    return results;
  }

  void _openJobDetail({required String jobId, Map<String, dynamic>? jobData}) {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await context.push('/job/$jobId', extra: {'jobData': jobData});
      } finally {
        if (mounted) {
          _isNavigatingToDetail = false;
        }
      }
    });
  }

  Widget _availableLeadsHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PageHeader(
      title: l10n.availableLeads,
      subtitle: l10n.availableLeadsSubtitle,
      padding: const EdgeInsets.only(bottom: 16),
    );
  }

  Widget _nearbyLeadsSection() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final zip = _currentZip;
    final hasZip = zip != null && zip.isNotEmpty;
    final rangeLabel = '${_distanceMiles.toStringAsFixed(0)} mi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.near_me_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.leadMarketServiceRadius,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (hasZip)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.leadMarketOnlyWithinRadius(rangeLabel, zip),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.leadMarketSetZipDistance,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '5 mi',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Expanded(
              child: Slider(
                value: _distanceMiles,
                min: 5,
                max: 100,
                divisions: 19,
                label: rangeLabel,
                onChanged: hasZip
                    ? (value) {
                        setState(() => _distanceMiles = value);
                      }
                    : null,
              ),
            ),
            Text(
              '100 mi',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        if (!hasZip) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _loadingLocation ? null : _useMyLocation,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(l10n.useMyLocation),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasActiveFilters() {
    return _matchMyServices ||
        _serviceFilter != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _datePostedDays > 0;
  }

  String _servicesSummary() {
    if (_myServices.isEmpty) return '';
    final visible = _myServices.take(3).join(', ');
    final hidden = _myServices.length - 3;
    if (hidden <= 0) return visible;
    return '$visible +$hidden';
  }

  String _leadMarketEmptyTitle(AppLocalizations l10n, bool hasZip) {
    if (!hasZip) return l10n.leadMarketEmptyZipTitle;
    if (_matchMyServices && _myServices.isNotEmpty) {
      return l10n.leadMarketEmptyServiceTitle;
    }
    if (_serviceFilter != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _datePostedDays > 0) {
      return l10n.leadMarketEmptyFiltersTitle;
    }
    if (_distanceEnabled) return l10n.leadMarketEmptyRadiusTitle;
    return l10n.leadMarketEmptyMarketTitle;
  }

  String _leadMarketEmptySubtitle(
    AppLocalizations l10n,
    bool hasZip,
    String? zip,
  ) {
    if (!hasZip) return l10n.leadMarketEmptyZipSubtitle;
    if (_matchMyServices && _myServices.isNotEmpty) {
      return l10n.leadMarketEmptyServiceSubtitle(_servicesSummary());
    }
    if (_serviceFilter != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _datePostedDays > 0) {
      return l10n.leadMarketEmptyFiltersSubtitle;
    }
    if (_distanceEnabled) {
      return l10n.leadMarketEmptyRadiusSubtitle(
        _distanceMiles.toStringAsFixed(0),
        zip ?? '',
      );
    }
    return l10n.leadMarketEmptyMarketSubtitle;
  }

  void _clearAdvancedFilters() {
    setState(() {
      _matchMyServices = false;
      _serviceFilter = null;
      _minPrice = null;
      _maxPrice = null;
      _datePostedDays = 0;
      // Distance stays enabled — contractors always see leads in their radius.
    });
  }

  Widget _leadMarketEmptyState({
    required Map<String, dynamic> userData,
    required int totalCredits,
    required VoidCallback onBuyCredits,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasFilters = _hasActiveFilters();
    final zip = _currentZip;
    final hasZip = zip != null && zip.isNotEmpty;
    final payoutsReady =
        userData['stripePayoutsEnabled'] == true ||
        userData['payoutsEnabled'] == true;
    final detailsSubmitted = userData['stripeDetailsSubmitted'] == true;
    final hasStripeAccount =
        (userData['stripeAccountId'] as String?)?.trim().isNotEmpty == true;
    final payoutText = payoutsReady
        ? l10n.leadMarketPayoutReady
        : (detailsSubmitted || hasStripeAccount
              ? l10n.leadMarketPayoutPending
              : l10n.leadMarketPayoutBlocked);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    hasFilters
                        ? Icons.filter_alt_outlined
                        : Icons.local_activity_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _leadMarketEmptyTitle(l10n, hasZip),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(_leadMarketEmptySubtitle(l10n, hasZip, zip)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LeadMarketStatusRow(
              icon: Icons.local_activity_outlined,
              text: l10n.leadMarketCreditBalance(totalCredits),
            ),
            _LeadMarketStatusRow(
              icon: Icons.near_me_outlined,
              text: hasZip
                  ? l10n.leadMarketRadiusStatus(
                      _distanceMiles.toStringAsFixed(0),
                      zip,
                    )
                  : l10n.leadMarketZipMissing,
            ),
            _LeadMarketStatusRow(
              icon: payoutsReady
                  ? Icons.verified_user_outlined
                  : Icons.account_balance_wallet_outlined,
              text: payoutText,
              warning: !payoutsReady,
            ),
            if (_matchMyServices)
              _LeadMarketStatusRow(
                icon: Icons.handyman_outlined,
                text: l10n.leadMarketServiceFilterOn,
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _retryFeed,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.refresh),
                ),
                OutlinedButton.icon(
                  onPressed: onBuyCredits,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.leadMarketBuyCredits),
                ),
                if (hasFilters)
                  OutlinedButton.icon(
                    onPressed: _clearAdvancedFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: Text(l10n.leadMarketClearFilters),
                  ),
                if (hasZip)
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _distanceMiles = (_distanceMiles + 20).clamp(5.0, 100.0);
                    }),
                    icon: const Icon(Icons.zoom_out_map_outlined),
                    label: Text(l10n.leadMarketExpandRadius),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _leadMarketplaceStatusPanel({
    required Map<String, dynamic> userData,
    required int sharedCredits,
    required int exclusiveCredits,
    required VoidCallback onBuyCredits,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final zip = _currentZip;
    final hasZip = zip != null && zip.isNotEmpty;
    final payoutsReady =
        userData['stripePayoutsEnabled'] == true ||
        userData['payoutsEnabled'] == true;
    final servicesCount = _myServices.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: scheme.primaryContainer.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.radar_outlined, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.leadMarketplaceStatusTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onBuyCredits,
                    child: Text(l10n.leadMarketBuyCredits),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LeadSignalChip(
                    icon: Icons.confirmation_number_outlined,
                    label: l10n.leadMarketSharedCreditsShort(sharedCredits),
                  ),
                  _LeadSignalChip(
                    icon: Icons.lock_outline,
                    label: l10n.leadMarketExclusiveCreditsShort(
                      exclusiveCredits,
                    ),
                  ),
                  _LeadSignalChip(
                    icon: Icons.near_me_outlined,
                    label: hasZip
                        ? l10n.leadMarketDistanceFromZip(
                            _distanceMiles.toStringAsFixed(0),
                            zip,
                          )
                        : l10n.leadMarketSetZipShort,
                  ),
                  _LeadSignalChip(
                    icon: Icons.flash_on_outlined,
                    label: l10n.leadMarketFreshLeadsImmediate,
                  ),
                  _LeadSignalChip(
                    icon: Icons.handyman_outlined,
                    label: servicesCount == 0
                        ? l10n.leadMarketAddServices
                        : l10n.leadMarketServicesCount(servicesCount),
                  ),
                  _LeadSignalChip(
                    icon: payoutsReady
                        ? Icons.verified_user_outlined
                        : Icons.account_balance_wallet_outlined,
                    label: payoutsReady
                        ? l10n.leadMarketPayoutsReadyShort
                        : l10n.leadMarketPayoutsBlockedShort,
                  ),
                  if (_hasActiveFilters())
                    _LeadSignalChip(
                      icon: Icons.filter_alt_outlined,
                      label: l10n.leadMarketFiltersActiveShort,
                    ),
                ],
              ),
              if (!payoutsReady) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.leadMarketPayoutBlockedExplain,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadCreditActivitySection({required String uid}) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('lead_credit_transactions')
          .where('userId', isEqualTo: uid)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        if (!snap.hasData) return const SizedBox.shrink();

        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final at = a.data()['createdAt'] as Timestamp?;
            final bt = b.data()['createdAt'] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.32),
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              leading: Icon(Icons.receipt_long_outlined, color: scheme.primary),
              title: Text(
                l10n.leadCreditActivityTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                docs.isEmpty
                    ? l10n.leadCreditActivityEmptySubtitle
                    : l10n.leadCreditActivitySubtitle,
              ),
              children: [
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.leadCreditActivityEmptyBody)),
                      ],
                    ),
                  )
                else
                  for (final doc in docs)
                    _LeadCreditActivityTile(data: doc.data()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _advancedFiltersCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: ExpansionTile(
        leading: Badge(
          isLabelVisible: _hasActiveFilters(),
          child: Icon(Icons.tune, color: scheme.primary),
        ),
        title: Text(
          'Filters',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        trailing: _hasActiveFilters()
            ? TextButton(
                onPressed: _clearAdvancedFilters,
                child: const Text('Clear'),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── My services toggle ──
                if (_myServices.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.handyman_outlined,
                        color: scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My services only',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Show leads matching your ${_myServices.length} selected service${_myServices.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _matchMyServices,
                        onChanged: (v) => setState(() => _matchMyServices = v),
                      ),
                    ],
                  ),
                  if (_matchMyServices)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _myServices
                            .map(
                              (s) => Chip(
                                label: Text(s),
                                visualDensity: VisualDensity.compact,
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.primary),
                                side: BorderSide(
                                  color: scheme.primary.withValues(alpha: 0.3),
                                ),
                                backgroundColor: scheme.primaryContainer
                                    .withValues(alpha: 0.15),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const Divider(height: 28),
                ],

                // Nearby leads
                _nearbyLeadsSection(),
                const Divider(height: 28),
                // Service type (manual)
                Text(
                  'Service type',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _serviceFilter == null,
                      onSelected: (_) => setState(() => _serviceFilter = null),
                    ),
                    ..._serviceTypes.map(
                      (svc) => FilterChip(
                        label: Text(svc),
                        selected: _serviceFilter == svc,
                        onSelected: (sel) =>
                            setState(() => _serviceFilter = sel ? svc : null),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Price range
                Text(
                  'Budget range',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Any'),
                      selected: _minPrice == null && _maxPrice == null,
                      onSelected: (_) {
                        setState(() {
                          _minPrice = null;
                          _maxPrice = null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('< \$500'),
                      selected: _maxPrice == 500 && _minPrice == null,
                      onSelected: (sel) {
                        setState(() {
                          _minPrice = sel ? null : null;
                          _maxPrice = sel ? 500 : null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('\$500 – \$2k'),
                      selected: _minPrice == 500 && _maxPrice == 2000,
                      onSelected: (sel) {
                        setState(() {
                          _minPrice = sel ? 500 : null;
                          _maxPrice = sel ? 2000 : null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('\$2k – \$10k'),
                      selected: _minPrice == 2000 && _maxPrice == 10000,
                      onSelected: (sel) {
                        setState(() {
                          _minPrice = sel ? 2000 : null;
                          _maxPrice = sel ? 10000 : null;
                        });
                      },
                    ),
                    FilterChip(
                      label: const Text('\$10k+'),
                      selected: _minPrice == 10000 && _maxPrice == null,
                      onSelected: (sel) {
                        setState(() {
                          _minPrice = sel ? 10000 : null;
                          _maxPrice = null;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Date posted
                Text(
                  'Posted within',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in {
                      0: 'Any time',
                      1: '24 hours',
                      3: '3 days',
                      7: '1 week',
                      30: '30 days',
                    }.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _datePostedDays == entry.key,
                        onSelected: (_) =>
                            setState(() => _datePostedDays = entry.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _passesAdvancedFilters(Map<String, dynamic> data) {
    // ── My-services filter ──
    if (_matchMyServices && _myServices.isNotEmpty) {
      final svc = (data['service'] ?? '').toString();
      final svcName = (data['serviceName'] ?? '').toString();
      final matched = _myServices.any(
        (mine) => serviceMatches(mine, svc) || serviceMatches(mine, svcName),
      );
      if (!matched) return false;
    }

    // Service filter (manual override)
    if (_serviceFilter != null) {
      final svc = (data['service'] ?? '').toString();
      final svcName = (data['serviceName'] ?? '').toString();
      if (!serviceMatches(_serviceFilter!, svc) &&
          !serviceMatches(_serviceFilter!, svcName)) {
        return false;
      }
    }

    // Price filter
    final budget =
        (data['budget'] as num?)?.toDouble() ??
        (data['price'] as num?)?.toDouble();
    if (_minPrice != null && (budget == null || budget < _minPrice!)) {
      return false;
    }
    if (_maxPrice != null && (budget == null || budget > _maxPrice!)) {
      return false;
    }

    // Date posted filter
    if (_datePostedDays > 0) {
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final postedDate = createdAt.toDate();
        final cutoff = DateTime.now().subtract(Duration(days: _datePostedDays));
        if (postedDate.isBefore(cutoff)) return false;
      }
    }

    return true;
  }

  Widget _leadCard({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> data,
    double? distanceMiles,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final service = (data['service'] ?? l10n.service).toString();
    final description = (data['description'] ?? '').toString().trim();
    final contractorBrief = (data['contractorBrief'] ?? '').toString().trim();
    final leadQualityLabel = (data['leadQualityLabel'] ?? '').toString().trim();
    final leadQualityScore = (data['leadQualityScore'] as num?)?.toInt();
    final missingLeadFields =
        (data['missingLeadFields'] as List?)
            ?.whereType<String>()
            .where((field) => field.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final imageCount =
        (data['imagePaths'] as List?)?.whereType<String>().length ?? 0;
    final urgency = (data['urgency'] ?? data['timeline'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final matchTags =
        (data['matchTags'] as List?)
            ?.whereType<String>()
            .where((tag) => tag.trim().isNotEmpty)
            .take(3)
            .toList() ??
        const <String>[];
    final sharedUnlockCount =
        (data['paidBy'] as List?)?.whereType<String>().length ?? 0;
    final exclusiveAvailable = (data['leadUnlockedBy'] ?? '')
        .toString()
        .trim()
        .isEmpty;
    final serviceAnswers = data['serviceAnswers'] is Map
        ? Map<String, dynamic>.from(data['serviceAnswers'] as Map)
        : const <String, dynamic>{};
    final location = (data['location'] ?? 'Unknown').toString();
    final guidance = guidanceForService(service);
    final intakeDefinition = intakeDefinitionForService(service);
    final pricingMode = (data['pricingMode'] ?? '').toString();
    final manualQuote =
        pricingMode == 'manual_quote' ||
        data['instantPriceSupported'] == false ||
        !supportsInstantPrice(service);

    final budgetRaw = data['budget'];
    final budget = budgetRaw is num ? budgetRaw.toDouble() : 0.0;

    final createdAt = data['createdAt'];
    final created = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();

    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final posted = DateFormat.yMd().format(created);

    final priceBg = scheme.primaryContainer.withValues(alpha: 0.22);
    final priceBorder = scheme.primary.withValues(alpha: 0.25);

    final isEscrow =
        data['instantBook'] == true ||
        (data['escrowId'] ?? '').toString().isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEscrow) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ProServeColors.accent,
                          ProServeColors.accent.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 12,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          l10n.escrow,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    service,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _LeadSignalChip(
                  icon: exclusiveAvailable
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  label: exclusiveAvailable
                      ? l10n.leadMarketExclusiveAvailable
                      : l10n.leadMarketSharedOnly,
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LeadSignalChip(
                  icon: manualQuote
                      ? Icons.request_quote_outlined
                      : Icons.bolt_outlined,
                  label: manualQuote
                      ? l10n.leadMarketManualQuote
                      : l10n.leadMarketInstantPriceReady,
                ),
                if (_myServices.any((mine) => serviceMatches(mine, service)))
                  _LeadSignalChip(
                    icon: Icons.handyman_outlined,
                    label: l10n.leadMarketMatchesYourServices,
                  ),
                if (leadQualityLabel.isNotEmpty)
                  _LeadSignalChip(
                    icon: leadQualityScore != null && leadQualityScore >= 75
                        ? Icons.verified_outlined
                        : Icons.info_outline,
                    label: leadQualityScore == null
                        ? leadQualityLabel
                        : '$leadQualityLabel · $leadQualityScore%',
                  ),
                _LeadSignalChip(
                  icon: Icons.groups_2_outlined,
                  label: l10n.leadMarketSharedUnlockCount(sharedUnlockCount),
                ),
                _LeadSignalChip(
                  icon: Icons.photo_library_outlined,
                  label: l10n.leadMarketPhotoCount(imageCount),
                ),
                if (urgency.isNotEmpty)
                  _LeadSignalChip(
                    icon: urgency == 'asap'
                        ? Icons.priority_high_outlined
                        : Icons.schedule_outlined,
                    label: urgency == 'asap' ? 'ASAP' : urgency,
                  ),
                ...matchTags.map(
                  (tag) => _LeadSignalChip(
                    icon: Icons.sell_outlined,
                    label: tag.replaceAll('-', ' '),
                  ),
                ),
                ...guidance.matchSignals
                    .take(1)
                    .map(
                      (signal) => _LeadSignalChip(
                        icon: Icons.verified_outlined,
                        label: signal,
                      ),
                    ),
              ],
            ),
            if (manualQuote) ...[
              const SizedBox(height: 10),
              Text(
                guidance.manualQuoteReason ??
                    l10n.leadMarketManualQuoteFallbackReason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (contractorBrief.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contractorBrief,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (serviceAnswers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: serviceAnswers.entries
                      .where(
                        (entry) => _formatLeadAnswer(entry.value).isNotEmpty,
                      )
                      .take(3)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.checklist_outlined,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  answerLabelForId(intakeDefinition, entry.key),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatLeadAnswer(entry.value),
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (missingLeadFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.leadMarketMayNeedFollowUp(
                  missingLeadFields.take(2).join(', '),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: priceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: priceBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.sell_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.leadMarketUnlockModelDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    l10n.leadMarketOneCredit,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.attach_money, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    budget > 0
                        ? l10n.leadMarketBudgetLabel(money.format(budget))
                        : l10n.leadMarketBudgetNotSet,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (distanceMiles != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.route_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.leadMarketDistanceAway(
                        formatDistance(distanceMiles),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.leadMarketPostedDate(posted),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _openJobDetail(jobId: jobId, jobData: data);
                },
                child: Text(l10n.leadMarketViewUnlockLead),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _distanceForJob(Map<String, dynamic> data) {
    final zip = _currentZip;
    if (zip == null || zip.trim().isEmpty) return null;

    final jobZip =
        extractZip(data) ?? extractZipFromString(data['location']?.toString());
    if (jobZip == null || jobZip.isEmpty) return null;

    return distanceMilesBetweenZips(zip, jobZip);
  }

  Query<Map<String, dynamic>> _baseQuery() {
    // Firestore rules only allow contractors to read jobs that are not claimed.
    // If we query across claimed jobs, the entire query can fail with
    // permission-denied.
    //
    // For exclusive leads, once a job is unlocked by a contractor, it should no
    // longer appear in the open feed for other contractors. We represent that
    // with `leadUnlockedBy` on the job.
    //
    // The preferred query orders by createdAt, but that often requires a
    // composite index. If that index isn't deployed yet, we fall back to a
    // simpler query to keep the feed usable.
    final base = FirebaseFirestore.instance
        .collection('job_requests')
        .where('launchRegion', isEqualTo: kLaunchRegionHoustonMetro)
        .where('claimed', isEqualTo: false)
        .where('leadUnlockedBy', isNull: true);

    if (_useSimpleQuery) return base;
    return base.orderBy('createdAt', descending: true);
  }

  bool _looksLikeMissingIndex(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('requires an index') ||
        msg.contains('failed_precondition') ||
        msg.contains('failed precondition');
  }

  Future<void> _loadMore() async {
    if (_useSimpleQuery) return;
    if (_isLoadingMore || !_hasMore) return;
    if (_oldestLoadedJobDoc == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snap = await _baseQuery()
          .startAfterDocument(_oldestLoadedJobDoc!)
          .limit(_pageSize)
          .get();

      if (snap.docs.isNotEmpty) {
        _oldestLoadedJobDoc = snap.docs.last;
        if (mounted) {
          setState(() {
            _olderJobs.addAll(snap.docs);
          });
        }
      }

      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Future<void> showLeadPackSheet() async {
      final chosen = await showLeadPackPurchaseSheet(context);

      if (chosen == null || chosen.trim().isEmpty) return;

      // Use native Google Play / App Store IAP on mobile for single-lead packs.
      // Bulk packs (10, 20) go through Stripe.
      if (LeadIapService.supported && LeadIapService.isIapPack(chosen)) {
        try {
          final iap = LeadIapService.instance;
          // Show a brief loading indicator while the store processes.
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening store...'),
                duration: Duration(seconds: 2),
              ),
            );
          }

          // One-shot listener to notify user on purchase result.
          void handleUpdate(PurchaseDetails p) {
            if (!context.mounted) return;
            if (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lead credits added!')),
              );
              iap.onPurchaseUpdate = null;
            } else if (p.status == PurchaseStatus.error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(p.error?.message ?? 'Purchase failed')),
              );
              iap.onPurchaseUpdate = null;
            } else if (p.status == PurchaseStatus.canceled) {
              iap.onPurchaseUpdate = null;
            }
          }

          iap.onPurchaseUpdate = handleUpdate;
          await iap.buy(chosen);
        } catch (e) {
          if (!context.mounted) return;
          final message = AppError.message(e, action: 'open the store');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }

      // Stripe Checkout for web / desktop / bulk lead packs (10, 20).
      try {
        await StripeService().buyLeadPack(packId: chosen);

        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Complete checkout to add lead credits.'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final message = AppError.message(e, action: 'open checkout');
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }

    Widget invitedSection({required String uid}) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          final data = userSnap.data?.data() ?? <String, dynamic>{};
          final role = (data['role'] as String?)?.trim().toLowerCase() ?? '';
          if (role != 'contractor') return const SizedBox.shrink();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bid_invites')
                .where('contractorId', isEqualTo: uid)
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, invitesSnap) {
              if (invitesSnap.hasError) {
                return const SizedBox.shrink();
              }

              if (!invitesSnap.hasData) {
                return const SizedBox.shrink();
              }

              final invites = invitesSnap.data!.docs;
              if (invites.isEmpty) return const SizedBox.shrink();

              final jobIds = invites
                  .map((d) => (d.data()['jobId'] ?? '').toString())
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList();

              return FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _batchLoadJobs(jobIds),
                builder: (context, jobsSnap) {
                  if (!jobsSnap.hasData) {
                    return const SizedBox.shrink();
                  }
                  final jobsMap = jobsSnap.data ?? {};
                  final visibleInvites = invites.where((invite) {
                    final jobId = (invite.data()['jobId'] ?? '').toString();
                    return jobsMap.containsKey(jobId);
                  }).toList();
                  if (visibleInvites.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invited to bid',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            for (final invite in visibleInvites)
                              Builder(
                                builder: (context) {
                                  final jobId = (invite.data()['jobId'] ?? '')
                                      .toString();
                                  final job = jobsMap[jobId];
                                  if (job == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final l10n = AppLocalizations.of(context)!;
                                  final service =
                                      (job['service'] ?? l10n.service)
                                          .toString();
                                  final location =
                                      (job['location'] ?? l10n.unknown)
                                          .toString();
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.mail_outline),
                                    title: Text(service),
                                    subtitle: Text(location),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      _openJobDetail(
                                        jobId: jobId,
                                        jobData: job,
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }

    Widget unlockedLeadsSection({required String uid}) {
      // Query unlocked leads directly — no need to nest inside a user-doc
      // StreamBuilder, which would recreate the inner stream on every user-doc
      // emit and cause visible flickering.
      // Remove .orderBy to avoid composite index dependency; sort client-side.
      final q = FirebaseFirestore.instance
          .collection('job_requests')
          .where('paidBy', arrayContains: uid)
          .limit(10);

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const SizedBox.shrink();
          if (!snap.hasData) return const SizedBox.shrink();

          final docs = snap.data!.docs.toList();
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: ProServeColors.accent.withValues(
                          alpha: 0.12,
                        ),
                        child: const Icon(
                          Icons.local_activity_outlined,
                          color: ProServeColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No unlocked leads yet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Leads you unlock or win will appear here so you can follow up and quote fast.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Sort newest first client-side.
          docs.sort((a, b) {
            final ta = a.data()['createdAt'] as Timestamp?;
            final tb = b.data()['createdAt'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
          final limited = docs.take(5).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlocked leads & won jobs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final doc in limited)
                      Builder(
                        builder: (context) {
                          final job = doc.data();
                          final service = (job['service'] ?? 'Service')
                              .toString();
                          final location = (job['location'] ?? 'Unknown')
                              .toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.local_activity_outlined,
                              color: ProServeColors.accent,
                            ),
                            title: Text(service),
                            subtitle: Text(location),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _openJobDetail(jobId: doc.id, jobData: job);
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    Widget submittedQuotesSection({required String uid}) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('quotes')
            .where('contractorId', isEqualTo: uid)
            .limit(10)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
          final quotes = snap.data!.docs.toList();
          if (quotes.isEmpty) return const SizedBox.shrink();

          quotes.sort((a, b) {
            final at = a.data()['submittedAt'] as Timestamp?;
            final bt = b.data()['submittedAt'] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

          final jobIds = quotes
              .map((d) => (d.data()['jobId'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _batchLoadJobs(jobIds),
            builder: (context, jobsSnap) {
              final jobsMap = jobsSnap.data ?? {};
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submitted quotes',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        for (final quote in quotes.take(5))
                          Builder(
                            builder: (context) {
                              final q = quote.data();
                              final jobId = (q['jobId'] ?? '').toString();
                              final job = jobsMap[jobId] ?? const {};
                              final service = (job['service'] ?? 'Project')
                                  .toString();
                              final status = (q['status'] ?? 'pending')
                                  .toString();
                              final price = q['price'];
                              final amount = price is num
                                  ? NumberFormat.currency(
                                      symbol: r'$',
                                      decimalDigits: 0,
                                    ).format(price)
                                  : 'Quote sent';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.description_outlined,
                                  color: ProServeColors.accent2,
                                ),
                                title: Text(service),
                                subtitle: Text('$amount · $status'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: jobId.isEmpty
                                    ? null
                                    : () => context.push('/job-command/$jobId'),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.jobs),
        actions: [
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final data = snap.data!.data() as Map<String, dynamic>?;
                final neRaw = data?['leadCredits'] ?? data?['credits'];
                final neCredits = neRaw is num ? neRaw.toInt() : 0;
                final exRaw = data?['exclusiveLeadCredits'];
                final exCredits = exRaw is num ? exRaw.toInt() : 0;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_activity_outlined,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$neCredits',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$exCredits',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: AppLocalizations.of(context)!.leadMarketBuyLeads,
                      onPressed: showLeadPackSheet,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: (user == null)
          ? Center(child: Text(AppLocalizations.of(context)!.signInRequired))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() ?? <String, dynamic>{};

                // Keep services in sync reactively.
                final latestServices = contractorServicesFromData(userData);
                if (latestServices.length != _myServices.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _myServices = latestServices;
                      });
                    }
                  });
                }

                final neRaw = userData['leadCredits'] ?? userData['credits'];
                final neCredits = neRaw is num ? neRaw.toInt() : 0;
                final exRaw = userData['exclusiveLeadCredits'];
                final exCredits = exRaw is num ? exRaw.toInt() : 0;
                final totalCredits = neCredits + exCredits;

                return StreamBuilder<QuerySnapshot>(
                  stream: _baseQuery()
                      .limit(_pageSize)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, snapshot) {
                    late final String stateKey;
                    late final Widget stateChild;

                    if (snapshot.hasError) {
                      final raw = snapshot.error.toString();
                      final messageLower = raw.toLowerCase();

                      if (!_useSimpleQuery &&
                          _looksLikeMissingIndex(snapshot.error!)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _useSimpleQuery = true;
                            _olderJobs.clear();
                            _oldestLoadedJobDoc = null;
                            _hasMore = false;
                            _isLoadingMore = false;
                          });
                        });
                        stateKey = 'missing_index';
                        stateChild = ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5,
                          itemBuilder: (context, index) =>
                              const JobCardSkeleton(),
                        );
                        return AnimatedStateSwitcher(
                          stateKey: stateKey,
                          child: stateChild,
                        );
                      }

                      // Most common case in production: rules block the feed
                      // (no credits / wrong role). Show a friendly CTA.
                      if (messageLower.contains('permission-denied') ||
                          messageLower.contains('permission denied')) {
                        stateKey = 'permission_denied';
                        stateChild = ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            invitedSection(uid: user.uid),
                            unlockedLeadsSection(uid: user.uid),
                            _availableLeadsHeader(context),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.leadMarketLeadsLockedTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.leadMarketLeadsLockedBody,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: showLeadPackSheet,
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.leadMarketBuyLeads,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                        return AnimatedStateSwitcher(
                          stateKey: stateKey,
                          child: stateChild,
                        );
                      }

                      stateKey = 'error';
                      stateChild = Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            AppError.message(
                              snapshot.error,
                              action: 'load leads',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                      return AnimatedStateSwitcher(
                        stateKey: stateKey,
                        child: stateChild,
                      );
                    }

                    if (!snapshot.hasData) {
                      stateKey = 'loading';
                      stateChild = FutureBuilder<void>(
                        future: Future<void>.delayed(
                          const Duration(seconds: 6),
                        ),
                        builder: (context, delaySnap) {
                          if (delaySnap.connectionState !=
                              ConnectionState.done) {
                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: 5,
                              itemBuilder: (context, index) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: JobCardSkeleton(),
                                );
                              },
                            );
                          }

                          _diagnoseFetch ??= _runDiagnosticFetch();

                          return FutureBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            future: _diagnoseFetch,
                            builder: (context, diagSnap) {
                              if (diagSnap.connectionState !=
                                  ConnectionState.done) {
                                return ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    for (var i = 0; i < 3; i++) ...[
                                      const JobCardSkeleton(),
                                      const SizedBox(height: 12),
                                    ],
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Still loading leads…',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text('Diagnosing Firestore…'),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: _retryFeed,
                                                icon: const Icon(Icons.refresh),
                                                label: const Text('Retry'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              if (diagSnap.hasError) {
                                final raw = diagSnap.error!;
                                final rawLower = raw.toString().toLowerCase();
                                final pretty = _prettyFirestoreError(raw);

                                final showBuyLeads =
                                    rawLower.contains('permission-denied') ||
                                    rawLower.contains('permission denied');

                                final showIndexHelp =
                                    !_useSimpleQuery &&
                                    _looksLikeMissingIndex(raw);

                                return ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    invitedSection(uid: user.uid),
                                    unlockedLeadsSection(uid: user.uid),
                                    submittedQuotesSection(uid: user.uid),
                                    _availableLeadsHeader(context),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Couldn\'t load leads',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(pretty),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: _retryFeed,
                                                icon: const Icon(Icons.refresh),
                                                label: const Text('Retry'),
                                              ),
                                            ),
                                            if (showIndexHelp) ...[
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                width: double.infinity,
                                                child: FilledButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      _useSimpleQuery = true;
                                                      _diagnoseFetch = null;
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons.auto_fix_high,
                                                  ),
                                                  label: const Text(
                                                    'Try simplified query',
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (showBuyLeads) ...[
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                width: double.infinity,
                                                child: FilledButton(
                                                  onPressed: showLeadPackSheet,
                                                  child: const Text(
                                                    'Buy leads',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              final snap = diagSnap.data;
                              final docs = snap?.docs ?? const [];
                              final filteredDocs = docs.where((doc) {
                                final data = doc.data();
                                // Distance filter
                                if (_distanceEnabled) {
                                  final distance = _distanceForJob(data);
                                  if (distance == null ||
                                      distance > _distanceMiles) {
                                    return false;
                                  }
                                }
                                // Advanced filters
                                if (!_passesAdvancedFilters(data)) return false;
                                return true;
                              }).toList();

                              if (filteredDocs.isEmpty) {
                                return ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    invitedSection(uid: user.uid),
                                    unlockedLeadsSection(uid: user.uid),
                                    _availableLeadsHeader(context),
                                    _leadMarketplaceStatusPanel(
                                      userData: userData,
                                      sharedCredits: neCredits,
                                      exclusiveCredits: exCredits,
                                      onBuyCredits: showLeadPackSheet,
                                    ),
                                    _leadCreditActivitySection(uid: user.uid),
                                    _leadMarketEmptyState(
                                      userData: userData,
                                      totalCredits: totalCredits,
                                      onBuyCredits: showLeadPackSheet,
                                    ),
                                  ],
                                );
                              }

                              // Firestore responded via one-shot fetch; render
                              // these leads so the page is usable even if the
                              // realtime stream is stuck.
                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  invitedSection(uid: user.uid),
                                  unlockedLeadsSection(uid: user.uid),
                                  submittedQuotesSection(uid: user.uid),
                                  _availableLeadsHeader(context),
                                  _leadMarketplaceStatusPanel(
                                    userData: userData,
                                    sharedCredits: neCredits,
                                    exclusiveCredits: exCredits,
                                    onBuyCredits: showLeadPackSheet,
                                  ),
                                  _leadCreditActivitySection(uid: user.uid),
                                  _advancedFiltersCard(),
                                  const SizedBox(height: 12),
                                  for (final doc in filteredDocs) ...[
                                    _leadCard(
                                      context: context,
                                      jobId: doc.id,
                                      data: doc.data(),
                                      distanceMiles: _distanceForJob(
                                        doc.data(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Live updates may be delayed',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Loaded these leads via a one-time fetch. If changes aren\'t appearing automatically, use Refresh.',
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: _retryFeed,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Refresh'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );

                      return AnimatedStateSwitcher(
                        stateKey: stateKey,
                        child: stateChild,
                      );
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isNotEmpty) {
                      _oldestLoadedJobDoc = docs.last;
                    }

                    final allDocs = <DocumentSnapshot>[...docs, ..._olderJobs];
                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) return false;
                      // Distance filter
                      if (_distanceEnabled) {
                        final distance = _distanceForJob(data);
                        if (distance == null || distance > _distanceMiles) {
                          return false;
                        }
                      }
                      // Advanced filters
                      if (!_passesAdvancedFilters(data)) return false;
                      return true;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      stateKey = 'empty';
                      stateChild = ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          invitedSection(uid: user.uid),
                          unlockedLeadsSection(uid: user.uid),
                          submittedQuotesSection(uid: user.uid),
                          _availableLeadsHeader(context),
                          _leadMarketplaceStatusPanel(
                            userData: userData,
                            sharedCredits: neCredits,
                            exclusiveCredits: exCredits,
                            onBuyCredits: showLeadPackSheet,
                          ),
                          _leadCreditActivitySection(uid: user.uid),
                          _advancedFiltersCard(),
                          const SizedBox(height: 12),
                          _leadMarketEmptyState(
                            userData: userData,
                            totalCredits: totalCredits,
                            onBuyCredits: showLeadPackSheet,
                          ),
                        ],
                      );
                      return AnimatedStateSwitcher(
                        stateKey: stateKey,
                        child: stateChild,
                      );
                    }

                    // Header rows: invited bids + unlocked leads + header.
                    const headerCount = 7;

                    stateKey = 'list';
                    stateChild = NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                            n.metrics.maxScrollExtent - 200) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            headerCount +
                            filteredDocs.length +
                            (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return invitedSection(uid: user.uid);
                          }
                          if (index == 1) {
                            return unlockedLeadsSection(uid: user.uid);
                          }
                          if (index == 2) {
                            return submittedQuotesSection(uid: user.uid);
                          }
                          if (index == 3) {
                            return _availableLeadsHeader(context);
                          }
                          if (index == 4) {
                            return _leadMarketplaceStatusPanel(
                              userData: userData,
                              sharedCredits: neCredits,
                              exclusiveCredits: exCredits,
                              onBuyCredits: showLeadPackSheet,
                            );
                          }
                          if (index == 5) {
                            return _leadCreditActivitySection(uid: user.uid);
                          }
                          if (index == 6) {
                            return Column(
                              children: [
                                _advancedFiltersCard(),
                                const SizedBox(height: 12),
                              ],
                            );
                          }

                          final listIndex = index - headerCount;

                          if (_hasMore && listIndex == filteredDocs.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoadingMore
                                    ? const CircularProgressIndicator()
                                    : const SizedBox.shrink(),
                              ),
                            );
                          }

                          final doc = filteredDocs[listIndex];
                          final data = doc.data() as Map<String, dynamic>?;
                          if (data == null) return const SizedBox.shrink();

                          return Column(
                            children: [
                              _leadCard(
                                context: context,
                                jobId: doc.id,
                                data: data,
                                distanceMiles: _distanceForJob(data),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
                    );

                    return AnimatedStateSwitcher(
                      stateKey: stateKey,
                      child: stateChild,
                    );
                  },
                );
              },
            ),
    );
  }
}
