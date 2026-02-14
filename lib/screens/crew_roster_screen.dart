import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/crew_roster_service.dart';

/// Crew Roster management screen — Enterprise only.
/// Contractors can add/edit/remove crew members with skills, ratings, certs.
class CrewRosterScreen extends StatefulWidget {
  const CrewRosterScreen({super.key});

  @override
  State<CrewRosterScreen> createState() => _CrewRosterScreenState();
}

class _CrewRosterScreenState extends State<CrewRosterScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crew Roster'),
        actions: [
          IconButton(
            tooltip: 'Add crew member',
            onPressed: () => _showAddEditSheet(context),
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: CrewRosterService.instance.watchCrew(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState(scheme);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _CrewMemberCard(
                id: doc.id,
                data: data,
                onEdit: () =>
                    _showAddEditSheet(context, id: doc.id, data: data),
                onDelete: () => _confirmDelete(doc.id, data['name'] ?? ''),
                onToggleAvail: (val) {
                  CrewRosterService.instance.toggleAvailability(doc.id, val);
                },
                onAssignJob: () => _showAssignJobSheet(
                  context,
                  crewMemberId: doc.id,
                  crewMemberName: data['name'] ?? 'Unknown',
                ),
                onLogHours: () => _showLogHoursSheet(
                  context,
                  crewMemberId: doc.id,
                  crewMemberName: data['name'] ?? 'Unknown',
                  defaultRate: (data['hourlyRate'] as num?)?.toDouble() ?? 25.0,
                ),
                onViewLaborHistory: () => _showLaborHistory(
                  context,
                  crewMemberId: doc.id,
                  crewMemberName: data['name'] ?? 'Unknown',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups,
              size: 72,
              color: scheme.primary.withValues(alpha: .4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Crew Members Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your crew so clients can see who\'s coming\nand their individual skills.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditSheet(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? data,
  }) {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final roleCtrl = TextEditingController(text: data?['role'] ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    final yearsCtrl = TextEditingController(
      text: (data?['yearsExperience'] ?? '').toString(),
    );
    final hourlyRateCtrl = TextEditingController(
      text: data?['hourlyRate'] != null
          ? (data!['hourlyRate'] as num).toStringAsFixed(2)
          : '',
    );
    final existingSkills =
        (data?['skills'] as List?)?.whereType<String>().toList() ?? [];
    final existingCerts =
        (data?['certifications'] as List?)?.whereType<String>().toList() ?? [];
    final existingRatings =
        (data?['skillRatings'] as Map?)?.cast<String, dynamic>() ?? {};

    List<String> skills = List.from(existingSkills);
    List<String> certs = List.from(existingCerts);
    Map<String, int> ratings = existingRatings.map(
      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 3),
    );

    final skillCtrl = TextEditingController();
    final certCtrl = TextEditingController();

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
                      id == null ? 'Add Crew Member' : 'Edit Crew Member',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: _inputDec(ctx, 'Full name', Icons.person),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roleCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Role / Title',
                        Icons.work_outline,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Phone (optional)',
                        Icons.phone,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: yearsCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Years experience',
                        Icons.timeline,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hourlyRateCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Hourly rate (\$)',
                        Icons.attach_money,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                    ),

                    // ── Skills ──
                    const SizedBox(height: 20),
                    Text(
                      'Skills',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skills.map((s) {
                        final rating = ratings[s] ?? 3;
                        return Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s),
                              const SizedBox(width: 4),
                              ...List.generate(
                                5,
                                (i) => InkWell(
                                  onTap: () {
                                    setSheetState(() => ratings[s] = i + 1);
                                  },
                                  child: Icon(
                                    i < rating ? Icons.star : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onDeleted: () {
                            setSheetState(() {
                              skills.remove(s);
                              ratings.remove(s);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: skillCtrl,
                            decoration: _inputDec(
                              ctx,
                              'Add skill',
                              Icons.add_circle_outline,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            final s = skillCtrl.text.trim();
                            if (s.isEmpty) return;
                            setSheetState(() {
                              skills.add(s);
                              ratings[s] = 3;
                            });
                            skillCtrl.clear();
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),

                    // ── Certifications ──
                    const SizedBox(height: 20),
                    Text(
                      'Certifications',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: certs.map((c) {
                        return Chip(
                          avatar: const Icon(Icons.verified, size: 16),
                          label: Text(c),
                          onDeleted: () => setSheetState(() => certs.remove(c)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: certCtrl,
                            decoration: _inputDec(
                              ctx,
                              'Add certification',
                              Icons.workspace_premium,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            final c = certCtrl.text.trim();
                            if (c.isEmpty) return;
                            setSheetState(() => certs.add(c));
                            certCtrl.clear();
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Name is required')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            if (id == null) {
                              await CrewRosterService.instance.addCrewMember(
                                name: name,
                                role: roleCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty
                                    ? null
                                    : phoneCtrl.text.trim(),
                                skills: skills,
                                skillRatings: ratings,
                                certifications: certs,
                                yearsExperience:
                                    int.tryParse(yearsCtrl.text.trim()) ?? 0,
                                hourlyRate: double.tryParse(
                                  hourlyRateCtrl.text.trim(),
                                ),
                              );
                            } else {
                              await CrewRosterService.instance.updateCrewMember(
                                id,
                                name: name,
                                role: roleCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty
                                    ? null
                                    : phoneCtrl.text.trim(),
                                skills: skills,
                                skillRatings: ratings,
                                certifications: certs,
                                yearsExperience:
                                    int.tryParse(yearsCtrl.text.trim()) ?? 0,
                                hourlyRate: double.tryParse(
                                  hourlyRateCtrl.text.trim(),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: Text(id == null ? 'Add Member' : 'Save Changes'),
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

  InputDecoration _inputDec(BuildContext ctx, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ── Job Assignment ──────────────────────────────────────────
  void _showAssignJobSheet(
    BuildContext context, {
    required String crewMemberId,
    required String crewMemberName,
  }) async {
    final jobs = await CrewRosterService.instance.getActiveJobs();
    if (!context.mounted) return;

    if (jobs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No active jobs to assign')));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign $crewMemberName to Job',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: jobs.length,
                  itemBuilder: (ctx, i) {
                    final job = jobs[i];
                    final title = job['serviceType'] ?? job['title'] ?? 'Job';
                    final status = job['status'] ?? '';
                    final address = job['address'] ?? '';
                    final alreadyAssigned =
                        (job['assignedCrew'] as List?)?.contains(
                          crewMemberId,
                        ) ??
                        false;

                    return ListTile(
                      leading: Icon(
                        alreadyAssigned ? Icons.check_circle : Icons.assignment,
                        color: alreadyAssigned ? Colors.green : null,
                      ),
                      title: Text(title),
                      subtitle: Text(
                        '${status.toString().toUpperCase()} • $address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: alreadyAssigned
                          ? const Text(
                              'Assigned',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: alreadyAssigned
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              HapticFeedback.mediumImpact();
                              try {
                                final existing =
                                    (job['assignedCrew'] as List?)
                                        ?.cast<String>() ??
                                    [];
                                final details =
                                    (job['assignedCrewDetails'] as List?)
                                        ?.cast<Map<String, dynamic>>()
                                        .map((m) => m.cast<String, String>())
                                        .toList() ??
                                    [];
                                existing.add(crewMemberId);
                                details.add({
                                  'id': crewMemberId,
                                  'name': crewMemberName,
                                });
                                await CrewRosterService.instance
                                    .assignCrewToJob(
                                      job['id'],
                                      existing,
                                      details,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$crewMemberName assigned to $title',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Log Hours ───────────────────────────────────────────────
  void _showLogHoursSheet(
    BuildContext context, {
    required String crewMemberId,
    required String crewMemberName,
    required double defaultRate,
  }) async {
    final jobs = await CrewRosterService.instance.getActiveJobs();
    if (!context.mounted) return;

    if (jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active jobs to log hours for')),
      );
      return;
    }

    final hoursCtrl = TextEditingController();
    final rateCtrl = TextEditingController(
      text: defaultRate.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();
    String? selectedJobId;
    String selectedJobTitle = '';
    DateTime selectedDate = DateTime.now();

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
                      'Log Hours — $crewMemberName',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: _inputDec(ctx, 'Select job', Icons.work),
                      items: jobs.map((j) {
                        final title = j['serviceType'] ?? j['title'] ?? 'Job';
                        return DropdownMenuItem(
                          value: j['id'] as String,
                          child: Text(title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setSheetState(() {
                          selectedJobId = val;
                          final job = jobs.firstWhere((j) => j['id'] == val);
                          selectedJobTitle =
                              job['serviceType'] ?? job['title'] ?? 'Job';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hoursCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Hours worked',
                        Icons.schedule,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Hourly rate (\$)',
                        Icons.attach_money,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(DateFormat.yMMMd().format(selectedDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 90),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: _inputDec(
                        ctx,
                        'Notes (optional)',
                        Icons.note,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    if (hoursCtrl.text.isNotEmpty && rateCtrl.text.isNotEmpty)
                      Builder(
                        builder: (_) {
                          final h = double.tryParse(hoursCtrl.text) ?? 0;
                          final r = double.tryParse(rateCtrl.text) ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Total: \$${(h * r).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(ctx).colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final hours = double.tryParse(hoursCtrl.text.trim());
                          final rate = double.tryParse(rateCtrl.text.trim());
                          if (selectedJobId == null ||
                              hours == null ||
                              hours <= 0 ||
                              rate == null ||
                              rate <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select a job and enter valid hours & rate',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          HapticFeedback.mediumImpact();
                          try {
                            await CrewRosterService.instance.logLabor(
                              crewMemberId: crewMemberId,
                              crewMemberName: crewMemberName,
                              jobId: selectedJobId!,
                              jobTitle: selectedJobTitle,
                              hoursWorked: hours,
                              hourlyRate: rate,
                              date: selectedDate,
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${hours}h logged for $crewMemberName — \$${(hours * rate).toStringAsFixed(2)}',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Log Hours'),
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

  // ── Labor History ───────────────────────────────────────────
  void _showLaborHistory(
    BuildContext context, {
    required String crewMemberId,
    required String crewMemberName,
  }) async {
    final logs = await CrewRosterService.instance.getCrewMemberLaborLogs(
      crewMemberId,
    );
    if (!context.mounted) return;

    final totalHours = logs.fold<double>(
      0,
      (acc, l) => acc + ((l['hoursWorked'] as num?)?.toDouble() ?? 0),
    );
    final totalCost = logs.fold<double>(
      0,
      (acc, l) => acc + ((l['totalCost'] as num?)?.toDouble() ?? 0),
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Labor History — $crewMemberName',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Summary row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: .3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${totalHours.toStringAsFixed(1)}h',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                              Text(
                                'Total Hours',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '\$${totalCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                'Total Cost',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: logs.isEmpty
                        ? Center(
                            child: Text(
                              'No labor logs yet',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: logs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final log = logs[i];
                              final date = (log['date'] as Timestamp?)
                                  ?.toDate();
                              final hours =
                                  (log['hoursWorked'] as num?)?.toDouble() ?? 0;
                              final rate =
                                  (log['hourlyRate'] as num?)?.toDouble() ?? 0;
                              final cost =
                                  (log['totalCost'] as num?)?.toDouble() ?? 0;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: scheme.secondaryContainer,
                                  child: Icon(
                                    Icons.schedule,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                                title: Text(
                                  log['jobTitle'] ?? 'Job',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${date != null ? DateFormat.yMMMd().format(date) : ''} • ${hours}h @ \$${rate.toStringAsFixed(0)}/hr'
                                  '${log['notes'] != null ? '\n${log['notes']}' : ''}',
                                ),
                                trailing: Text(
                                  '\$${cost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                isThreeLine: log['notes'] != null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Crew Member'),
        content: Text('Remove $name from your crew?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              CrewRosterService.instance.removeCrewMember(id);
              HapticFeedback.lightImpact();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Crew member card widget
// ────────────────────────────────────────────────────────────
class _CrewMemberCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleAvail;
  final VoidCallback onAssignJob;
  final VoidCallback onLogHours;
  final VoidCallback onViewLaborHistory;

  const _CrewMemberCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvail,
    required this.onAssignJob,
    required this.onLogHours,
    required this.onViewLaborHistory,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = data['name'] ?? 'Unknown';
    final role = data['role'] ?? '';
    final available = data['available'] as bool? ?? true;
    final skills =
        (data['skills'] as List?)?.whereType<String>().toList() ?? [];
    final certs =
        (data['certifications'] as List?)?.whereType<String>().toList() ?? [];
    final ratings =
        (data['skillRatings'] as Map?)?.cast<String, dynamic>() ?? {};
    final yearsExp = (data['yearsExperience'] as num?)?.toInt() ?? 0;
    final jobsDone = (data['jobsCompleted'] as num?)?.toInt() ?? 0;
    final hourlyRate = (data['hourlyRate'] as num?)?.toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (role.isNotEmpty)
                        Text(
                          role,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Availability toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: available
                        ? Colors.green.withValues(alpha: .12)
                        : Colors.red.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        available ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: available ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        available ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: available ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Stats row ──
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(icon: Icons.timeline, label: '$yearsExp yrs exp'),
                const SizedBox(width: 12),
                _StatChip(icon: Icons.task_alt, label: '$jobsDone jobs'),
                if (hourlyRate != null) ...[
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.attach_money,
                    label: '\$${hourlyRate.toStringAsFixed(0)}/hr',
                  ),
                ],
              ],
            ),

            // ── Skills with ratings ──
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.map((s) {
                  final rating = (ratings[s] as num?)?.toInt() ?? 3;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 4),
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 12,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // ── Certifications ──
            if (certs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: certs.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          c,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // ── Actions ──
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => onToggleAvail(!available),
                  icon: Icon(
                    available ? Icons.block : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(available ? 'Unavailable' : 'Available'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onAssignJob,
                  icon: const Icon(Icons.assignment_ind, size: 18),
                  label: const Text('Assign'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Log hours',
                  onPressed: onLogHours,
                  icon: const Icon(Icons.schedule, size: 20),
                ),
                IconButton(
                  tooltip: 'Labor history',
                  onPressed: onViewLaborHistory,
                  icon: const Icon(Icons.history, size: 20),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Client-facing crew viewer (read-only, shown on job detail)
// ────────────────────────────────────────────────────────────
class CrewViewerWidget extends StatelessWidget {
  final String contractorId;
  const CrewViewerWidget({super.key, required this.contractorId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CrewRosterService.instance.watchCrew(contractorId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.groups, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Meet the Crew',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final d = docs[index].data();
                  final available = d['available'] as bool? ?? true;
                  if (!available) return const SizedBox.shrink();

                  final name = d['name'] ?? '';
                  final role = d['role'] ?? '';
                  final skills =
                      (d['skills'] as List?)
                          ?.whereType<String>()
                          .take(3)
                          .toList() ??
                      [];

                  return Container(
                    width: 130,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          role,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        if (skills.isNotEmpty)
                          Text(
                            skills.join(' • '),
                            style: TextStyle(
                              fontSize: 9,
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
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
}
