import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../theme/proserve_theme.dart';

/// Customer-facing screen to browse a contractor's availability
/// and book a specific time slot.
class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
  });

  final String contractorId;
  final String contractorName;

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _availability = {};
  bool _loading = true;
  String? _selectedSlot;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(widget.contractorId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final raw = data['availability'] as Map<String, dynamic>?;
        if (raw != null) {
          final parsed = <String, List<Map<String, dynamic>>>{};
          raw.forEach((key, value) {
            if (value is List) {
              parsed[key] = List<Map<String, dynamic>>.from(
                value.map((item) => Map<String, dynamic>.from(item as Map)),
              );
            }
          });
          _availability = parsed;
        }
      }
    } catch (e) {
      debugPrint('BookingCalendar load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<Map<String, dynamic>> _availableSlots() {
    final key = _dateKey(_selectedDate);
    final slots = _availability[key] ?? [];
    return slots.where((s) => s['booked'] != true).toList();
  }

  bool _dateHasSlots(DateTime d) {
    final key = _dateKey(d);
    final slots = _availability[key] ?? [];
    return slots.any((s) => s['booked'] != true);
  }

  Future<void> _book() async {
    if (_selectedSlot == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      // Use a transaction to prevent double-booking the same slot
      final contractorRef = FirebaseFirestore.instance
          .collection('contractors')
          .doc(widget.contractorId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final contractorSnap = await tx.get(contractorRef);
        final liveAvailability =
            (contractorSnap.data()?['availability'] as Map<String, dynamic>?) ??
                {};
        final key = _dateKey(_selectedDate);
        final liveSlots =
            (liveAvailability[key] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
                [];
        final slot = liveSlots.firstWhere(
          (s) => s['time'] == _selectedSlot,
          orElse: () => <String, dynamic>{},
        );
        if (slot.isEmpty || slot['booked'] == true) {
          throw Exception(
            'This slot was just booked by someone else. Please choose another.',
          );
        }

        // Mark slot as booked
        for (final s in liveSlots) {
          if (s['time'] == _selectedSlot) {
            s['booked'] = true;
          }
        }
        liveAvailability[key] = liveSlots;
        tx.update(contractorRef, {'availability': liveAvailability});
      });

      // Create booking doc outside the transaction
      final bookingRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add({
            'customerId': uid,
            'contractorId': widget.contractorId,
            'contractorName': widget.contractorName,
            'date': _dateKey(_selectedDate),
            'time': _selectedSlot,
            'status': 'confirmed',
            'reminderSent': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Update local state
      final key = _dateKey(_selectedDate);
      final slots = _availability[key] ?? [];
      for (final slot in slots) {
        if (slot['time'] == _selectedSlot) {
          slot['booked'] = true;
        }
      }

      // Send booking confirmation notification via Cloud Function
      try {
        await FirebaseFunctions.instance
            .httpsCallable('sendBookingConfirmation')
            .call({
              'bookingId': bookingRef.id,
              'contractorId': widget.contractorId,
              'customerId': uid,
              'date': _dateKey(_selectedDate),
              'time': _selectedSlot,
            });
      } catch (_) {
        // Notifications are best-effort
      }

      // Write notification doc for both parties
      final batch = FirebaseFirestore.instance.batch();
      final notifData = {
        'title': 'Booking Confirmed',
        'body':
            '${DateFormat.yMMMd().format(_selectedDate)} at $_selectedSlot with ${widget.contractorName}',
        'type': 'booking_confirmed',
        'route': '/bookings',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(),
        notifData,
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.contractorId)
            .collection('notifications')
            .doc(),
        {
          ...notifData,
          'body':
              'New booking: ${DateFormat.yMMMd().format(_selectedDate)} at $_selectedSlot',
        },
      );
      await batch.commit();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Booking Confirmed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat.yMMMd().format(_selectedDate)} at $_selectedSlot\n'
                'with ${widget.contractorName}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ll receive a reminder before your appointment.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final days = List.generate(14, (i) => today.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.contractorName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date strip
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, i) {
                      final day = days[i];
                      final selected = _dateKey(day) == _dateKey(_selectedDate);
                      final hasSlots = _dateHasSlots(day);

                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedDate = day;
                          _selectedSlot = null;
                        }),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary
                                : hasSlots
                                ? scheme.surfaceContainerHighest
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? null
                                : Border.all(color: scheme.outlineVariant),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat.E().format(day),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                ),
                              ),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: selected
                                      ? scheme.onPrimary
                                      : hasSlots
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              if (!hasSlots)
                                Text(
                                  'Full',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: selected
                                        ? scheme.onPrimary.withValues(
                                            alpha: 0.7,
                                          )
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(),

                // Time slots
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final slots = _availableSlots();
                      if (slots.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 48,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No available slots on this date',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            DateFormat.yMMMMd().format(_selectedDate),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: slots.map((slot) {
                              final time = slot['time'] as String;
                              final selected = _selectedSlot == time;

                              return ChoiceChip(
                                label: Text(time),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _selectedSlot = time),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Book button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ProServeCTAButton(
                      onPressed: _selectedSlot == null || _submitting
                          ? null
                          : _book,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _selectedSlot != null
                                  ? 'Confirm Booking — $_selectedSlot'
                                  : 'Select a Time Slot',
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
