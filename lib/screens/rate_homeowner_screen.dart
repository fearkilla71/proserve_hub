import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/homeowner_reliability_service.dart';

/// Screen for contractors to rate a homeowner after job completion.
/// Four categories: On-time access, Communication, Payment promptness,
/// Property condition. Plus optional comment.
class RateHomeownerScreen extends StatefulWidget {
  final String homeownerId;
  final String jobId;
  final String homeownerName;

  const RateHomeownerScreen({
    super.key,
    required this.homeownerId,
    required this.jobId,
    this.homeownerName = 'Homeowner',
  });

  @override
  State<RateHomeownerScreen> createState() => _RateHomeownerScreenState();
}

class _RateHomeownerScreenState extends State<RateHomeownerScreen> {
  int _accessOnTime = 0;
  int _communication = 0;
  int _paymentPromptness = 0;
  int _propertyCondition = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _accessOnTime > 0 &&
      _communication > 0 &&
      _paymentPromptness > 0 &&
      _propertyCondition > 0;

  double get _overallAvg =>
      (_accessOnTime +
          _communication +
          _paymentPromptness +
          _propertyCondition) /
      4.0;

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      await HomeownerReliabilityService.instance.rateHomeowner(
        homeownerId: widget.homeownerId,
        jobId: widget.jobId,
        accessOnTime: _accessOnTime,
        communication: _communication,
        paymentPromptness: _paymentPromptness,
        propertyCondition: _propertyCondition,
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Homeowner')),
      body: _submitted ? _buildThankYou(scheme) : _buildForm(scheme),
    );
  }

  Widget _buildThankYou(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.thumb_up, size: 72, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              'Thanks for your feedback!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your rating helps other contractors know\nwhat to expect from this client.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primaryContainer, scheme.tertiaryContainer],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: scheme.onPrimaryContainer.withValues(
                  alpha: .1,
                ),
                child: Text(
                  widget.homeownerName.isNotEmpty
                      ? widget.homeownerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Rate ${widget.homeownerName}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Help other contractors by rating your experience.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onPrimaryContainer.withValues(alpha: .7),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Rating categories ──
        _RatingCategory(
          title: 'On-Time Access',
          subtitle: 'Was the property accessible at the agreed time?',
          icon: Icons.access_time,
          value: _accessOnTime,
          onChanged: (v) => setState(() => _accessOnTime = v),
        ),
        const SizedBox(height: 16),
        _RatingCategory(
          title: 'Communication',
          subtitle: 'Were they responsive and clear?',
          icon: Icons.chat_bubble_outline,
          value: _communication,
          onChanged: (v) => setState(() => _communication = v),
        ),
        const SizedBox(height: 16),
        _RatingCategory(
          title: 'Payment Promptness',
          subtitle: 'Did they pay on time without issues?',
          icon: Icons.payments_outlined,
          value: _paymentPromptness,
          onChanged: (v) => setState(() => _paymentPromptness = v),
        ),
        const SizedBox(height: 16),
        _RatingCategory(
          title: 'Property Condition',
          subtitle: 'Was the workspace reasonably clear and ready?',
          icon: Icons.home_outlined,
          value: _propertyCondition,
          onChanged: (v) => setState(() => _propertyCondition = v),
        ),

        // ── Overall preview ──
        if (_isValid) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _overallColor(_overallAvg).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _overallColor(_overallAvg).withValues(alpha: .3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: _overallColor(_overallAvg),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall: ${_overallAvg.toStringAsFixed(1)} / 5.0',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _overallColor(_overallAvg),
                      ),
                    ),
                    Text(
                      _overallLabel(_overallAvg),
                      style: TextStyle(
                        fontSize: 13,
                        color: _overallColor(_overallAvg),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Comment ──
        TextField(
          controller: _commentCtrl,
          decoration: InputDecoration(
            labelText: 'Additional comments (optional)',
            hintText: 'Anything else to note about this client?',
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isValid && !_submitting ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_submitting ? 'Submitting...' : 'Submit Rating'),
          ),
        ),
      ],
    );
  }

  Color _overallColor(double score) {
    if (score >= 4.5) return Colors.green;
    if (score >= 3.5) return Colors.teal;
    if (score >= 2.5) return Colors.orange;
    return Colors.red;
  }

  String _overallLabel(double score) {
    if (score >= 4.5) return 'Excellent Client';
    if (score >= 3.5) return 'Good Client';
    if (score >= 2.5) return 'Average';
    if (score >= 1.5) return 'Below Average';
    return 'Difficult';
  }
}

// ────────────────────────────────────────────────────────────
// Rating category widget
// ────────────────────────────────────────────────────────────
class _RatingCategory extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              final selected = starNum <= value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(starNum);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      selected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 36,
                      color: selected ? Colors.amber : scheme.outlineVariant,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Reliability badge widget — shown to contractors on job detail
// ────────────────────────────────────────────────────────────
class HomeownerReliabilityBadge extends StatelessWidget {
  final double score;
  final int count;

  const HomeownerReliabilityBadge({
    super.key,
    required this.score,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final color = score >= 4.5
        ? Colors.green
        : score >= 3.5
        ? Colors.teal
        : score >= 2.5
        ? Colors.orange
        : Colors.red;

    final label = score >= 4.5
        ? 'Excellent'
        : score >= 3.5
        ? 'Good'
        : score >= 2.5
        ? 'Average'
        : 'Low';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(1)} $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: .7)),
          ),
        ],
      ),
    );
  }
}
