import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Crew scheduling calendar — visual day/week view of crew member assignments.
class CrewScheduleCalendarScreen extends StatefulWidget {
  const CrewScheduleCalendarScreen({super.key});

  @override
  State<CrewScheduleCalendarScreen> createState() =>
      _CrewScheduleCalendarScreenState();
}

class _CrewScheduleCalendarScreenState
    extends State<CrewScheduleCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _weekView = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _weekView
              ? 'Week of ${DateFormat.MMMd().format(_weekStart)}'
              : DateFormat.yMMMd().format(_selectedDate),
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _weekView ? Icons.calendar_view_day : Icons.calendar_view_week,
            ),
            tooltip: _weekView ? 'Day view' : 'Week view',
            onPressed: () => setState(() => _weekView = !_weekView),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () => setState(() => _selectedDate = DateTime.now()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date navigation
          _buildDateNav(scheme),
          // Crew schedule list
          Expanded(
            child: _weekView ? _buildWeekView(scheme) : _buildDayView(scheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Assign Crew'),
      ),
    );
  }

  DateTime get _weekStart {
    final d = _selectedDate;
    return d.subtract(Duration(days: d.weekday % 7));
  }

  Widget _buildDateNav(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(
                  Duration(days: _weekView ? 7 : 1),
                );
              });
            },
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Text(
              DateFormat.yMMMMd().format(_selectedDate),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(
                  Duration(days: _weekView ? 7 : 1),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getAssignmentsForDate(_selectedDate),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.groups,
                  size: 64,
                  color: scheme.primary.withValues(alpha: .3),
                ),
                const SizedBox(height: 12),
                const Text('No crew assigned for this day'),
                const SizedBox(height: 6),
                Text(
                  'Tap + to assign crew members',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            return _CrewAssignmentCard(
              docId: docs[i].id,
              data: data,
              onDelete: () => _deleteAssignment(docs[i].id),
            );
          },
        );
      },
    );
  }

  Widget _buildWeekView(ColorScheme scheme) {
    final weekDays = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: 7,
      itemBuilder: (context, i) {
        final day = weekDays[i];
        final isToday = _isSameDay(day, DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat.E().format(day),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isToday ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat.MMMd().format(day),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getAssignmentsForDate(day),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'No assignments',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }
                return Column(
                  children: docs
                      .map(
                        (doc) => _CrewAssignmentCard(
                          docId: doc.id,
                          data: doc.data(),
                          compact: true,
                          onDelete: () => _deleteAssignment(doc.id),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getAssignmentsForDate(
    DateTime date,
  ) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('contractors')
        .doc(_uid)
        .collection('crew_schedule')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('date')
        .snapshots();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showAssignSheet(BuildContext context) {
    final memberCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '8:00 AM');
    final endCtrl = TextEditingController(text: '5:00 PM');
    final notesCtrl = TextEditingController();
    DateTime assignDate = _selectedDate;

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
                      'Assign Crew Member',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(ctx, memberCtrl, 'Crew member name', Icons.person),
                    const SizedBox(height: 12),
                    _field(ctx, jobCtrl, 'Job / Task', Icons.work),
                    const SizedBox(height: 12),
                    _field(ctx, addressCtrl, 'Address', Icons.location_on),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            ctx,
                            startCtrl,
                            'Start',
                            Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(ctx, endCtrl, 'End', Icons.access_time),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        'Date: ${DateFormat.yMMMd().format(assignDate)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: assignDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => assignDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _field(ctx, notesCtrl, 'Notes', Icons.note, maxLines: 2),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (memberCtrl.text.trim().isEmpty ||
                              jobCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Member and job are required'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            await FirebaseFirestore.instance
                                .collection('contractors')
                                .doc(_uid)
                                .collection('crew_schedule')
                                .add({
                                  'memberName': memberCtrl.text.trim(),
                                  'jobTitle': jobCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'startTime': startCtrl.text.trim(),
                                  'endTime': endCtrl.text.trim(),
                                  'date': Timestamp.fromDate(
                                    DateTime(
                                      assignDate.year,
                                      assignDate.month,
                                      assignDate.day,
                                      8,
                                    ),
                                  ),
                                  'notes': notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Assign'),
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

  void _deleteAssignment(String docId) {
    FirebaseFirestore.instance
        .collection('contractors')
        .doc(_uid)
        .collection('crew_schedule')
        .doc(docId)
        .delete();
  }

  Widget _field(
    BuildContext ctx,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: type,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.words,
    );
  }
}

class _CrewAssignmentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool compact;
  final VoidCallback onDelete;

  const _CrewAssignmentCard({
    required this.docId,
    required this.data,
    this.compact = false,
    required this.onDelete,
  });

  static const _memberColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.red,
    Colors.indigo,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final member = data['memberName'] ?? 'Unknown';
    final job = data['jobTitle'] ?? 'Task';
    final start = data['startTime'] ?? '';
    final end = data['endTime'] ?? '';
    final address = data['address'] as String?;
    final notes = data['notes'] as String?;
    final colorIdx = member.hashCode.abs() % _memberColors.length;
    final memberColor = _memberColors[colorIdx];

    if (compact) {
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: memberColor.withValues(alpha: .15),
            child: Text(
              member[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: memberColor,
                fontSize: 13,
              ),
            ),
          ),
          title: Text('$member — $job', style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            '$start – $end',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          trailing: IconButton(
            icon: Icon(Icons.close, size: 16, color: scheme.error),
            onPressed: onDelete,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Colored bar
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: memberColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    job,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (address != null && address.isNotEmpty)
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (notes != null && notes.isNotEmpty)
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$start – $end',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
