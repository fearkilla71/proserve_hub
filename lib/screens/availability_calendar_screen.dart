import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/job_scheduling_service.dart';

class AvailabilityCalendarScreen extends StatefulWidget {
  const AvailabilityCalendarScreen({super.key});

  @override
  State<AvailabilityCalendarScreen> createState() =>
      _AvailabilityCalendarScreenState();
}

class _AvailabilityCalendarScreenState
    extends State<AvailabilityCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _availability = {};
  bool _isLoading = true;
  bool _syncing = false;
  bool _calendarLinked = false;

  // Scheduled jobs for selected date.
  List<Map<String, dynamic>> _scheduledJobs = [];

  // Configurable working hours.
  TimeOfDay _workStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 18, minute: 0);

  // Recurring patterns: days of week that are auto-available.
  // 1=Mon … 7=Sun (DateTime.monday .. DateTime.sunday).
  Set<int> _recurringDays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  List<String> get _timeSlots {
    final slots = <String>[];
    int h = _workStart.hour;
    final end = _workEnd.hour;
    while (h <= end) {
      final period = h >= 12 ? 'PM' : 'AM';
      final display = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      slots.add('${display.toString().padLeft(2, '0')}:00 $period');
      h++;
    }
    return slots;
  }

  @override
  void initState() {
    super.initState();
    _loadAvailability();
    _checkCalendarLinked();
    _loadScheduledJobs();
  }

  Future<void> _loadScheduledJobs() async {
    try {
      final jobs = await JobSchedulingService.instance.getScheduledJobsForDate(
        _selectedDate,
      );
      if (mounted) setState(() => _scheduledJobs = jobs);
    } catch (_) {}
  }

  Future<void> _loadAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final availabilityData = data['availability'] as Map<String, dynamic>?;

        if (availabilityData != null) {
          final Map<String, List<Map<String, dynamic>>> parsedAvailability = {};
          availabilityData.forEach((key, value) {
            if (value is List) {
              parsedAvailability[key] = List<Map<String, dynamic>>.from(
                value.map((item) => Map<String, dynamic>.from(item)),
              );
            }
          });
          setState(() => _availability = parsedAvailability);
        }

        // Load configurable hours.
        final startHour = data['workStartHour'] as int?;
        final endHour = data['workEndHour'] as int?;
        if (startHour != null) {
          _workStart = TimeOfDay(hour: startHour, minute: 0);
        }
        if (endHour != null) {
          _workEnd = TimeOfDay(hour: endHour, minute: 0);
        }

        // Load recurring day pattern.
        final recurring = data['recurringDays'] as List<dynamic>?;
        if (recurring != null) {
          _recurringDays = recurring.whereType<int>().toSet();
        }
      }
    } catch (e) {
      debugPrint('Error loading availability: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({
            'availability': _availability,
            'workStartHour': _workStart.hour,
            'workEndHour': _workEnd.hour,
            'recurringDays': _recurringDays.toList(),
          }, SetOptions(merge: true));

      messenger.showSnackBar(
        const SnackBar(content: Text('Availability saved successfully!')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool _isSlotAvailable(String timeSlot) {
    final dateKey = _getDateKey(_selectedDate);
    final slots = _availability[dateKey] ?? [];
    return slots.any((slot) => slot['time'] == timeSlot);
  }

  void _toggleSlot(String timeSlot) {
    final dateKey = _getDateKey(_selectedDate);
    final slots = _availability[dateKey] ?? [];

    setState(() {
      if (_isSlotAvailable(timeSlot)) {
        // Remove slot
        _availability[dateKey] = slots
            .where((slot) => slot['time'] != timeSlot)
            .toList();
        if (_availability[dateKey]!.isEmpty) {
          _availability.remove(dateKey);
        }
      } else {
        // Add slot
        _availability[dateKey] = [
          ...slots,
          {'time': timeSlot, 'booked': false},
        ];
      }
    });
  }

  void _setDayAvailability(bool available) {
    final dateKey = _getDateKey(_selectedDate);

    setState(() {
      if (available) {
        _availability[dateKey] = _timeSlots
            .map((time) => {'time': time, 'booked': false})
            .toList();
      } else {
        _availability.remove(dateKey);
      }
    });
  }

  Future<void> _checkCalendarLinked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('contractors')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() {
        _calendarLinked = doc.data()?['googleCalendarLinked'] as bool? ?? false;
      });
    }
  }

  Future<void> _linkGoogleCalendar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('getGoogleCalendarAuthUrl');
      final result = await callable.call(<String, dynamic>{});
      final url = result.data?['url'] as String?;

      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Google Calendar sync requires server setup. '
              'Contact support for assistance.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Calendar link error: $e')),
      );
    }
  }

  Future<void> _syncCalendar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _syncing = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable(
        'syncGoogleCalendar',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call(<String, dynamic>{
        'availability': _availability,
      });

      final imported = result.data?['imported'] as int? ?? 0;
      final exported = result.data?['exported'] as int? ?? 0;

      // Reload updated availability from Firestore
      await _loadAvailability();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Synced! $exported slots exported, $imported events imported.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability Calendar'),
        actions: [
          if (_calendarLinked)
            IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              tooltip: 'Sync Google Calendar',
              onPressed: _syncing ? null : _syncCalendar,
            )
          else
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Link Google Calendar',
              onPressed: _linkGoogleCalendar,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAvailability,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar Header
                _buildCalendarHeader(),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          onPressed: () => _setDayAvailability(true),
                          label: const Text('All Day Available'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel),
                          onPressed: () => _setDayAvailability(false),
                          label: const Text('All Day Unavailable'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Working Hours Config
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Working Hours',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _workStart,
                                    );
                                    if (picked != null) {
                                      setState(() => _workStart = picked);
                                    }
                                  },
                                  child: Text(
                                    'Start: ${_workStart.format(context)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _workEnd,
                                    );
                                    if (picked != null) {
                                      setState(() => _workEnd = picked);
                                    }
                                  },
                                  child: Text(
                                    'End: ${_workEnd.format(context)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Recurring Day Patterns
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recurring Days',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              TextButton(
                                onPressed: _applyRecurringPattern,
                                child: const Text('Apply to next 4 weeks'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              _dayChip('Mon', DateTime.monday),
                              _dayChip('Tue', DateTime.tuesday),
                              _dayChip('Wed', DateTime.wednesday),
                              _dayChip('Thu', DateTime.thursday),
                              _dayChip('Fri', DateTime.friday),
                              _dayChip('Sat', DateTime.saturday),
                              _dayChip('Sun', DateTime.sunday),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Time Slots
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(
                        'Select Available Time Slots',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to toggle availability for ${DateFormat('EEEE, MMMM d').format(_selectedDate)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._timeSlots.map((timeSlot) {
                        final isAvailable = _isSlotAvailable(timeSlot);
                        final bookedJob = _getBookedJobForSlot(timeSlot);
                        final isBooked = bookedJob != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isBooked
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : isAvailable
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: InkWell(
                            onTap: isBooked
                                ? null
                                : () => _toggleSlot(timeSlot),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    isBooked
                                        ? Icons.event_busy
                                        : isAvailable
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isBooked
                                        ? Theme.of(context).colorScheme.tertiary
                                        : isAvailable
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          timeSlot,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isAvailable || isBooked
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (isBooked)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              '${bookedJob['jobTitle']} — ${bookedJob['clientName']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isBooked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        (bookedJob['status'] as String? ??
                                                'scheduled')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScheduleJobSheet(context),
        icon: const Icon(Icons.event_available),
        label: const Text('Schedule Job'),
      ),
    );
  }

  Map<String, dynamic>? _getBookedJobForSlot(String timeSlot) {
    for (final job in _scheduledJobs) {
      final start = job['startSlot'] as String? ?? '';
      final end = job['endSlot'] as String? ?? '';
      final svc = JobSchedulingService.instance;
      final slotMin = svc.slotToMinutes(timeSlot);
      final startMin = svc.slotToMinutes(start);
      final endMin = svc.slotToMinutes(end);
      if (slotMin >= startMin && slotMin < endMin) return job;
    }
    return null;
  }

  void _showScheduleJobSheet(BuildContext context) async {
    final jobs = await JobSchedulingService.instance.getSchedulableJobs();
    if (!context.mounted) return;

    if (jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active jobs to schedule')),
      );
      return;
    }

    String? selectedJobId;
    String selectedJobTitle = '';
    String selectedClientName = '';
    String? selectedAddress;
    String? selectedStartSlot;
    String? selectedEndSlot;
    final notesCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Job — ${DateFormat('MMM d').format(_selectedDate)}',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select job',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                      items: jobs.map((j) {
                        final title = j['serviceType'] ?? j['title'] ?? 'Job';
                        return DropdownMenuItem(
                          value: j['id'] as String,
                          child: Text(title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        final job = jobs.firstWhere((j) => j['id'] == val);
                        setSheetState(() {
                          selectedJobId = val;
                          selectedJobTitle =
                              job['serviceType'] ?? job['title'] ?? 'Job';
                          selectedClientName = job['customerName'] ?? 'Client';
                          selectedAddress = job['address'] as String?;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Start time',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            items: _timeSlots
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setSheetState(() => selectedStartSlot = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'End time',
                              prefixIcon: Icon(Icons.access_time),
                              border: OutlineInputBorder(),
                            ),
                            items: _timeSlots
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setSheetState(() => selectedEndSlot = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (selectedJobId == null ||
                              selectedStartSlot == null ||
                              selectedEndSlot == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select a job and time range',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            await JobSchedulingService.instance.scheduleJob(
                              jobId: selectedJobId!,
                              jobTitle: selectedJobTitle,
                              clientName: selectedClientName,
                              date: _selectedDate,
                              startSlot: selectedStartSlot!,
                              endSlot: selectedEndSlot!,
                              address: selectedAddress,
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                            _loadScheduledJobs();
                            _loadAvailability();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$selectedJobTitle scheduled for ${DateFormat('MMM d').format(_selectedDate)}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.event_available),
                        label: const Text('Schedule'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dayChip(String label, int weekday) {
    final selected = _recurringDays.contains(weekday);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        setState(() {
          if (val) {
            _recurringDays.add(weekday);
          } else {
            _recurringDays.remove(weekday);
          }
        });
      },
    );
  }

  void _applyRecurringPattern() {
    final today = DateTime.now();
    setState(() {
      for (int i = 0; i < 28; i++) {
        final date = today.add(Duration(days: i));
        final dateKey = _getDateKey(date);
        if (_recurringDays.contains(date.weekday)) {
          // Only set if not already configured (don't overwrite manual edits)
          if (!_availability.containsKey(dateKey)) {
            _availability[dateKey] = _timeSlots
                .map((time) => {'time': time, 'booked': false})
                .toList();
          }
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Applied recurring pattern to next 4 weeks'),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                    _loadScheduledJobs();
                  },
                ),
                Text(
                  DateFormat('MMMM d, yyyy').format(_selectedDate),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  tooltip: 'Next day',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        const Duration(days: 1),
                      );
                    });
                    _loadScheduledJobs();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected =
                    DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(_selectedDate);
                final dateKey = _getDateKey(date);
                final hasSlots =
                    _availability.containsKey(dateKey) &&
                    _availability[dateKey]!.isNotEmpty;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _loadScheduledJobs();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: hasSlots
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
