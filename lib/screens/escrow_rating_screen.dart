import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/escrow_booking.dart';
import '../services/escrow_service.dart';
import '../theme/proserve_theme.dart';

/// Post-job rating screen for price fairness feedback.
///
/// Shown after an escrow booking is released. Lets customers
/// rate how fair the AI price was (1-5 stars) and leave a comment.
class EscrowRatingScreen extends StatefulWidget {
  final String escrowId;

  const EscrowRatingScreen({super.key, required this.escrowId});

  @override
  State<EscrowRatingScreen> createState() => _EscrowRatingScreenState();
}

class _EscrowRatingScreenState extends State<EscrowRatingScreen> {
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  EscrowBooking? _booking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBooking() async {
    try {
      final snap = await EscrowService.instance
          .watchBooking(widget.escrowId)
          .first;
      if (mounted) {
        setState(() {
          _booking = snap;
          _loading = false;
          // Pre-fill if already rated
          if (snap?.hasRating == true) {
            _selectedRating = snap!.priceFairnessRating!;
            _commentCtrl.text = snap.ratingComment ?? '';
            _submitted = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      await EscrowService.instance.submitRating(
        escrowId: widget.escrowId,
        rating: _selectedRating,
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
    }
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Way Too High';
      case 2:
        return 'Slightly High';
      case 3:
        return 'Fair Price';
      case 4:
        return 'Great Deal';
      case 5:
        return 'Amazing Value!';
      default:
        return 'Tap to rate';
    }
  }

  Color _ratingColor(int rating) {
    switch (rating) {
      case 1:
        return ProServeColors.error;
      case 2:
        return ProServeColors.warning;
      case 3:
        return Colors.white70;
      case 4:
        return ProServeColors.accent2;
      case 5:
        return ProServeColors.success;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _submitted
          ? _buildThankYou(scheme)
          : _buildRatingForm(scheme),
    );
  }

  Widget _buildThankYou(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ProServeColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.thumb_up,
                color: ProServeColors.success,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thanks for Your Feedback!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your rating helps our AI learn and provide even more accurate pricing for future jobs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: ProServeColors.accent2.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: ProServeColors.accent2,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI accuracy improves with every rating',
                    style: TextStyle(
                      color: ProServeColors.accent2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingForm(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        // Job summary
        if (_booking != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.work_outline, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _booking!.service,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You paid \$${_booking!.aiPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      if (_booking!.savingsAmount != null &&
                          _booking!.savingsAmount! > 0)
                        Text(
                          'Saved \$${_booking!.savingsAmount!.toStringAsFixed(0)} vs contractors',
                          style: TextStyle(
                            color: ProServeColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],

        // Question
        Text(
          'How fair was the AI price?',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Your feedback helps improve pricing accuracy',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Star rating
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              final selected = starNum <= _selectedRating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedRating = starNum);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? _ratingColor(starNum).withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? _ratingColor(starNum).withValues(alpha: 0.4)
                          : Colors.white10,
                    ),
                  ),
                  child: Icon(
                    selected ? Icons.star : Icons.star_border,
                    color: selected ? _ratingColor(starNum) : Colors.white30,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // Rating label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _ratingLabel(_selectedRating),
            key: ValueKey(_selectedRating),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ratingColor(_selectedRating),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Comment field
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any additional feedback? (optional)',
            hintStyle: TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.primary),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _selectedRating > 0 && !_submitting
                ? _submitRating
                : null,
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(
              _submitting ? 'Submitting...' : 'Submit Rating',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),

        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}
