import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// System Health Admin Tab — Live platform overview & diagnostics
/// ---------------------------------------------------------------------------
class SystemHealthTab extends StatefulWidget {
  const SystemHealthTab({super.key});

  @override
  State<SystemHealthTab> createState() => _SystemHealthTabState();
}

class _SystemHealthTabState extends State<SystemHealthTab> {
  bool _loading = true;
  final List<StreamSubscription> _subs = [];

  // Live counters
  int _totalUsers = 0;
  int _totalContractors = 0;
  int _totalCustomers = 0;
  int _activeJobs = 0;
  int _completedJobs = 0;
  int _openDisputes = 0;
  int _pendingVerifications = 0;
  int _activeEscrows = 0;
  int _pushEnabledUsers = 0;
  int _proSubscribers = 0;
  int _enterpriseSubscribers = 0;

  // Recent signups (last 24h)
  int _newUsersToday = 0;
  int _newContractorsToday = 0;
  int _newJobsToday = 0;

  // Service type distribution
  Map<String, int> _serviceTypes = {};

  // Top ZIPs
  Map<String, int> _topZips = {};

  @override
  void initState() {
    super.initState();
    _listenAll();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _listenAll() {
    final now = DateTime.now();
    final todayCutoff = DateTime(now.year, now.month, now.day);

    // Users (all)
    _subs.add(FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snap) {
      int total = 0, cust = 0, cont = 0, push = 0, pro = 0, ent = 0;
      int newToday = 0, newContToday = 0;
      final zipMap = <String, int>{};

      for (final d in snap.docs) {
        final data = d.data();
        if (data['isDeleted'] == true) continue;
        total++;
        final role = data['role'] ?? '';
        if (role == 'customer') cust++;
        if (role == 'contractor') {
          cont++;
          final tier = _effectiveTier(data);
          if (tier == 'pro') pro++;
          if (tier == 'enterprise') ent++;
        }
        if ((data['fcmToken'] ?? '').toString().isNotEmpty) push++;

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp &&
            createdAt.toDate().isAfter(todayCutoff)) {
          newToday++;
          if (role == 'contractor') newContToday++;
        }

        final zip = (data['zip'] ?? '').toString().trim();
        if (zip.isNotEmpty) {
          zipMap[zip] = (zipMap[zip] ?? 0) + 1;
        }
      }

      // Sort zips by count, take top 10
      final sortedZips = zipMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topZips = Map.fromEntries(sortedZips.take(10));

      setState(() {
        _totalUsers = total;
        _totalCustomers = cust;
        _totalContractors = cont;
        _pushEnabledUsers = push;
        _proSubscribers = pro;
        _enterpriseSubscribers = ent;
        _newUsersToday = newToday;
        _newContractorsToday = newContToday;
        _topZips = topZips;
        _loading = false;
      });
    }));

    // Jobs
    _subs.add(FirebaseFirestore.instance
        .collection('job_requests')
        .snapshots()
        .listen((snap) {
      int active = 0, completed = 0, newToday = 0;
      final serviceMap = <String, int>{};

      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'open' || status == 'in_progress' || status == 'claimed') {
          active++;
        }
        if (status == 'completed') completed++;

        final service = (data['serviceType'] ?? 'Other').toString();
        serviceMap[service] = (serviceMap[service] ?? 0) + 1;

        final createdAt = data['createdAt'];
        if (createdAt is Timestamp &&
            createdAt.toDate().isAfter(todayCutoff)) {
          newToday++;
        }
      }

      setState(() {
        _activeJobs = active;
        _completedJobs = completed;
        _newJobsToday = newToday;
        _serviceTypes = serviceMap;
      });
    }));

    // Disputes
    _subs.add(FirebaseFirestore.instance
        .collection('disputes')
        .where('status', whereIn: ['open', 'under_review'])
        .snapshots()
        .listen((snap) {
      setState(() => _openDisputes = snap.docs.length);
    }));

    // Verifications
    _subs.add(FirebaseFirestore.instance
        .collection('contractors')
        .snapshots()
        .listen((snap) {
      int pending = 0;
      for (final d in snap.docs) {
        final data = d.data();
        for (final type in ['idVerification', 'licenseVerification', 'insuranceVerification']) {
          final v = data[type];
          if (v is Map && v['status'] == 'pending') pending++;
        }
      }
      setState(() => _pendingVerifications = pending);
    }));

    // Active Escrows
    _subs.add(FirebaseFirestore.instance
        .collection('escrow_bookings')
        .where('status', whereIn: ['funded', 'confirmed', 'offered'])
        .snapshots()
        .listen((snap) {
      setState(() => _activeEscrows = snap.docs.length);
    }));
  }

  String _effectiveTier(Map<String, dynamic> data) {
    final tier = (data['subscriptionTier'] as String?)?.toLowerCase();
    if (tier == 'enterprise') return 'enterprise';
    if (tier == 'pro') return 'pro';
    if (data['pricingToolsPro'] == true ||
        data['contractorPro'] == true ||
        data['isPro'] == true) {
      return 'pro';
    }
    return 'basic';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
            SizedBox(height: 12),
            ListTileSkeleton(),
          ],
        ),
      );
    }

    final mrr = (_proSubscribers * 11.99) + (_enterpriseSubscribers * 49.99);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ───────────────────────────────────────────────
        Row(
          children: [
            Text('System Health',
                style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Last updated: ${DateFormat.jm().format(DateTime.now())}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white38),
        ),
        const SizedBox(height: 20),

        // ── Today's Activity ─────────────────────────────────────
        Card(
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Activity",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.blue)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _todayStat('New Users', _newUsersToday, Icons.person_add),
                    _todayStat('New Contractors', _newContractorsToday,
                        Icons.engineering),
                    _todayStat(
                        'New Jobs', _newJobsToday, Icons.work),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Platform Stats Grid ──────────────────────────────────
        Text('Platform Stats',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _kpiCard('Total Users', '$_totalUsers', Icons.people, Colors.blue),
            _kpiCard('Customers', '$_totalCustomers', Icons.person,
                Colors.teal),
            _kpiCard('Contractors', '$_totalContractors', Icons.build,
                Colors.orange),
            _kpiCard('PRO Subs', '$_proSubscribers', Icons.star, Colors.amber),
            _kpiCard(
                'Enterprise', '$_enterpriseSubscribers', Icons.diamond, Colors.purpleAccent),
            _kpiCard('Sub MRR', '\$${mrr.toStringAsFixed(2)}',
                Icons.attach_money, Colors.green),
            _kpiCard(
                'Push Enabled', '$_pushEnabledUsers', Icons.notifications_active, Colors.cyan),
          ],
        ),
        const SizedBox(height: 24),

        // ── Alerts ───────────────────────────────────────────────
        Text('Action Required',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _alertCard('Active Jobs', '$_activeJobs', Icons.work,
                Colors.blue, _activeJobs > 0),
            _alertCard('Completed Jobs', '$_completedJobs',
                Icons.check_circle, Colors.green, false),
            _alertCard('Open Disputes', '$_openDisputes',
                Icons.gavel, Colors.red, _openDisputes > 0),
            _alertCard('Pending Verifications', '$_pendingVerifications',
                Icons.verified_user, Colors.orange, _pendingVerifications > 0),
            _alertCard('Active Escrows', '$_activeEscrows',
                Icons.account_balance, Colors.purple, _activeEscrows > 0),
          ],
        ),
        const SizedBox(height: 24),

        // ── Service Type Distribution ────────────────────────────
        if (_serviceTypes.isNotEmpty) ...[
          Text('Service Type Distribution',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _serviceTypes.entries.map((e) {
                  final total = _serviceTypes.values
                      .fold<int>(0, (acc, v) => acc + v);
                  final pct = total > 0 ? (e.value / total) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white10,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${e.value}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                            ' (${(pct * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Top ZIP Codes ────────────────────────────────────────
        if (_topZips.isNotEmpty) ...[
          Text('Top ZIP Codes',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _topZips.entries.map((e) {
                  final maxCount = _topZips.values.first;
                  final pct = maxCount > 0 ? (e.value / maxCount) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white10,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${e.value} users',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _todayStat(String label, int value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 6),
        Text('$value',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertCard(
      String label, String value, IconData icon, Color color, bool urgent) {
    return SizedBox(
      width: 180,
      child: Card(
        color: urgent ? color.withValues(alpha: 0.15) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  if (urgent) ...[
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}
