import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Multi-Location Dashboard
///
/// Franchise owners see all crews/locations on one map with live job status,
/// revenue per location, crew utilization rates. Think ServiceTitan-lite.
/// ─────────────────────────────────────────────────────────────────────────────
class MultiLocationDashboardScreen extends StatefulWidget {
  const MultiLocationDashboardScreen({super.key});

  @override
  State<MultiLocationDashboardScreen> createState() =>
      _MultiLocationDashboardScreenState();
}

class _MultiLocationDashboardScreenState
    extends State<MultiLocationDashboardScreen> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _loading = true;

  // ── Locations ──
  List<Map<String, dynamic>> _locations = [];

  // ── Aggregate metrics ──
  double _totalRevenue = 0;
  int _totalJobs = 0;
  int _activeJobs = 0;
  double _avgUtilization = 0;

  // ── Date range filter ──
  String _range = 'This Month';
  final _ranges = ['Today', 'This Week', 'This Month', 'This Quarter', 'All'];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);

    try {
      // Load locations.
      final locSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('locations')
          .get();

      if (locSnap.docs.isEmpty) {
        // Seed a default location from user profile.
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .get();
        final userData = userDoc.data() ?? {};
        _locations = [
          {
            'id': 'primary',
            'name': userData['businessName'] ?? 'Primary Location',
            'address': userData['address'] ?? '',
            'city': userData['city'] ?? '',
            'state': userData['state'] ?? '',
            'zip': userData['zip'] ?? '',
            'revenue': 0.0,
            'jobCount': 0,
            'activeJobs': 0,
            'crewCount': 1,
            'utilization': 0.0,
          },
        ];
      } else {
        _locations = locSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      }

      // Load job metrics per location.
      await _loadMetrics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMetrics() async {
    final dateFilter = _getDateFilter();

    try {
      // Jobs for this contractor.
      Query<Map<String, dynamic>> jobQuery = FirebaseFirestore.instance
          .collection('job_requests')
          .where('contractorId', isEqualTo: _uid);

      if (dateFilter != null) {
        jobQuery = jobQuery.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFilter),
        );
      }

      final jobSnap = await jobQuery.limit(500).get();
      final jobs = jobSnap.docs.map((d) => d.data()).toList();

      _totalJobs = jobs.length;
      _activeJobs = jobs
          .where(
            (j) => j['status'] == 'in_progress' || j['status'] == 'accepted',
          )
          .length;

      // Revenue from completed jobs.
      _totalRevenue = 0;
      for (final j in jobs) {
        if (j['status'] == 'completed' || j['status'] == 'paid') {
          final amt = j['totalAmount'] ?? j['amount'] ?? j['price'] ?? 0;
          _totalRevenue += (amt is num) ? amt.toDouble() : 0;
        }
      }

      // Map revenue to locations based on ZIP.
      for (final loc in _locations) {
        final locZip = loc['zip']?.toString() ?? '';
        final locJobs = jobs
            .where(
              (j) =>
                  (j['jobZip']?.toString() ?? '') == locZip || locZip.isEmpty,
            )
            .toList();
        double locRevenue = 0;
        for (final j in locJobs) {
          if (j['status'] == 'completed' || j['status'] == 'paid') {
            final amt = j['totalAmount'] ?? j['amount'] ?? j['price'] ?? 0;
            locRevenue += (amt is num) ? amt.toDouble() : 0;
          }
        }
        loc['revenue'] = locRevenue;
        loc['jobCount'] = locJobs.length;
        loc['activeJobs'] = locJobs
            .where(
              (j) => j['status'] == 'in_progress' || j['status'] == 'accepted',
            )
            .length;
      }

      // Crew utilization.
      final crewSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('crews')
          .get();
      final totalCrews = crewSnap.docs.isEmpty ? 1 : crewSnap.docs.length;
      final busyCrews = crewSnap.docs
          .where((d) => d.data()['available'] == false)
          .length;
      _avgUtilization = totalCrews > 0 ? (busyCrews / totalCrews * 100) : 0;

      for (final loc in _locations) {
        loc['crewCount'] = totalCrews;
        loc['utilization'] = _avgUtilization;
      }
    } catch (_) {
      // Best-effort metrics.
    }
  }

  DateTime? _getDateFilter() {
    final now = DateTime.now();
    switch (_range) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return now.subtract(Duration(days: now.weekday));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Quarter':
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterMonth, 1);
      default:
        return null;
    }
  }

  // ── Add Location ──────────────────────────────────────────────────────────

  Future<void> _showAddLocationDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final zipCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Location Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: stateCtrl,
                      decoration: const InputDecoration(labelText: 'ST'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: zipCtrl,
                decoration: const InputDecoration(labelText: 'ZIP Code'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': nameCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'city': cityCtrl.text.trim(),
                'state': stateCtrl.text.trim(),
                'zip': zipCtrl.text.trim(),
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('locations')
          .add({...result, 'createdAt': FieldValue.serverTimestamp()});
      await _loadDashboard();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Location Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Add Location',
            onPressed: _showAddLocationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date range selector
                  _buildRangeSelector(cs),
                  const SizedBox(height: 16),

                  // Aggregate KPI row
                  _buildKpiRow(cs),
                  const SizedBox(height: 20),

                  // Locations list
                  Text(
                    'Locations (${_locations.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._locations.map((loc) => _buildLocationCard(loc, cs)),

                  const SizedBox(height: 20),

                  // Job status breakdown
                  _buildJobStatusBreakdown(cs),
                ],
              ),
            ),
    );
  }

  // ── Range Selector ────────────────────────────────────────────────────────

  Widget _buildRangeSelector(ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _ranges.map((r) {
          final selected = r == _range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(r),
              selected: selected,
              onSelected: (v) {
                if (v) {
                  setState(() => _range = r);
                  _loadDashboard();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── KPI Row ───────────────────────────────────────────────────────────────

  Widget _buildKpiRow(ColorScheme cs) {
    final formatter = NumberFormat.compactCurrency(symbol: '\$');
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'Revenue',
            formatter.format(_totalRevenue),
            Icons.attach_money,
            Colors.green,
            cs,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Total Jobs',
            '$_totalJobs',
            Icons.work_outline,
            cs.primary,
            cs,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Active',
            '$_activeJobs',
            Icons.play_arrow,
            Colors.orange,
            cs,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            'Utilization',
            '${_avgUtilization.toStringAsFixed(0)}%',
            Icons.groups,
            Colors.blue,
            cs,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme cs,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Location Card ─────────────────────────────────────────────────────────

  Widget _buildLocationCard(Map<String, dynamic> loc, ColorScheme cs) {
    final revenue = (loc['revenue'] as num?)?.toDouble() ?? 0;
    final jobCount = (loc['jobCount'] as num?)?.toInt() ?? 0;
    final activeJobs = (loc['activeJobs'] as num?)?.toInt() ?? 0;
    final crewCount = (loc['crewCount'] as num?)?.toInt() ?? 0;
    final utilization = (loc['utilization'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.location_on, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc['name']?.toString() ?? 'Location',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (loc['city'] != null || loc['state'] != null)
                        Text(
                          [loc['city'], loc['state']]
                              .where(
                                (s) => s != null && s.toString().isNotEmpty,
                              )
                              .join(', '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeJobs > 0
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    activeJobs > 0 ? '$activeJobs active' : 'Idle',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: activeJobs > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _locationStat(
                  'Revenue',
                  NumberFormat.compactCurrency(symbol: '\$').format(revenue),
                  Icons.attach_money,
                  Colors.green,
                ),
                _locationStat(
                  'Jobs',
                  '$jobCount',
                  Icons.work_outline,
                  cs.primary,
                ),
                _locationStat('Crews', '$crewCount', Icons.groups, Colors.blue),
                _locationStat(
                  'Util.',
                  '${utilization.toStringAsFixed(0)}%',
                  Icons.speed,
                  Colors.orange,
                ),
              ],
            ),
            // Utilization bar
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: utilization / 100,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  utilization > 80
                      ? Colors.green
                      : utilization > 50
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ── Job Status Breakdown ──────────────────────────────────────────────────

  Widget _buildJobStatusBreakdown(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job Status Overview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _statusRow('Active', _activeJobs, Colors.green, cs),
            const SizedBox(height: 8),
            _statusRow(
              'Completed',
              _totalJobs - _activeJobs > 0 ? _totalJobs - _activeJobs : 0,
              Colors.blue,
              cs,
            ),
            const SizedBox(height: 8),
            _statusRow('Total', _totalJobs, cs.primary, cs),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, int count, Color color, ColorScheme cs) {
    final pct = _totalJobs > 0
        ? (count / _totalJobs * 100).toStringAsFixed(0)
        : '0';
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ),
      ],
    );
  }
}
