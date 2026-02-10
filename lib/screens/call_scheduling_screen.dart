import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CallSchedulingScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? conversationId;

  const CallSchedulingScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.conversationId,
  });

  @override
  State<CallSchedulingScreen> createState() => _CallSchedulingScreenState();
}

class _CallSchedulingScreenState extends State<CallSchedulingScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _callType = 'audio';
  final _notesController = TextEditingController();
  bool _isScheduling = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _scheduleCall() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isScheduling = true);

    try {
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await FirebaseFirestore.instance.collection('scheduled_calls').add({
        'scheduledBy': user.uid,
        'scheduledWith': widget.otherUserId,
        'scheduledByName':
            (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get())
                .data()?['name'],
        'scheduledWithName': widget.otherUserName,
        'scheduledTime': Timestamp.fromDate(scheduledDateTime),
        'callType': _callType,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'conversationId': widget.conversationId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call scheduled successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error scheduling call: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isScheduling = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Call')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Schedule a call with ${widget.otherUserName}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Call Type Selection
            Text('Call Type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Audio call only — video call not supported.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('Audio Call'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Date Selection
            Text('Date', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat.yMMMMd().format(_selectedDate)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickDate,
            ),

            const SizedBox(height: 16),

            // Time Selection
            Text('Time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const Icon(Icons.access_time),
              title: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _pickTime,
            ),

            const SizedBox(height: 24),

            // Notes
            Text(
              'Notes (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g., Discuss project timeline',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Schedule Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isScheduling ? null : _scheduleCall,
                icon: _isScheduling
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Schedule Call'),
              ),
            ),

            const SizedBox(height: 16),

            // Scheduled Calls List
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Scheduled Calls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('scheduled_calls')
                  .where(
                    'scheduledBy',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .where('status', isEqualTo: 'pending')
                  .orderBy('scheduledTime', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final calls = snapshot.data!.docs;

                if (calls.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No scheduled calls',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: calls.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final scheduledTime = (data['scheduledTime'] as Timestamp?)
                        ?.toDate();
                    final callType = data['callType']?.toString() ?? 'video';
                    final notes = data['notes']?.toString() ?? '';
                    final withName =
                        data['scheduledWithName']?.toString() ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          callType == 'video' ? Icons.videocam : Icons.phone,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(withName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (scheduledTime != null)
                              Text(
                                DateFormat(
                                  'MMM d, y • h:mm a',
                                ).format(scheduledTime),
                              ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () async {
                            await doc.reference.delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Call cancelled')),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
