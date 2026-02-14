import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/job_timeline_service.dart';

/// Icon resolver from string keys stored in Firestore.
IconData _iconFromKey(String key) {
  const map = {
    'check_circle': Icons.check_circle,
    'shopping_cart': Icons.shopping_cart,
    'format_paint': Icons.format_paint,
    'brush': Icons.brush,
    'layers': Icons.layers,
    'auto_fix_high': Icons.auto_fix_high,
    'cleaning_services': Icons.cleaning_services,
    'verified': Icons.verified,
    'water_drop': Icons.water_drop,
    'construction': Icons.construction,
    'grid_view': Icons.grid_view,
    'blur_on': Icons.blur_on,
    'build': Icons.build,
    'science': Icons.science,
    'shower': Icons.shower,
    'door_front': Icons.door_front_door,
    'handyman': Icons.handyman,
  };
  return map[key] ?? Icons.circle;
}

/// Pizza-tracker-style live job timeline.
/// Homeowners see real-time progress; contractors update stages.
class LiveJobTimelineScreen extends StatefulWidget {
  final String jobId;
  final bool isContractor;

  const LiveJobTimelineScreen({
    super.key,
    required this.jobId,
    this.isContractor = false,
  });

  @override
  State<LiveJobTimelineScreen> createState() => _LiveJobTimelineScreenState();
}

class _LiveJobTimelineScreenState extends State<LiveJobTimelineScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initTimeline(String serviceType) async {
    setState(() => _initializing = true);
    try {
      await JobTimelineService.instance.initializeTimeline(
        widget.jobId,
        serviceType,
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Job Progress'), centerTitle: true),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: JobTimelineService.instance.watchTimeline(widget.jobId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stages = snap.data ?? [];

          // Not initialized yet — show init button for contractor
          if (stages.isEmpty) {
            return _buildEmptyState(context, scheme);
          }

          final completedCount = stages
              .where((s) => s['status'] == 'completed')
              .length;
          final total = stages.length;
          final progress = total > 0 ? completedCount / total : 0.0;

          return Column(
            children: [
              // ── Progress header ──
              _ProgressHeader(
                progress: progress,
                completedCount: completedCount,
                total: total,
                scheme: scheme,
              ),

              // ── Stage list ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: stages.length,
                  itemBuilder: (context, index) {
                    final stage = stages[index];
                    final status = stage['status'] ?? 'pending';
                    final isFirst = index == 0;
                    final isLast = index == stages.length - 1;

                    return _StageRow(
                      stage: stage,
                      status: status,
                      isFirst: isFirst,
                      isLast: isLast,
                      pulseAnimation: _pulseCtrl,
                      isContractor: widget.isContractor,
                      onComplete:
                          widget.isContractor &&
                              (status == 'in_progress' || status == 'pending')
                          ? () => _showCompleteSheet(stage)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme scheme) {
    if (!widget.isContractor) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Timeline not started yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your contractor will activate the progress tracker\nonce they begin working.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Contractor — show initialize button
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .get(),
      builder: (context, jobSnap) {
        final serviceType =
            (jobSnap.data?.data() as Map<String, dynamic>?)?['serviceName'] ??
            'interior_painting';

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rocket_launch, size: 64, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Start Progress Tracker',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Initialize the live timeline so your client can\ntrack progress in real time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _initializing
                      ? null
                      : () => _initTimeline(serviceType),
                  icon: _initializing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _initializing ? 'Initializing...' : 'Start Tracking',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompleteSheet(Map<String, dynamic> stage) {
    final noteCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete: ${stage['label']}',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Add a note (optional)',
                  hintText: 'e.g. "Used 2 coats of Sherwin-Williams Alabaster"',
                  filled: true,
                  fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    try {
                      await JobTimelineService.instance.completeStage(
                        widget.jobId,
                        stage['key'],
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Complete'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────
// Progress Header — circular progress + stats
// ────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int total;
  final ColorScheme scheme;

  const _ProgressHeader({
    required this.progress,
    required this.completedCount,
    required this.total,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: scheme.outline.withValues(alpha: .2),
                    color: progress >= 1.0 ? Colors.green : scheme.primary,
                  ),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress >= 1.0 ? 'Job Complete! 🎉' : 'In Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedCount of $total stages done',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onPrimaryContainer.withValues(alpha: .7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Individual stage row with connector line
// ────────────────────────────────────────────────────────────
class _StageRow extends StatelessWidget {
  final Map<String, dynamic> stage;
  final String status;
  final bool isFirst;
  final bool isLast;
  final AnimationController pulseAnimation;
  final bool isContractor;
  final VoidCallback? onComplete;

  const _StageRow({
    required this.stage,
    required this.status,
    required this.isFirst,
    required this.isLast,
    required this.pulseAnimation,
    required this.isContractor,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isComplete = status == 'completed';
    final isActive = status == 'in_progress';
    final completedAt = stage['completedAt'] as Timestamp?;
    final note = stage['note'] as String?;

    final Color dotColor = isComplete
        ? Colors.green
        : isActive
        ? scheme.primary
        : scheme.outlineVariant;

    final Color lineColor = isComplete
        ? Colors.green.withValues(alpha: .4)
        : scheme.outlineVariant.withValues(alpha: .3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Vertical connector + dot ──
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top line
                if (!isFirst)
                  Expanded(child: Container(width: 3, color: lineColor))
                else
                  const Expanded(child: SizedBox()),

                // Dot
                isActive
                    ? AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withValues(
                                    alpha: .3 + pulseAnimation.value * .3,
                                  ),
                                  blurRadius: 8 + pulseAnimation.value * 6,
                                  spreadRadius: pulseAnimation.value * 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _iconFromKey(stage['icon'] ?? ''),
                              size: 14,
                              color: Colors.white,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                        child: Icon(
                          isComplete
                              ? Icons.check
                              : _iconFromKey(stage['icon'] ?? ''),
                          size: 14,
                          color: Colors.white,
                        ),
                      ),

                // Bottom line
                if (!isLast)
                  Expanded(child: Container(width: 3, color: lineColor))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Content card ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive
                    ? scheme.primaryContainer.withValues(alpha: .3)
                    : isComplete
                    ? Colors.green.withValues(alpha: .06)
                    : scheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
                border: isActive
                    ? Border.all(color: scheme.primary.withValues(alpha: .4))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage['label'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isComplete
                                ? Colors.green.shade700
                                : isActive
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isComplete && completedAt != null)
                        Text(
                          DateFormat(
                            'MMM d, h:mm a',
                          ).format(completedAt.toDate()),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: scheme.primary,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (onComplete != null && isActive) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Mark Complete'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
