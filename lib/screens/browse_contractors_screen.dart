import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recommended_contractors_page.dart';
import '../widgets/contractor_reputation_card.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String? _currentZip;
  bool _distanceEnabled = false;
  double _distanceMiles = 25;
  bool _loadingLocation = false;

  final List<String> _serviceTypes = [
    'All Services',
    'Interior Painting',
    'Exterior Painting',
    'Painting',
    'Drywall Repair',
    'Pressure Washing',
    'Cabinets',
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

  bool _serviceMatchesFilter(List<String> servicesLower, String selected) {
    if (selected == 'All Services') return true;
    final sel = selected.trim().toLowerCase();
    if (sel == 'interior painting') {
      return servicesLower.any(
        (s) => s.contains('interior') && s.contains('paint'),
      );
    }
    if (sel == 'exterior painting') {
      return servicesLower.any(
        (s) => s.contains('exterior') && s.contains('paint'),
      );
    }
    if (sel.contains('paint')) {
      return servicesLower.any((s) => s.contains('paint'));
    }
    if (sel.contains('drywall')) {
      return servicesLower.any((s) => s.contains('drywall'));
    }
    if (sel.contains('pressure')) {
      return servicesLower.any(
        (s) =>
            s.contains('pressure') ||
            (s.contains('wash') && !s.contains('dish')),
      );
    }
    return servicesLower.contains(sel);
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text('Browse Contractors'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _filtersExpanded = !_filtersExpanded);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune),
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
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
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
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.near_me_outlined),
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
                                  const Icon(Icons.star),
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
          const Divider(height: 1),

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
                  final services = data['services'];
                  return services is List && services.isNotEmpty;
                }).length;

                var contractors = allDocs;

                // Client-side filtering for verified, service, rating, and search
                contractors = contractors.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Optional filter by verified status
                  if (_verifiedOnly && !_isVerified(data)) return false;

                  // Filter by service type
                  if (_selectedService != 'All Services') {
                    final services = data['services'];
                    if (services is! List) return false;
                    final servicesList = services
                        .cast<String>()
                        .map((s) => s.toLowerCase())
                        .toList();
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No contractors found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contractors.length,
                  itemBuilder: (context, index) {
                    final contractor =
                        contractors[index].data() as Map<String, dynamic>;
                    final contractorId = contractors[index].id;

                    return _ContractorCard(
                      contractorId: contractorId,
                      contractor: contractor,
                      distanceMiles: _distanceForContractor(contractor),
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
}

class _ContractorCard extends StatelessWidget {
  final String contractorId;
  final Map<String, dynamic> contractor;
  final double? distanceMiles;

  const _ContractorCard({
    required this.contractorId,
    required this.contractor,
    this.distanceMiles,
  });

  @override
  Widget build(BuildContext context) {
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
    final services =
        (contractor['services'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        [];
    final profileImage = contractor['profileImage'] as String?;
    final featured = contractor['featured'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContractorProfilePage(contractorId: contractorId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: profileImage != null
                    ? NetworkImage(profileImage)
                    : null,
                child: profileImage == null
                    ? Text(
                        displayName.isNotEmpty ? displayName[0] : '?',
                        style: const TextStyle(fontSize: 32),
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
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (featured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'FEATURED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (contractor['reputation'] is Map<String, dynamic>) ...[
                      const SizedBox(height: 4),
                      ContractorReputationCard(
                        reputationData:
                            contractor['reputation'] as Map<String, dynamic>,
                        compact: true,
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${formatDistance(distanceMiles!)} away',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                          averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($totalReviews reviews)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                          return Chip(
                            label: Text(
                              service,
                              style: const TextStyle(fontSize: 12),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
