import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/location_service.dart';
import '../services/favorites_service.dart';
import '../utils/geo_utils.dart';
import '../theme/proserve_theme.dart';
import '../constants/service_types.dart';
import '../constants/service_guidance.dart';

class BrowseContractorsScreen extends StatefulWidget {
  const BrowseContractorsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<BrowseContractorsScreen> createState() =>
      _BrowseContractorsScreenState();
}

class _BrowseContractorsScreenState extends State<BrowseContractorsScreen> {
  String _selectedService = 'All Services';
  double _minRating = 0;
  String _sortBy = 'rating'; // rating, reviews, distance
  bool _verifiedOnly = false;
  bool _filtersExpanded = false;
  bool _mapView = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String? _currentZip;
  bool _distanceEnabled = false;
  double _distanceMiles = 25;
  bool _loadingLocation = false;

  final List<String> _serviceTypes = const [
    'All Services',
    'Painting',
    ...kContractorServiceCatalog,
  ];

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

  bool _serviceMatchesFilter(List<String> services, String selected) {
    if (selected == 'All Services') return true;
    return services.any((service) => serviceMatches(service, selected));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    // Simplified query to avoid missing compound indexes
    // Filtering and sorting will be done in memory
    return FirebaseFirestore.instance.collection('contractors');
  }

  bool _isVerified(Map<String, dynamic> data) {
    return data['verified'] == true;
  }

  double? _distanceForContractor(Map<String, dynamic> data) {
    if (!_distanceEnabled) return null;
    final zip = _currentZip;
    if (zip == null || zip.isEmpty) return null;

    final contractorZip =
        extractZip(data) ?? extractZipFromString(data['location']?.toString());
    if (contractorZip == null || contractorZip.isEmpty) return null;

    return distanceMilesBetweenZips(zip, contractorZip);
  }

  String _debugEmptyReason({
    required int total,
    required int verified,
    required int hasServices,
  }) {
    if (total == 0) {
      return 'No contractor profiles exist in Firestore yet.';
    }
    if (_verifiedOnly && verified == 0) {
      return 'No contractors are marked verified yet. Turn off “Verified only”.';
    }
    if (_selectedService != 'All Services' && hasServices == 0) {
      return 'No contractor profiles have a services list set.';
    }
    return 'Your current filters/search returned no matches.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: ProServeColors.bg,
      appBar: widget.showBackButton
          ? AppBar(
              automaticallyImplyLeading: true,
              title: const Text('Browse Pros'),
              backgroundColor: ProServeColors.bgDeep,
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                  tooltip: _mapView ? 'List view' : 'Map view',
                  icon: Icon(_mapView ? Icons.view_list : Icons.map_outlined),
                  onPressed: () => setState(() => _mapView = !_mapView),
                ),
                IconButton(
                  tooltip: 'Saved contractors',
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => context.push('/favorites'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          _buildBrowseHeader(context),
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: ProServeColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ProServeColors.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() => _filtersExpanded = !_filtersExpanded);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ProServeColors.accent.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune,
                              color: ProServeColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filters',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _filtersExpanded ? 'Hide' : 'Show',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: ProServeColors.accent),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _filtersExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 420;

                                  final serviceDropdown =
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: _selectedService,
                                        decoration: const InputDecoration(
                                          labelText: 'Service Type',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: _serviceTypes
                                            .map(
                                              (service) => DropdownMenuItem(
                                                value: service,
                                                child: Text(service),
                                              ),
                                            )
                                            .toList(),
                                        selectedItemBuilder: (context) {
                                          return _serviceTypes
                                              .map(
                                                (service) => Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    service,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList();
                                        },
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(
                                            () => _selectedService = value,
                                          );
                                        },
                                      );

                                  final sortDropdown =
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: _sortBy,
                                        decoration: const InputDecoration(
                                          labelText: 'Sort By',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'rating',
                                            child: Text('Highest Rated'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'reviews',
                                            child: Text('Most Reviews'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'distance',
                                            child: Text('Closest'),
                                          ),
                                        ],
                                        selectedItemBuilder: (context) {
                                          const labels = {
                                            'rating': 'Highest Rated',
                                            'reviews': 'Most Reviews',
                                            'distance': 'Closest',
                                          };
                                          return const [
                                                'rating',
                                                'reviews',
                                                'distance',
                                              ]
                                              .map(
                                                (v) => Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    labels[v] ?? v,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList();
                                        },
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() => _sortBy = value);
                                        },
                                      );

                                  if (narrow) {
                                    return Column(
                                      children: [
                                        serviceDropdown,
                                        const SizedBox(height: 12),
                                        sortDropdown,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: serviceDropdown),
                                      const SizedBox(width: 16),
                                      Expanded(child: sortDropdown),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilterChip(
                                      label: const Text('Verified only'),
                                      selected: _verifiedOnly,
                                      onSelected: (v) {
                                        setState(() => _verifiedOnly = v);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: ProServeColors.bgDeep.withValues(
                                    alpha: 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: ProServeColors.line,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.near_me_outlined,
                                            color: ProServeColors.accent2,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Nearby contractors',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Switch(
                                            value:
                                                _distanceEnabled &&
                                                _currentZip != null &&
                                                _currentZip!.isNotEmpty,
                                            onChanged: (value) {
                                              if (_currentZip == null ||
                                                  _currentZip!.isEmpty) {
                                                _useMyLocation();
                                                return;
                                              }
                                              setState(
                                                () => _distanceEnabled = value,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        (_currentZip == null ||
                                                _currentZip!.isEmpty)
                                            ? 'Set your ZIP to filter by distance.'
                                            : 'Using ZIP $_currentZip',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Slider(
                                              value: _distanceMiles,
                                              min: 5,
                                              max: 100,
                                              divisions: 19,
                                              label:
                                                  '${_distanceMiles.toStringAsFixed(0)} mi',
                                              onChanged:
                                                  (_distanceEnabled &&
                                                      _currentZip != null &&
                                                      _currentZip!.isNotEmpty)
                                                  ? (value) {
                                                      setState(
                                                        () => _distanceMiles =
                                                            value,
                                                      );
                                                    }
                                                  : null,
                                            ),
                                          ),
                                          Text(
                                            '${_distanceMiles.toStringAsFixed(0)} mi',
                                          ),
                                        ],
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: _loadingLocation
                                              ? null
                                              : _useMyLocation,
                                          icon: _loadingLocation
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.my_location),
                                          label: const Text('Use my location'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Slider(
                                      value: _minRating,
                                      min: 0,
                                      max: 5,
                                      divisions: 10,
                                      label: _minRating == 0
                                          ? 'Any Rating'
                                          : '${_minRating.toStringAsFixed(1)}+',
                                      onChanged: (value) {
                                        setState(() {
                                          _minRating = value;
                                        });
                                      },
                                    ),
                                  ),
                                  Text(
                                    _minRating == 0
                                        ? 'Any'
                                        : '${_minRating.toStringAsFixed(1)}+',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _filtersExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outline.withValues(alpha: 0.12)),

          // Results
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading contractors: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;
                final totalCount = allDocs.length;
                final verifiedCount = allDocs
                    .where(
                      (d) => _isVerified((d.data() as Map<String, dynamic>)),
                    )
                    .length;
                final hasServicesCount = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return contractorServicesFromData(data).isNotEmpty;
                }).length;

                var contractors = allDocs;

                // Client-side filtering for verified, service, rating, and search
                contractors = contractors.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Optional filter by verified status
                  if (_verifiedOnly && !_isVerified(data)) return false;

                  // Filter by service type
                  if (_selectedService != 'All Services') {
                    final servicesList = contractorServicesFromData(data);
                    if (servicesList.isEmpty) return false;
                    if (!_serviceMatchesFilter(
                      servicesList,
                      _selectedService,
                    )) {
                      return false;
                    }
                  }

                  final rating =
                      (data['averageRating'] as num?)?.toDouble() ?? 0;
                  final businessName =
                      (data['businessName'] as String?)?.toLowerCase() ?? '';
                  final name = (data['name'] as String?)?.toLowerCase() ?? '';
                  final location =
                      (data['location'] as String?)?.toLowerCase() ?? '';
                  final zip = (data['zip'] as String?)?.toLowerCase() ?? '';

                  final matchesRating = rating >= _minRating;
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      businessName.contains(_searchQuery) ||
                      name.contains(_searchQuery) ||
                      location.contains(_searchQuery) ||
                      zip.contains(_searchQuery);

                  if (_distanceEnabled) {
                    final distance = _distanceForContractor(data);
                    if (distance == null || distance > _distanceMiles) {
                      return false;
                    }
                  }

                  return matchesRating && matchesSearch;
                }).toList();

                // Client-side sorting — boosted/featured contractors always first
                contractors.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  // Featured / boosted contractors float to top
                  final featA = dataA['featured'] == true ? 0 : 1;
                  final featB = dataB['featured'] == true ? 0 : 1;
                  if (featA != featB) return featA.compareTo(featB);

                  if (_sortBy == 'rating') {
                    final ratingA =
                        (dataA['averageRating'] as num?)?.toDouble() ?? 0;
                    final ratingB =
                        (dataB['averageRating'] as num?)?.toDouble() ?? 0;
                    return ratingB.compareTo(ratingA); // descending
                  } else if (_sortBy == 'reviews') {
                    final reviewsA =
                        (dataA['totalReviews'] as num?)?.toInt() ??
                        (dataA['reviewCount'] as num?)?.toInt() ??
                        0;
                    final reviewsB =
                        (dataB['totalReviews'] as num?)?.toInt() ??
                        (dataB['reviewCount'] as num?)?.toInt() ??
                        0;
                    return reviewsB.compareTo(reviewsA); // descending
                  } else if (_sortBy == 'distance') {
                    final dA = _distanceForContractor(dataA) ?? double.infinity;
                    final dB = _distanceForContractor(dataB) ?? double.infinity;
                    return dA.compareTo(dB);
                  }
                  return 0;
                });

                if (contractors.isEmpty) {
                  final reason = _debugEmptyReason(
                    total: totalCount,
                    verified: verifiedCount,
                    hasServices: hasServicesCount,
                  );
                  return _BrowseEmptyState(
                    reason: reason,
                    onClear: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedService = 'All Services';
                        _minRating = 0;
                        _verifiedOnly = false;
                        _distanceEnabled = false;
                      });
                    },
                    onStartProject: () => context.push('/smart-request'),
                  );
                }

                final resultHeader = Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _mapView
                              ? 'Pros by distance'
                              : '${contractors.length} trusted pros',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ProServeColors.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: ProServeColors.accent.withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                        child: Text(
                          _verifiedOnly ? 'Verified only' : 'All pros',
                          style: const TextStyle(
                            color: ProServeColors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                return _mapView
                    ? _buildMapView(context, contractors, header: resultHeader)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: contractors.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) return resultHeader;
                          final contractor =
                              contractors[index - 1].data()
                                  as Map<String, dynamic>;
                          final contractorId = contractors[index - 1].id;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _ContractorCard(
                              contractorId: contractorId,
                              contractor: contractor,
                              distanceMiles: _distanceForContractor(contractor),
                              selectedService: _selectedService,
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ProServeColors.bgDeep, ProServeColors.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BROWSE PROS',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find verified local contractors, compare proof, and save your shortlist.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ProServeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: _mapView ? 'List view' : 'Map view',
                onPressed: () => setState(() => _mapView = !_mapView),
                icon: Icon(_mapView ? Icons.view_list : Icons.map_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Saved contractors',
                onPressed: () => context.push('/favorites'),
                icon: const Icon(Icons.favorite_border),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: ProServeColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ProServeColors.line),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, city, ZIP, or trade',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TrustChip(icon: Icons.verified_user_outlined, label: 'Verified'),
              _TrustChip(icon: Icons.star_outline, label: 'Reviewed'),
              _TrustChip(icon: Icons.lock_outline, label: 'Escrow-safe'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(
    BuildContext context,
    List<QueryDocumentSnapshot> contractors, {
    Widget? header,
  }) {
    // Sort by distance for map view.
    final sorted = List<QueryDocumentSnapshot>.from(contractors)
      ..sort((a, b) {
        final dA =
            _distanceForContractor(a.data() as Map<String, dynamic>) ??
            double.infinity;
        final dB =
            _distanceForContractor(b.data() as Map<String, dynamic>) ??
            double.infinity;
        return dA.compareTo(dB);
      });

    // Group into distance bands.
    final nearby = <QueryDocumentSnapshot>[];
    final midRange = <QueryDocumentSnapshot>[];
    final farAway = <QueryDocumentSnapshot>[];

    for (final doc in sorted) {
      final data = doc.data() as Map<String, dynamic>;
      final d = _distanceForContractor(data);
      if (d == null) {
        farAway.add(doc);
      } else if (d <= 10) {
        nearby.add(doc);
      } else if (d <= 25) {
        midRange.add(doc);
      } else {
        farAway.add(doc);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (header != null) header,
        // Your location
        if (_currentZip != null && _currentZip!.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ProServeColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ProServeColors.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: ProServeColors.accent),
                  const SizedBox(width: 12),
                  Text(
                    'Your location: ZIP $_currentZip',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        if (_currentZip == null || _currentZip!.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ProServeColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ProServeColors.warning.withValues(alpha: 0.24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: ProServeColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set your ZIP code in filters to see distance-based results.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (nearby.isNotEmpty) ...[
          _distanceBandHeader(
            context,
            Icons.near_me,
            'Nearby (< 10 mi)',
            '${nearby.length} pros',
            Colors.green,
          ),
          const SizedBox(height: 8),
          ...nearby.map((doc) => _mapCard(context, doc)),
          const SizedBox(height: 16),
        ],
        if (midRange.isNotEmpty) ...[
          _distanceBandHeader(
            context,
            Icons.directions_car,
            '10–25 miles',
            '${midRange.length} pros',
            Colors.orange,
          ),
          const SizedBox(height: 8),
          ...midRange.map((doc) => _mapCard(context, doc)),
          const SizedBox(height: 16),
        ],
        if (farAway.isNotEmpty) ...[
          _distanceBandHeader(
            context,
            Icons.explore,
            '25+ miles',
            '${farAway.length} pros',
            Colors.grey,
          ),
          const SizedBox(height: 8),
          ...farAway.map((doc) => _mapCard(context, doc)),
        ],
      ],
    );
  }

  Widget _distanceBandHeader(
    BuildContext context,
    IconData icon,
    String title,
    String count,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Text(
          count,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _mapCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name =
        (data['businessName'] as String?)?.trim() ??
        (data['companyName'] as String?)?.trim() ??
        (data['name'] as String?)?.trim() ??
        'Unknown';
    final rating = (data['averageRating'] as num?)?.toDouble() ?? 0;
    final dist = _distanceForContractor(data);
    final profileImage = data['profileImage'] as String?;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: scheme.primaryContainer,
          backgroundImage: profileImage != null
              ? CachedNetworkImageProvider(profileImage)
              : null,
          child: profileImage == null
              ? Text(name.isNotEmpty ? name[0] : '?')
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.star, size: 14, color: Colors.amber[700]),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1)),
            if (dist != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.route, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 2),
              Text(formatDistance(dist)),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/contractor/${doc.id}'),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ProServeColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: ProServeColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseEmptyState extends StatelessWidget {
  const _BrowseEmptyState({
    required this.reason,
    required this.onClear,
    required this.onStartProject,
  });

  final String reason;
  final VoidCallback onClear;
  final VoidCallback onStartProject;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ProServeColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ProServeColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: ProServeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.manage_search,
                  size: 34,
                  color: ProServeColors.accent,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No pros match this search',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: ProServeColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear filters'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onStartProject,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Start project'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractorCard extends StatefulWidget {
  final String contractorId;
  final Map<String, dynamic> contractor;
  final double? distanceMiles;
  final String selectedService;

  const _ContractorCard({
    required this.contractorId,
    required this.contractor,
    this.distanceMiles,
    required this.selectedService,
  });

  @override
  State<_ContractorCard> createState() => _ContractorCardState();
}

class _ContractorCardState extends State<_ContractorCard> {
  bool _isFav = false;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _checkFav();
  }

  Future<void> _checkFav() async {
    final fav = await FavoritesService.instance.isFavorite(widget.contractorId);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    if (_toggling) return;
    _toggling = true;
    final result = await FavoritesService.instance.toggle(widget.contractorId);
    if (mounted) setState(() => _isFav = result);
    _toggling = false;
  }

  @override
  Widget build(BuildContext context) {
    final contractor = widget.contractor;
    final contractorId = widget.contractorId;
    final distanceMiles = widget.distanceMiles;
    final businessNameRaw = (contractor['businessName'] as String?)?.trim();
    final nameRaw = (contractor['name'] as String?)?.trim();
    final companyNameRaw = (contractor['companyName'] as String?)?.trim();
    final displayName = (businessNameRaw != null && businessNameRaw.isNotEmpty)
        ? businessNameRaw
        : (companyNameRaw != null && companyNameRaw.isNotEmpty)
        ? companyNameRaw
        : (nameRaw != null && nameRaw.isNotEmpty)
        ? nameRaw
        : 'Unknown';
    final location = contractor['location'] as String? ?? '';
    final averageRating =
        (contractor['averageRating'] as num?)?.toDouble() ?? 0;
    final totalReviews =
        (contractor['totalReviews'] as num?)?.toInt() ??
        (contractor['reviewCount'] as num?)?.toInt() ??
        0;
    final services = contractorServicesFromData(contractor);
    final profileImage = contractor['profileImage'] as String?;
    final featured = contractor['featured'] == true;
    final selectedService = widget.selectedService;
    final serviceFiltered = selectedService != 'All Services';
    String? matchedService;
    if (serviceFiltered) {
      for (final service in services) {
        if (serviceMatches(service, selectedService)) {
          matchedService = service;
          break;
        }
      }
    }
    final guidance = guidanceForService(matchedService ?? selectedService);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: ProServeColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProServeColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            context.push('/contractor/$contractorId');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                CircleAvatar(
                  radius: 40,
                  backgroundColor: ProServeColors.accent.withValues(
                    alpha: 0.16,
                  ),
                  backgroundImage: profileImage != null
                      ? CachedNetworkImageProvider(profileImage)
                      : null,
                  child: profileImage == null
                      ? Text(
                          displayName.isNotEmpty ? displayName[0] : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            color: ProServeColors.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (featured) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ProServeColors.accent.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ProServeColors.accent.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'FEATURED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: ProServeColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: ProServeColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ProServeColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (distanceMiles != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.route_outlined,
                              size: 16,
                              color: ProServeColors.accent2,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${formatDistance(distanceMiles)} away',
                              style: TextStyle(
                                fontSize: 14,
                                color: ProServeColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, size: 18, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            averageRating > 0
                                ? averageRating.toStringAsFixed(1)
                                : 'New',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            totalReviews > 0
                                ? '($totalReviews reviews)'
                                : 'No reviews yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: ProServeColors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: services.take(3).map((service) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ProServeColors.bgDeep.withValues(
                                  alpha: 0.72,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: ProServeColors.line),
                              ),
                              child: Text(
                                service,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: ProServeColors.ink,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (serviceFiltered) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MatchSignalChip(
                              icon: Icons.handyman_outlined,
                              label: matchedService != null
                                  ? 'Offers $matchedService'
                                  : 'Related service',
                            ),
                            if (distanceMiles != null)
                              _MatchSignalChip(
                                icon: Icons.near_me_outlined,
                                label: '${formatDistance(distanceMiles)} away',
                              ),
                            ...guidance.matchSignals
                                .where(
                                  (signal) => signal != 'Offers this service',
                                )
                                .take(1)
                                .map(
                                  (signal) => _MatchSignalChip(
                                    icon: Icons.verified_outlined,
                                    label: signal,
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Favorite + Arrow
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: _isFav
                          ? 'Remove from favorites'
                          : 'Save contractor',
                      icon: Icon(
                        _isFav ? Icons.favorite : Icons.favorite_border,
                        color: _isFav
                            ? ProServeColors.error
                            : ProServeColors.muted,
                      ),
                      onPressed: _toggleFav,
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: ProServeColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchSignalChip extends StatelessWidget {
  const _MatchSignalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ProServeColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ProServeColors.accent.withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ProServeColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ProServeColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
