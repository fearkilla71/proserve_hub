import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  final List<String> _timeSlots = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
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

    try {
      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({'availability': _availability}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability Calendar'),
        actions: [
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
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isAvailable
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: InkWell(
                            onTap: () => _toggleSlot(timeSlot),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    isAvailable
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: isAvailable
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    timeSlot,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isAvailable
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM d, yyyy').format(_selectedDate),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        const Duration(days: 1),
                      );
                    });
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
                  onTap: () => setState(() => _selectedDate = date),
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
