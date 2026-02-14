import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ai_usage_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Smart Scheduling AI
///
/// Feed in your pipeline of accepted jobs + crew availability + weather
/// forecast + drive times → AI optimizes the weekly schedule to minimize
/// windshield time and avoid rain days.
/// ─────────────────────────────────────────────────────────────────────────────
class SmartSchedulingScreen extends StatefulWidget {
  const SmartSchedulingScreen({super.key});

  @override
  State<SmartSchedulingScreen> createState() => _SmartSchedulingScreenState();
}

class _SmartSchedulingScreenState extends State<SmartSchedulingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Job pipeline ──
  List<Map<String, dynamic>> _jobs = [];
  bool _loadingJobs = true;

  // ── Crew ──
  List<Map<String, dynamic>> _crews = [];
  bool _loadingCrews = true;

  // ── AI schedule result ──
  bool _optimizing = false;
  List<Map<String, dynamic>> _schedule = [];
  String? _aiSummary;
  String? _error;

  // ── Week selector ──
  late DateTime _weekStart;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday % 7));
    _loadJobs();
    _loadCrews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadJobs() async {
    setState(() => _loadingJobs = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('contractorId', isEqualTo: _uid)
          .where('status', whereIn: ['accepted', 'in_progress', 'scheduled'])
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      _jobs = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      // Fallback: load from pipeline collection
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('job_pipeline')
            .orderBy('startDate')
            .limit(50)
            .get();
        _jobs = snap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingJobs = false);
  }

  Future<void> _loadCrews() async {
    setState(() => _loadingCrews = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('crews')
          .get();
      _crews = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}

    // If no crews collection, create a default crew
    if (_crews.isEmpty) {
      _crews = [
        {'id': 'default', 'name': 'Main Crew', 'size': 3, 'available': true},
      ];
    }
    if (mounted) setState(() => _loadingCrews = false);
  }

  // ── Add job to pipeline ───────────────────────────────────────────────────

  Future<void> _showAddJobDialog() async {
    final titleCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final zipCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '8');
    String priority = 'Medium';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Job to Pipeline'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Job Title *',
                    hintText: 'e.g. Interior Paint – 123 Oak St',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    hintText: '123 Oak St, City, State',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: zipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ZIP Code',
                    hintText: '30301',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Hours',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['High', 'Medium', 'Low']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => priority = v ?? 'Medium'),
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
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'title': titleCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'zip': zipCtrl.text.trim(),
                  'estimatedHours': double.tryParse(hoursCtrl.text.trim()) ?? 8,
                  'priority': priority,
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('job_pipeline')
          .add({
            ...result,
            'status': 'accepted',
            'createdAt': FieldValue.serverTimestamp(),
          });
      await _loadJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding job: $e')));
      }
    }
  }

  // ── Add crew ──────────────────────────────────────────────────────────────

  Future<void> _showAddCrewDialog() async {
    final nameCtrl = TextEditingController();
    final sizeCtrl = TextEditingController(text: '2');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Crew'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Crew Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sizeCtrl,
              decoration: const InputDecoration(labelText: 'Crew Size'),
              keyboardType: TextInputType.number,
            ),
          ],
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
                'size': int.tryParse(sizeCtrl.text.trim()) ?? 2,
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
          .collection('crews')
          .add({
            ...result,
            'available': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
      await _loadCrews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding crew: $e')));
      }
    }
  }

  // ── AI Optimize ───────────────────────────────────────────────────────────

  Future<void> _optimizeSchedule() async {
    if (_jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one job to optimize')),
      );
      return;
    }

    // Rate-limit check.
    final limitMsg = await AiUsageService.instance.checkLimit('scheduling');
    if (limitMsg != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(limitMsg)));
      }
      return;
    }

    setState(() {
      _optimizing = true;
      _error = null;
      _schedule = [];
      _aiSummary = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'optimizeSchedule',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final jobPayloads = _jobs
          .map(
            (j) => {
              'id': j['id'],
              'title': j['title'] ?? j['serviceType'] ?? 'Job',
              'address': j['address'] ?? '',
              'zip': j['zip'] ?? j['jobZip'] ?? '',
              'estimatedHours': j['estimatedHours'] ?? 8,
              'priority': j['priority'] ?? 'Medium',
            },
          )
          .toList();

      final crewPayloads = _crews
          .map(
            (c) => {
              'id': c['id'],
              'name': c['name'] ?? 'Crew',
              'size': c['size'] ?? 2,
              'available': c['available'] ?? true,
            },
          )
          .toList();

      final resp = await callable.call<dynamic>({
        'jobs': jobPayloads,
        'crews': crewPayloads,
        'weekStart': _weekStart.toIso8601String(),
      });

      final data = resp.data as Map<dynamic, dynamic>? ?? {};
      final entries =
          (data['schedule'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      await AiUsageService.instance.recordUsage('scheduling');

      if (mounted) {
        setState(() {
          _schedule = entries;
          _aiSummary = data['summary']?.toString();
          _optimizing = false;
        });
      }
    } catch (e) {
      // Fallback: local schedule generation when Cloud Function unavailable
      _generateLocalSchedule();
    }
  }

  void _generateLocalSchedule() {
    final days = List.generate(
      5,
      (i) => _weekStart.add(Duration(days: i + 1)),
    ); // Mon-Fri
    final entries = <Map<String, dynamic>>[];
    int jobIdx = 0;

    for (final crew in _crews) {
      for (final day in days) {
        if (jobIdx >= _jobs.length) break;
        final job = _jobs[jobIdx];
        entries.add({
          'day': DateFormat('EEEE').format(day),
          'date': DateFormat('yyyy-MM-dd').format(day),
          'crew': crew['name'] ?? 'Crew',
          'job': job['title'] ?? job['serviceType'] ?? 'Job',
          'address': job['address'] ?? '',
          'hours': job['estimatedHours'] ?? 8,
          'priority': job['priority'] ?? 'Medium',
        });
        jobIdx++;
      }
    }

    setState(() {
      _schedule = entries;
      _aiSummary =
          'Local schedule created (${entries.length} assignments). '
          'Cloud AI unavailable — upgrade to get weather-aware, '
          'drive-time-optimized schedules.';
      _optimizing = false;
    });
  }

  // ── Save schedule to Firestore ────────────────────────────────────────────

  Future<void> _saveSchedule() async {
    if (_schedule.isEmpty) return;

    try {
      final weekKey = DateFormat('yyyy-MM-dd').format(_weekStart);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('schedules')
          .doc(weekKey)
          .set({
            'weekStart': _weekStart,
            'entries': _schedule,
            'summary': _aiSummary,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule saved ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  // ── Week navigation ───────────────────────────────────────────────────────

  void _prevWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() =>
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Scheduling AI'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Pipeline'),
            Tab(icon: Icon(Icons.groups), text: 'Crews'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Schedule'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPipelineTab(cs),
          _buildCrewsTab(cs),
          _buildScheduleTab(cs),
        ],
      ),
    );
  }

  // ── Pipeline Tab ──────────────────────────────────────────────────────────

  Widget _buildPipelineTab(ColorScheme cs) {
    if (_loadingJobs) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_jobs.length} jobs in pipeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Job'),
                onPressed: _showAddJobDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: cs.outline),
                      const SizedBox(height: 12),
                      Text(
                        'No jobs in pipeline',
                        style: TextStyle(color: cs.outline),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add your first job'),
                        onPressed: _showAddJobDialog,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final job = _jobs[i];
                    final priority = job['priority'] ?? 'Medium';
                    final priorityColor = priority == 'High'
                        ? Colors.red
                        : priority == 'Low'
                        ? Colors.grey
                        : Colors.orange;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: priorityColor.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(Icons.work_outline, color: priorityColor),
                        ),
                        title: Text(
                          job['title'] ?? job['serviceType'] ?? 'Untitled Job',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${job['address'] ?? 'No address'} · '
                          '${job['estimatedHours'] ?? '?'}h · $priority',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Chip(
                          label: Text(
                            job['status'] ?? 'accepted',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Crews Tab ─────────────────────────────────────────────────────────────

  Widget _buildCrewsTab(ColorScheme cs) {
    if (_loadingCrews) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_crews.length} crews',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.group_add, size: 18),
                label: const Text('Add Crew'),
                onPressed: _showAddCrewDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _crews.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final crew = _crews[i];
              final available = crew['available'] == true;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (available ? Colors.green : Colors.grey)
                        .withValues(alpha: 0.15),
                    child: Icon(
                      Icons.groups,
                      color: available ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(crew['name'] ?? 'Crew'),
                  subtitle: Text(
                    '${crew['size'] ?? '?'} members · '
                    '${available ? 'Available' : 'Busy'}',
                  ),
                  trailing: Switch(
                    value: available,
                    onChanged: (v) async {
                      final id = crew['id'];
                      if (id == 'default') {
                        setState(() => crew['available'] = v);
                        return;
                      }
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .collection('crews')
                          .doc(id)
                          .update({'available': v});
                      await _loadCrews();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Schedule Tab ──────────────────────────────────────────────────────────

  Widget _buildScheduleTab(ColorScheme cs) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';

    return Column(
      children: [
        // Week navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevWeek,
              ),
              Expanded(
                child: Text(
                  weekLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextWeek,
              ),
            ],
          ),
        ),
        // Optimize button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _optimizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_optimizing ? 'Optimizing…' : 'AI Optimize Schedule'),
              onPressed: _optimizing ? null : _optimizeSchedule,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),
        if (_aiSummary != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: cs.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _aiSummary!,
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Schedule entries
        Expanded(
          child: _schedule.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: cs.outline),
                      const SizedBox(height: 12),
                      Text(
                        'Tap "AI Optimize" to generate\na smart schedule',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.outline),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _schedule.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final entry = _schedule[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry['day'] ?? ''} '
                                  '${entry['date'] ?? ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                ),
                                const Spacer(),
                                if (entry['weather'] != null)
                                  Chip(
                                    avatar: const Icon(Icons.cloud, size: 14),
                                    label: Text(
                                      entry['weather'].toString(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.work_outline, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry['job']?.toString() ?? 'Job',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (entry['address'] != null &&
                                entry['address'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        entry['address'].toString(),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.groups,
                                  size: 14,
                                  color: cs.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  entry['crew']?.toString() ?? 'Crew',
                                  style: TextStyle(color: cs.secondary),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: cs.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${entry['hours'] ?? '?'}h',
                                  style: TextStyle(color: cs.outline),
                                ),
                                if (entry['driveTime'] != null) ...[
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.directions_car,
                                    size: 14,
                                    color: cs.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry['driveTime']}min',
                                    style: TextStyle(color: cs.outline),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Save bar
        if (_schedule.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Schedule'),
                  onPressed: _saveSchedule,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
