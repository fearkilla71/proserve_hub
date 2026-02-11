import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:proserve_hub/services/stripe_service.dart';
import 'package:proserve_hub/widgets/page_header.dart';
import 'package:proserve_hub/widgets/animated_states.dart';
import '../widgets/skeleton_loader.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';

class JobFeedPage extends StatelessWidget {
  const JobFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _JobFeedBody();
  }
}

class _JobFeedBody extends StatefulWidget {
  const _JobFeedBody();

  @override
  State<_JobFeedBody> createState() => _JobFeedBodyState();
}

class _JobFeedBodyState extends State<_JobFeedBody> {
  static const int _pageSize = 25;
  static const double _leadPriceUsd = 50;
  DocumentSnapshot? _oldestLoadedJobDoc;
  final List<DocumentSnapshot> _olderJobs = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _useSimpleQuery = false;
  bool _distanceEnabled = false;
  double _distanceMiles = 25;
  String? _currentZip;
  bool _loadingLocation = false;

  // ─── Advanced filters ──
  String? _serviceFilter;
  double? _minPrice;
  double? _maxPrice;
  int _datePostedDays = 0; // 0 = any, 1/3/7/30 = within N days

  static const List<String> _serviceTypes = [
    'Painting',
    'Plumbing',
    'Electrical',
    'Roofing',
    'Flooring',
    'HVAC',
    'Landscaping',
    'Carpentry',
    'Cleaning',
    'Moving',
    'General',
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
      final zip = (data['zip'] as String?)?.trim();
      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location failed: $e')));
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
    return const PageHeader(
      title: 'Available Leads',
      subtitle: 'Browse and purchase customer project leads',
      padding: EdgeInsets.only(bottom: 16),
    );
  }

  Widget _distanceFilterCard() {
    final scheme = Theme.of(context).colorScheme;
    final zip = _currentZip;
    final hasZip = zip != null && zip.isNotEmpty;
    final rangeLabel = '${_distanceMiles.toStringAsFixed(0)} mi';

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
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
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.near_me_outlined, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby leads',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasZip
                            ? 'Using ZIP $zip'
                            : 'Set your ZIP to filter by distance',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _distanceEnabled && hasZip,
                  onChanged: (value) {
                    if (!hasZip) {
                      _useMyLocation();
                      return;
                    }
                    setState(() => _distanceEnabled = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(hasZip ? 'ZIP $zip' : 'ZIP needed'),
                  avatar: Icon(
                    hasZip ? Icons.location_on_outlined : Icons.location_off,
                    size: 18,
                    color: scheme.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(rangeLabel),
                  avatar: Icon(
                    Icons.route_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '5 mi',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _distanceMiles,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: rangeLabel,
                    onChanged: (_distanceEnabled && hasZip)
                        ? (value) {
                            setState(() => _distanceMiles = value);
                          }
                        : null,
                  ),
                ),
                Text(
                  '100 mi',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
                label: const Text('Use my location'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _serviceFilter != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _datePostedDays > 0;
  }

  void _clearAdvancedFilters() {
    setState(() {
      _serviceFilter = null;
      _minPrice = null;
      _maxPrice = null;
      _datePostedDays = 0;
    });
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
                // Service type
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
    // Service filter
    if (_serviceFilter != null) {
      final svc = (data['service'] ?? '').toString().toLowerCase();
      final svcName = (data['serviceName'] ?? '').toString().toLowerCase();
      final filterLower = _serviceFilter!.toLowerCase();
      if (!svc.contains(filterLower) && !svcName.contains(filterLower)) {
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
    final scheme = Theme.of(context).colorScheme;
    final service = (data['service'] ?? 'Service').toString();
    final description = (data['description'] ?? '').toString().trim();
    final location = (data['location'] ?? 'Unknown').toString();

    final budgetRaw = data['budget'];
    final budget = budgetRaw is num ? budgetRaw.toDouble() : 0.0;

    final createdAt = data['createdAt'];
    final created = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();

    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final posted = DateFormat.yMd().format(created);

    final chipBg = scheme.surfaceContainerHighest;
    final chipFg = scheme.onSurface;
    final priceBg = scheme.primaryContainer.withValues(alpha: 0.22);
    final priceBorder = scheme.primary.withValues(alpha: 0.25);

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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      service,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: chipFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
                  Text(
                    'Lead Price:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    money.format(_leadPriceUsd),
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
                    'Budget: ${money.format(budget)}',
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
                      '${formatDistance(distanceMiles)} away',
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
                    'Posted $posted',
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
                child: const Text('Purchase Lead'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _distanceForJob(Map<String, dynamic> data) {
    if (!_distanceEnabled) return null;
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
      final chosen = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;

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
                      ? scheme.onPrimary.withValues(alpha: 0.16)
                      : scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary
                        ? scheme.onPrimary.withValues(alpha: 0.9)
                        : scheme.primary,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: primary
                    ? FilledButton(
                        onPressed: () => Navigator.pop(context, id),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (badgeWidget(badge) != null) ...[
                                        const SizedBox(width: 10),
                                        badgeWidget(badge)!,
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onPrimary.withValues(
                                            alpha: 0.85,
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
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      )
                    : FilledButton.tonal(
                        onPressed: () => Navigator.pop(context, id),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (badgeWidget(badge) != null) ...[
                                        const SizedBox(width: 10),
                                        badgeWidget(badge)!,
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: scheme.onSurfaceVariant,
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
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Choose non-exclusive (\$50) or exclusive (\$80).',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, right: 16, top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Non-exclusive',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  packButton(
                    id: 'ne_1',
                    title: '1 lead — \$50',
                    subtitle: 'Multiple contractors may purchase',
                  ),
                  packButton(
                    id: 'ne_10',
                    title: '10 leads — \$450',
                    subtitle: '10 non-exclusive credits',
                    badge: 'Popular',
                  ),
                  packButton(
                    id: 'ne_20',
                    title: '20 leads — \$850',
                    subtitle: '20 non-exclusive credits',
                    badge: 'Best value',
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, right: 16, top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Exclusive',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  packButton(
                    id: 'ex_1',
                    title: '1 lead — \$80',
                    subtitle: 'Locks lead so only you can see it',
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

      if (chosen == null || chosen.trim().isEmpty) return;
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
        final message = e.toString().replaceFirst('Exception: ', '').trim();
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
                        for (final invite in invites)
                          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: FirebaseFirestore.instance
                                .collection('job_requests')
                                .doc((invite.data()['jobId'] ?? '').toString())
                                .get(),
                            builder: (context, jobSnap) {
                              final job = jobSnap.data?.data();
                              if (job == null) return const SizedBox.shrink();

                              final service = (job['service'] ?? 'Service')
                                  .toString();
                              final location = (job['location'] ?? 'Unknown')
                                  .toString();
                              final jobId = jobSnap.data!.id;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.mail_outline),
                                title: Text(service),
                                subtitle: Text(location),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  _openJobDetail(jobId: jobId, jobData: job);
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
          if (docs.isEmpty) return const SizedBox.shrink();

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
                      'My unlocked leads',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                            leading: const Icon(Icons.lock_open),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Leads'),
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

                final showBoth = neCredits > 0 && exCredits > 0;
                final showNeOnly = neCredits > 0 && exCredits <= 0;
                final showExOnly = exCredits > 0 && neCredits <= 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (showBoth || showNeOnly)
                          Chip(
                            label: Text('Non-excl: $neCredits'),
                            avatar: const Icon(Icons.group_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (showBoth || showExOnly)
                          Chip(
                            label: Text('Exclusive: $exCredits'),
                            avatar: const Icon(Icons.lock_outline, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (!showBoth && !showNeOnly && !showExOnly)
                          const Chip(
                            label: Text('Credits: 0'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: (user == null)
          ? const Center(child: Text('Please sign in to view jobs.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() ?? <String, dynamic>{};
                final role =
                    (userData['role'] as String?)?.trim().toLowerCase() ?? '';
                final neRaw = userData['leadCredits'] ?? userData['credits'];
                final neCredits = neRaw is num ? neRaw.toInt() : 0;
                final exRaw = userData['exclusiveLeadCredits'];
                final exCredits = exRaw is num ? exRaw.toInt() : 0;
                final totalCredits = neCredits + exCredits;

                final isContractor = role == 'contractor';

                if (isContractor && totalCredits <= 0) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      invitedSection(uid: user.uid),
                      unlockedLeadsSection(uid: user.uid),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buy leads to see available jobs',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'You need lead credits to view the job feed and unlock customer contact info.',
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: showLeadPackSheet,
                                  child: const Text('Buy leads'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

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
                                      'Leads are locked',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'You need lead credits (or an invite) to view the available leads feed. If you just bought credits, give it a moment and try again.',
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: showLeadPackSheet,
                                        child: const Text('Buy leads'),
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
                            'Error loading leads\n\n$raw',
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
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _distanceEnabled
                                                  ? 'No nearby leads in range'
                                                  : 'No leads available right now',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Firestore responded, but there are no matching jobs for the current feed filters.',
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
                              }

                              // Firestore responded via one-shot fetch; render
                              // these leads so the page is usable even if the
                              // realtime stream is stuck.
                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  invitedSection(uid: user.uid),
                                  unlockedLeadsSection(uid: user.uid),
                                  _availableLeadsHeader(context),
                                  _distanceFilterCard(),
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
                          _availableLeadsHeader(context),
                          _distanceFilterCard(),
                          _advancedFiltersCard(),
                          const SizedBox(height: 12),
                          const EmptyStateCard(
                            icon: Icons.inbox_outlined,
                            title: 'No leads available right now',
                            subtitle:
                                'Check back soon—new customer requests will appear here when they are posted.',
                          ),
                        ],
                      );
                      return AnimatedStateSwitcher(
                        stateKey: stateKey,
                        child: stateChild,
                      );
                    }

                    // Header rows: invited bids + unlocked leads + header.
                    const headerCount = 4;

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
                            return _availableLeadsHeader(context);
                          }
                          if (index == 3) {
                            return Column(
                              children: [
                                _distanceFilterCard(),
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
