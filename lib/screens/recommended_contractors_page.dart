import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/contractor_reputation_card.dart';
import 'package:intl/intl.dart';

import '../widgets/skeleton_loader.dart';

import '../models/marketplace_models.dart';
import '../services/zip_lookup_service.dart';
import '../utils/zip_locations.dart';

class RecommendedContractorsPage extends StatefulWidget {
  final String jobId;

  const RecommendedContractorsPage({super.key, required this.jobId});

  @override
  State<RecommendedContractorsPage> createState() =>
      _RecommendedContractorsPageState();
}

class _RecommendedContractorsPageState
    extends State<RecommendedContractorsPage> {
  final Set<String> _invitingContractorIds = <String>{};

  String _sortBy = 'match'; // match, distance, rating, response

  bool _serviceMatches(String contractorService, String requestedService) {
    final s = contractorService.trim().toLowerCase();
    final req = requestedService.trim().toLowerCase();
    if (req.isEmpty) return true;

    if (req.contains('interior') && req.contains('paint')) {
      return s.contains('interior') && s.contains('paint');
    }
    if (req.contains('exterior') && req.contains('paint')) {
      return s.contains('exterior') && s.contains('paint');
    }
    if (req.contains('paint')) {
      return s.contains('paint');
    }
    if (req.contains('drywall')) {
      return s.contains('drywall');
    }
    if (req.contains('pressure')) {
      return s.contains('pressure') ||
          (s.contains('wash') && !s.contains('dish'));
    }
    if (req.contains('cabinet')) {
      return s.contains('cabinet');
    }

    return s == req;
  }

  bool _contractorSupportsService(
    Map<String, dynamic> contractor,
    String requestedService,
  ) {
    final raw = contractor['services'];
    if (raw is! List) return false;
    final services = raw.map((e) => e.toString()).toList();
    return services.any((s) => _serviceMatches(s, requestedService));
  }

  double? _zipLat(String zip) {
    final loc =
        ZipLookupService.instance.lookupCached(zip.trim()) ??
        zipLocations[zip.trim()];
    final lat = loc?['lat'];
    if (lat == null) return null;
    return (lat as num).toDouble();
  }

  double? _zipLng(String zip) {
    final loc =
        ZipLookupService.instance.lookupCached(zip.trim()) ??
        zipLocations[zip.trim()];
    final lng = loc?['lng'];
    if (lng == null) return null;
    return (lng as num).toDouble();
  }

  double _haversineMiles(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final km = earthRadiusKm * c;
    return km * 0.621371;
  }

  num _ratingScoreFromContractor(Map<String, dynamic> c) {
    final avg = c['averageRating'];
    final legacy = c['rating'];
    final r = avg is num
        ? avg.toDouble()
        : (legacy is num
              ? legacy.toDouble()
              : double.tryParse('${avg ?? legacy ?? ''}') ?? 0.0);
    return (r.clamp(0.0, 5.0) * 20).round();
  }

  num _responseScoreFromContractor(Map<String, dynamic> c) {
    final mins = c['avgResponseMinutes'];
    final m = mins is num ? mins.toDouble() : double.tryParse('$mins') ?? 60.0;
    // 0 min => 100, 120+ => ~0
    final score = (100.0 - (m.clamp(0.0, 120.0) / 120.0) * 100.0).round();
    return score.clamp(0, 100);
  }

  int _matchScoreForFallback({
    required Map<String, dynamic> contractor,
    required double distanceMiles,
    required String requestedService,
  }) {
    var score = 0;

    if (_contractorSupportsService(contractor, requestedService)) {
      score += 55;
    }
    if (contractor['verified'] == true) {
      score += 10;
    }
    if (contractor['stripePayoutsEnabled'] == true) {
      score += 5;
    }

    final ratingPts = (_ratingScoreFromContractor(contractor) / 5)
        .round(); // 0..20
    score += ratingPts;

    // Prefer closer: up to -25 points
    score -= (distanceMiles.clamp(0.0, 50.0) / 2.0).round();

    return score.clamp(0, 100);
  }

  Widget _fallbackMatches({
    required Map<String, dynamic> job,
    required bool canInvite,
    required Set<String> invited,
  }) {
    final zip = (job['zip'] as String?)?.trim() ?? '';
    final service = (job['service'] as String?)?.trim() ?? '';

    final jobLat = _zipLat(zip);
    final jobLng = _zipLng(zip);

    if (zip.isEmpty || jobLat == null || jobLng == null) {
      return const Center(
        child: Text('No contractors found (missing or unsupported ZIP).'),
      );
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('contractors')
          .limit(250)
          .get(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Error loading contractors: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final candidates = <Map<String, dynamic>>[];
        for (final d in snap.data!.docs) {
          final c = d.data();
          if (c['available'] == false) continue;
          if (service.isNotEmpty && !_contractorSupportsService(c, service)) {
            continue;
          }

          double? cLat = (c['lat'] is num)
              ? (c['lat'] as num).toDouble()
              : null;
          double? cLng = (c['lng'] is num)
              ? (c['lng'] as num).toDouble()
              : null;
          if (cLat == null || cLng == null) {
            final cZip = (c['zip'] as String?)?.trim() ?? '';
            cLat = _zipLat(cZip);
            cLng = _zipLng(cZip);
          }
          if (cLat == null || cLng == null) continue;

          final distance = _haversineMiles(jobLat, jobLng, cLat, cLng);
          final radiusRaw = c['radius'];
          final radius = radiusRaw is num
              ? radiusRaw.toDouble()
              : double.tryParse('$radiusRaw') ?? 30.0;
          if (distance > radius.clamp(1.0, 250.0)) continue;

          final ratingScore = _ratingScoreFromContractor(c);
          final responseScore = _responseScoreFromContractor(c);
          final matchScore = _matchScoreForFallback(
            contractor: c,
            distanceMiles: distance,
            requestedService: service,
          );

          candidates.add({
            'id': d.id,
            'matchScore': matchScore,
            'distanceMiles': distance,
            'ratingScore': ratingScore,
            'responseScore': responseScore,
          });
        }

        if (candidates.isEmpty) {
          return const Center(
            child: Text('No contractors found (fallback matching found none).'),
          );
        }

        candidates.sort((a, b) {
          num numVal(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
          switch (_sortBy) {
            case 'distance':
              return numVal(
                a['distanceMiles'],
              ).compareTo(numVal(b['distanceMiles']));
            case 'rating':
              return numVal(
                b['ratingScore'],
              ).compareTo(numVal(a['ratingScore']));
            case 'response':
              return numVal(
                b['responseScore'],
              ).compareTo(numVal(a['responseScore']));
            case 'match':
            default:
              return numVal(b['matchScore']).compareTo(numVal(a['matchScore']));
          }
        });

        final top = candidates.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Showing fallback matches (auto-matching not generated yet).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final c in top)
              _contractorCard(
                context,
                contractorId: (c['id'] as String),
                matchScore: (c['matchScore'] as int),
                distance: (c['distanceMiles'] as num?)?.toDouble() ?? 0,
                ratingScore: c['ratingScore'] as num,
                responseScore: c['responseScore'] as num,
                canInvite: canInvite,
                isInvited: invited.contains(c['id'] as String),
                isInviting: _invitingContractorIds.contains(c['id'] as String),
                onInvite: () => _inviteToBid(contractorId: c['id'] as String),
              ),
          ],
        );
      },
    );
  }

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

    if (mounted) {
      setState(() => _invitingContractorIds.add(safeContractorId));
    }

    try {
      final inviteId = '${widget.jobId}_$safeContractorId';
      final ref = FirebaseFirestore.instance
          .collection('bid_invites')
          .doc(inviteId);

      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 14)),
      );

      // Use set directly (deterministic ID prevents duplicates).
      // Avoids tx.get on a non-existent doc which fails read rules.
      await ref.set({
        'jobId': widget.jobId,
        'contractorId': safeContractorId,
        'customerId': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Top Recommended Pros')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Complete'),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .snapshots(),
        builder: (context, jobSnap) {
          final job = jobSnap.data?.data();
          final requesterUid = (job?['requesterUid'] as String?)?.trim() ?? '';
          final claimed = job?['claimed'] == true;
          final canInvite =
              currentUid != null && currentUid == requesterUid && !claimed;

          final invitesStream = (currentUid == null)
              ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
              : FirebaseFirestore.instance
                    .collection('bid_invites')
                    .where('jobId', isEqualTo: widget.jobId)
                    .where('customerId', isEqualTo: currentUid)
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

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('job_matches')
                        .doc(widget.jobId)
                        .collection('candidates')
                        // Keep a stable query to avoid index churn; sort in-memory.
                        .orderBy('matchScore', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error loading matches'),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs.toList();

                      if (docs.isEmpty) {
                        final jobData = job ?? const <String, dynamic>{};
                        return _fallbackMatches(
                          job: jobData,
                          canInvite: canInvite,
                          invited: invited,
                        );
                      }

                      docs.sort((a, b) {
                        final da = a.data();
                        final db = b.data();

                        num numVal(dynamic v) =>
                            v is num ? v : num.tryParse('$v') ?? 0;

                        final aMatch = numVal(da['matchScore']);
                        final bMatch = numVal(db['matchScore']);
                        final aDist = numVal(da['distanceMiles']);
                        final bDist = numVal(db['distanceMiles']);
                        final aRating = numVal(da['ratingScore']);
                        final bRating = numVal(db['ratingScore']);
                        final aResp = numVal(da['responseScore']);
                        final bResp = numVal(db['responseScore']);

                        switch (_sortBy) {
                          case 'distance':
                            return aDist.compareTo(bDist); // ascending
                          case 'rating':
                            return bRating.compareTo(aRating);
                          case 'response':
                            return bResp.compareTo(aResp);
                          case 'match':
                          default:
                            return bMatch.compareTo(aMatch);
                        }
                      });

                      final top = docs.take(3).toList();

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                const Text('Sort:'),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _sortBy,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'match',
                                        child: Text('Best Match'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'distance',
                                        child: Text('Closest'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'rating',
                                        child: Text('Highest Rated'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'response',
                                        child: Text('Fastest Response'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _sortBy = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final doc in top)
                            Builder(
                              builder: (context) {
                                final data = doc.data();

                                final matchScoreRaw = data['matchScore'];
                                final matchScore = matchScoreRaw is num
                                    ? matchScoreRaw.round()
                                    : int.tryParse(matchScoreRaw.toString()) ??
                                          0;

                                final distanceRaw = data['distanceMiles'];
                                final distance = distanceRaw is num
                                    ? distanceRaw.toDouble()
                                    : double.tryParse(distanceRaw.toString()) ??
                                          0.0;

                                final ratingScoreRaw = data['ratingScore'];
                                final ratingScore = ratingScoreRaw is num
                                    ? ratingScoreRaw
                                    : num.tryParse(ratingScoreRaw.toString()) ??
                                          0;

                                final responseScoreRaw = data['responseScore'];
                                final responseScore = responseScoreRaw is num
                                    ? responseScoreRaw
                                    : num.tryParse(
                                            responseScoreRaw.toString(),
                                          ) ??
                                          0;

                                final cid = doc.id;

                                return _contractorCard(
                                  context,
                                  contractorId: cid,
                                  matchScore: matchScore,
                                  distance: distance,
                                  ratingScore: ratingScore,
                                  responseScore: responseScore,
                                  canInvite: canInvite,
                                  isInvited: invited.contains(cid),
                                  isInviting: _invitingContractorIds.contains(
                                    cid,
                                  ),
                                  onInvite: () =>
                                      _inviteToBid(contractorId: cid),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _contractorCard(
    BuildContext context, {
    required String contractorId,
    required int matchScore,
    required double distance,
    required num ratingScore,
    required num responseScore,
    required bool canInvite,
    required bool isInvited,
    required bool isInviting,
    required VoidCallback onInvite,
  }) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .get(),
      builder: (context, snapshot) {
        final c = snapshot.data?.data();
        if (c == null) return const SizedBox.shrink();

        final scheme = Theme.of(context).colorScheme;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NAME + VERIFIED
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (c['name'] ?? 'Contractor').toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (c['verified'] == true)
                      Icon(Icons.verified, color: scheme.primary),
                    if (c['stripePayoutsEnabled'] == true) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_user, color: scheme.primary),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // Reputation compact view
                if (c['reputation'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ContractorReputationCard(
                      reputationData: c['reputation'],
                      compact: true,
                    ),
                  ),

                // MATCH SCORE BAR
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (matchScore.clamp(0, 100)) / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$matchScore%'),
                  ],
                ),

                const SizedBox(height: 10),

                // INFO ROW
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _infoChip(
                      Icons.star,
                      (ratingScore / 20).toStringAsFixed(1),
                    ),
                    _infoChip(
                      Icons.location_on,
                      '${distance.toStringAsFixed(1)} mi',
                    ),
                    _infoChip(
                      Icons.schedule,
                      responseScore >= 80
                          ? 'Fast'
                          : responseScore >= 60
                          ? 'Medium'
                          : 'Slow',
                    ),
                    _infoChip(Icons.work, '${c['completedJobs'] ?? 0} jobs'),
                  ],
                ),

                const SizedBox(height: 14),

                // ACTION
                if (canInvite) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (isInvited || isInviting) ? null : onInvite,
                      child: Text(
                        isInvited
                            ? 'Invited'
                            : (isInviting ? 'Inviting…' : 'Invite to Bid'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      context.push('/contractor/$contractorId');
                    },
                    child: const Text('View Profile'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}

class ContractorProfilePage extends StatelessWidget {
  final String contractorId;

  const ContractorProfilePage({super.key, required this.contractorId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contractor Profile')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('contractors')
            .doc(contractorId)
            .get(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading profile'));
          }
          if (!snap.hasData) {
            return const ProfileSkeleton();
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('Profile not found'));
          }

          final name = (data['name'] ?? 'Contractor').toString();
          final servicesRaw = data['services'];
          final services = servicesRaw is List
              ? servicesRaw.map((e) => e.toString()).toList()
              : <String>[];
          final verified = data['verified'] == true;
          final completedJobs = data['completedJobs'] ?? 0;
          final ratingRaw = data['rating'];
          final rating = ratingRaw is num
              ? ratingRaw.toDouble()
              : double.tryParse(ratingRaw.toString()) ?? 0.0;

          String? firstService;
          for (final service in services) {
            final s = service.trim().toLowerCase();
            if (s.contains('paint')) {
              // Prefer a specific painting service if a contractor lists it.
              if (s.contains('exterior')) {
                firstService = 'Exterior Painting';
              } else if (s.contains('interior')) {
                firstService = 'Interior Painting';
              } else {
                firstService = 'Interior Painting';
              }
              break;
            }
            if (s.contains('drywall')) {
              firstService = 'Drywall Repair';
              break;
            }
            if (s.contains('pressure') ||
                (s.contains('wash') && !s.contains('dish'))) {
              firstService = 'Pressure Washing';
              break;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (verified) const Icon(Icons.verified),
                  ],
                ),
                const SizedBox(height: 12),

                // Rating with Reviews Count
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('contractorId', isEqualTo: contractorId)
                      .snapshots(),
                  builder: (context, reviewsSnapshot) {
                    if (!reviewsSnapshot.hasData) {
                      return Text('Rating: ${rating.toStringAsFixed(1)}');
                    }

                    final reviews = reviewsSnapshot.data!.docs
                        .map((doc) => Review.fromFirestore(doc))
                        .toList();

                    if (reviews.isEmpty) {
                      return const Text('No reviews yet');
                    }

                    final avgRating =
                        reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                        reviews.length;

                    return Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < avgRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${avgRating.toStringAsFixed(1)} (${reviews.length} reviews)',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 8),
                Text('Completed jobs: $completedJobs'),
                if (services.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Services: ${services.join(', ')}'),
                ],

                const SizedBox(height: 24),

                // Reputation Engine
                ContractorReputationCard(
                  reputationData: data['reputation'] ?? {},
                ),

                const SizedBox(height: 24),

                // Recent Reviews Section
                const Text(
                  'Recent Reviews',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reviews')
                      .where('contractorId', isEqualTo: contractorId)
                      .orderBy('createdAt', descending: true)
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final reviews = snapshot.data!.docs
                        .map((doc) => Review.fromFirestore(doc))
                        .toList();

                    if (reviews.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No reviews yet',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final review in reviews)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          review.customerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(
                                          5,
                                          (index) => Icon(
                                            index < review.rating.round()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd().format(review.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    review.comment.length > 150
                                        ? '${review.comment.substring(0, 150)}...'
                                        : review.comment,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // View All Reviews Button
                        OutlinedButton(
                          onPressed: () {
                            context.push('/reviews/$contractorId');
                          },
                          child: const Text('View All Reviews'),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Portfolio Section
                _buildPortfolioSection(context, data),

                const SizedBox(height: 24),

                // Business Profile Section
                _buildBusinessProfileSection(context, data),

                const SizedBox(height: 24),

                // Q&A Section
                _buildQASection(context),

                const SizedBox(height: 24),

                // Instant Book button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/instant-book/$contractorId?name=$name');
                    },
                    icon: const Icon(Icons.bolt),
                    label: const Text('Instant Book'),
                  ),
                ),
                const SizedBox(height: 8),

                // Booking Calendar button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/calendar/$contractorId?name=$name');
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('View Availability'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: firstService == null
                        ? null
                        : () {
                            final s = firstService!.trim();
                            final lower = s.toLowerCase();
                            if (lower == 'painting') {
                              context.push('/flow/painting');
                              return;
                            }
                            if (lower == 'interior painting') {
                              context.push('/flow/painting?scope=interior');
                              return;
                            }
                            if (lower == 'exterior painting') {
                              context.push('/flow/exterior-painting');
                              return;
                            }
                            if (lower == 'cabinets') {
                              context.push('/flow/cabinets');
                              return;
                            }
                            if (lower == 'pressure washing') {
                              context.push('/flow/pressure-washing');
                              return;
                            }
                            if (lower == 'drywall repair') {
                              context.push('/flow/drywall-repair');
                              return;
                            }
                            context.push('/job-request/$firstService');
                          },
                    child: const Text('Request Job'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortfolioSection(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    // Portfolio is now stored as a subcollection.
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('contractors')
          .doc(contractorId)
          .collection('portfolio')
          .orderBy('uploadedAt', descending: true)
          .limit(5)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final portfolioList = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Portfolio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    context.push('/portfolio/$contractorId');
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: portfolioList.length,
                itemBuilder: (context, index) {
                  final item = portfolioList[index].data();
                  final url = item['url']?.toString() ?? '';
                  final title = item['title']?.toString() ?? '';

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: url.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    width: 150,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                  )
                                : Container(
                                    color: const Color(0xFF101E38),
                                    child: const Icon(Icons.image),
                                  ),
                          ),
                          if (title.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBusinessProfileSection(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final businessProfile = data['businessProfile'];
    if (businessProfile == null || businessProfile is! Map) {
      return const SizedBox.shrink();
    }

    final yearsInBusiness = businessProfile['yearsInBusiness']?.toString();
    final employeeCount = businessProfile['employeeCount']?.toString();
    final businessHours = businessProfile['businessHours']?.toString();
    final certifications = businessProfile['certifications'];
    final offerWarranty = businessProfile['offerWarranty'] == true;
    final warrantyDetails = businessProfile['warrantyDetails']?.toString();
    final awards = businessProfile['awards']?.toString();

    final certList = certifications is Map
        ? certifications.entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString())
              .toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (yearsInBusiness != null && yearsInBusiness.isNotEmpty)
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Years in Business',
                    yearsInBusiness,
                  ),
                if (employeeCount != null && employeeCount.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.people, 'Employees', employeeCount),
                ],
                if (businessHours != null && businessHours.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Hours', businessHours),
                ],
                if (certList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Certifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: certList
                        .map(
                          (cert) => Chip(
                            label: Text(
                              cert,
                              style: const TextStyle(fontSize: 12),
                            ),
                            avatar: const Icon(Icons.verified, size: 16),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (offerWarranty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.shield, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Warranty Offered',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (warrantyDetails != null &&
                                warrantyDetails.isNotEmpty)
                              Text(
                                warrantyDetails,
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (awards != null && awards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.emoji_events, 'Awards', awards),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildQASection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Questions & Answers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                context.push('/qanda/$contractorId');
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('qa')
              .where('contractorId', isEqualTo: contractorId)
              .orderBy('createdAt', descending: true)
              .limit(2)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final qaList = snapshot.data!.docs;

            if (qaList.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No questions yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: qaList.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final question = data['question']?.toString() ?? '';
                final answer = data['answer']?.toString() ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.question_answer,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                question,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (answer.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Text(
                              answer,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
