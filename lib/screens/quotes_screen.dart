import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../utils/bottom_sheet_helper.dart';
import '../utils/optimistic_ui.dart';

class QuotesScreen extends StatefulWidget {
  final String jobId;

  const QuotesScreen({super.key, required this.jobId});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Quotes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quotes')
            .where('jobId', isEqualTo: widget.jobId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final quotes = snapshot.data!.docs.toList()
            ..sort((a, b) {
              Timestamp ts(dynamic v) {
                if (v is Timestamp) return v;
                return Timestamp(0, 0);
              }

              final aData = a.data() as Map<String, dynamic>?;
              final bData = b.data() as Map<String, dynamic>?;
              final aTs = ts(aData?['submittedAt']);
              final bTs = ts(bData?['submittedAt']);
              return aTs.compareTo(bTs); // ascending
            });

          if (quotes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No quotes yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contractors will submit quotes for your job request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720 ? 2 : 1;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: crossAxisCount == 1 ? 1.25 : 1.35,
                ),
                itemCount: quotes.length,
                itemBuilder: (context, index) {
                  final quoteDoc = quotes[index];
                  final quote = quoteDoc.data() as Map<String, dynamic>;
                  return _buildQuoteCard(quoteDoc.id, quote);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuoteCard(String quoteId, Map<String, dynamic> quote) {
    final contractorId = quote['contractorId'] as String;
    final price = (quote['price'] as num).toDouble();
    final estimatedDuration = quote['estimatedDuration'] as String?;
    final notes = quote['notes'] as String?;
    final pricingMode = (quote['pricingMode'] as String?)?.trim() ?? 'manual';
    final adjustmentExplanation =
        (quote['aiAdjustmentExplanation'] as String?)?.trim() ?? '';
    final submittedAt = quote['submittedAt'] as Timestamp?;
    final status = quote['status'] as String? ?? 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contractor Info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('contractors')
                  .doc(contractorId)
                  .get(),
              builder: (context, contractorSnap) {
                if (!contractorSnap.hasData) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final contractor =
                    contractorSnap.data!.data() as Map<String, dynamic>?;
                final name = contractor?['name'] ?? 'Unknown Contractor';
                final rating =
                    (contractor?['averageRating'] as num?)?.toDouble() ??
                    (contractor?['avgRating'] as num?)?.toDouble() ??
                    0.0;
                final reviewCount =
                    contractor?['reviewCount'] as int? ??
                    contractor?['totalReviews'] as int? ??
                    0;
                final completedJobs =
                    (contractor?['completedJobs'] as num?)?.toInt() ?? 0;
                final profileImageUrl =
                    contractor?['profileImageUrl'] as String?;

                return Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: profileImageUrl != null
                          ? CachedNetworkImageProvider(profileImageUrl)
                          : null,
                      child: profileImageUrl == null
                          ? Text(
                              name.toString().isNotEmpty
                                  ? name.toString()[0].toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${rating.toStringAsFixed(1)} ($reviewCount)',
                                  ),
                                ],
                              ),
                              Text('$completedJobs completed'),
                              Text(
                                'ETA: ${estimatedDuration?.trim().isNotEmpty == true ? estimatedDuration!.trim() : '—'}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Price', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (pricingMode != 'manual') ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (pricingMode == 'ai_accept')
                    const Chip(
                      avatar: Icon(Icons.auto_awesome, size: 16),
                      label: Text('AI price'),
                    )
                  else if (pricingMode == 'ai_adjust')
                    const Chip(
                      avatar: Icon(Icons.tune, size: 16),
                      label: Text('Adjusted from AI'),
                    ),
                ],
              ),
            ],

            if (pricingMode == 'ai_adjust' &&
                adjustmentExplanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Adjustment',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(adjustmentExplanation),
            ],

            if (notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(notes.trim()),
            ],

            if (submittedAt != null) ...[
              const Spacer(),
              Text(
                'Submitted ${DateFormat.yMMMd().add_jm().format(submittedAt.toDate())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              const Spacer(),
            ],

            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineQuote(quoteId),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _acceptQuote(quoteId, quote),
                      child: const Text('Accept Quote'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'accepted':
        color = Colors.green;
        label = 'Accepted';
        break;
      case 'declined':
        color = Colors.red;
        label = 'Declined';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
    );
  }

  Future<void> _acceptQuote(String quoteId, Map<String, dynamic> quote) async {
    final contractorId = quote['contractorId'] as String;
    final price = (quote['price'] as num).toDouble();

    // Show confirmation bottom sheet
    final confirmed = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Accept Quote',
      message:
          'Accept this quote for \$${price.toStringAsFixed(0)}? The contractor will be assigned to your job.',
      confirmText: 'Accept',
    );

    if (!confirmed || !mounted) return;

    await OptimisticUI.executeWithOptimism(
      context: context,
      action: () async {
        // Update quote status
        await FirebaseFirestore.instance
            .collection('quotes')
            .doc(quoteId)
            .update({
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });

        // Decline other quotes
        final otherQuotes = await FirebaseFirestore.instance
            .collection('quotes')
            .where('jobId', isEqualTo: widget.jobId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in otherQuotes.docs) {
          if (doc.id != quoteId) {
            await doc.reference.update({'status': 'declined'});
          }
        }

        // Update job request
        await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .update({
              'claimed': true,
              'contractorId': contractorId,
              'claimedBy': contractorId,
              'price': price,
              'status': 'accepted',
              'claimedAt': FieldValue.serverTimestamp(),
              'acceptedQuoteId': quoteId,
              'quoteAcceptedAt': FieldValue.serverTimestamp(),
            });
      },
      loadingMessage: 'Accepting quote...',
      successMessage: 'Quote accepted! Job assigned.',
      onSuccess: () {
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _declineQuote(String quoteId) async {
    try {
      await FirebaseFirestore.instance.collection('quotes').doc(quoteId).update(
        {'status': 'declined', 'declinedAt': FieldValue.serverTimestamp()},
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quote declined')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error declining quote: $e')));
      }
    }
  }
}

class SubmitQuoteScreen extends StatefulWidget {
  final String jobId;

  const SubmitQuoteScreen({super.key, required this.jobId});

  @override
  State<SubmitQuoteScreen> createState() => _SubmitQuoteScreenState();
}

class _SubmitQuoteScreenState extends State<SubmitQuoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  final _aiExplainController = TextEditingController();
  bool _loadingAiEstimate = false;
  String _pricingMode = 'manual'; // manual | ai_accept | ai_adjust

  bool _isSubmitting = false;

  @override
  void dispose() {
    _priceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    _aiExplainController.dispose();
    super.dispose();
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Map<String, dynamic>? _readAiEstimateFromJob(Map<String, dynamic>? job) {
    final raw = job?['aiEstimate'];
    if (raw is Map) return raw.cast<String, dynamic>();
    return null;
  }

  Future<void> _generateAiEstimate() async {
    if (_loadingAiEstimate) return;

    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in first.')),
      );
      return;
    }

    setState(() => _loadingAiEstimate = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('estimateJob');
      await callable.call({'jobId': widget.jobId});

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('AI estimate updated.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'AI estimate failed.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('AI estimate failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingAiEstimate = false);
    }
  }

  Future<void> _submitQuote() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      Map<String, dynamic>? aiEstimate;
      if (_pricingMode != 'manual') {
        final jobSnap = await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .get();
        aiEstimate = _readAiEstimateFromJob(jobSnap.data());
        if (aiEstimate == null) {
          throw Exception('AI estimate is not available yet.');
        }
      }

      if (_pricingMode == 'ai_adjust' &&
          _aiExplainController.text.trim().isEmpty) {
        throw Exception('Please explain why you adjusted the AI price.');
      }

      // Check if already submitted
      final existing = await FirebaseFirestore.instance
          .collection('quotes')
          .where('jobId', isEqualTo: widget.jobId)
          .where('contractorId', isEqualTo: user.uid)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already submitted a quote for this job'),
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('quotes').add({
        'jobId': widget.jobId,
        'contractorId': user.uid,
        'price': double.parse(_priceController.text),
        'estimatedDuration': _durationController.text.trim(),
        'notes': _notesController.text.trim(),
        'pricingMode': _pricingMode,
        if (aiEstimate != null) 'aiEstimateSnapshot': aiEstimate,
        if (_pricingMode == 'ai_adjust')
          'aiAdjustmentExplanation': _aiExplainController.text.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Update job with quote count
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .update({
            'quoteCount': FieldValue.increment(1),
            'lastQuoteAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting quote: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Quote')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Provide Your Quote',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Submit a competitive quote to win this job',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('job_requests')
                  .doc(widget.jobId)
                  .snapshots(),
              builder: (context, jobSnap) {
                final job = jobSnap.data?.data();
                final ai = _readAiEstimateFromJob(job);

                final prices =
                    (ai?['prices'] as Map?)?.cast<String, dynamic>() ?? {};
                final low = _asDouble(prices['low']);
                final rec = _asDouble(prices['recommended']);
                final high = _asDouble(prices['premium']);
                final conf = _asDouble(ai?['confidence']);
                final unit = (ai?['unit'] ?? '').toString();
                final qty = _asDouble(ai?['quantity']);
                final aiNotes = (ai?['notes'] ?? '').toString().trim();

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'AI estimate',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _loadingAiEstimate
                                  ? null
                                  : _generateAiEstimate,
                              child: Text(
                                _loadingAiEstimate
                                    ? 'Generating…'
                                    : (ai == null ? 'Generate' : 'Refresh'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (ai == null)
                          Text(
                            'No AI estimate yet. Generate one to quickly price this job using a range and confidence score.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        else ...[
                          Text(
                            'Estimated range: \$${low.toStringAsFixed(0)} – \$${high.toStringAsFixed(0)}',
                          ),
                          Text('Suggested price: \$${rec.toStringAsFixed(0)}'),
                          const SizedBox(height: 6),
                          Text(
                            'Confidence: ${(conf * 100).toStringAsFixed(0)}%',
                          ),
                          if (qty > 0)
                            Text(
                              'Assumed: ${qty.toStringAsFixed(0)} ${unit.isEmpty ? "units" : unit}',
                            ),
                          if (aiNotes.isNotEmpty) Text('Notes: $aiNotes'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _pricingMode = 'ai_accept';
                                      _aiExplainController.clear();
                                      _priceController.text = rec
                                          .toStringAsFixed(0);
                                    });
                                  },
                                  child: const Text('Accept AI price'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _pricingMode = 'ai_adjust';
                                      if (_priceController.text
                                          .trim()
                                          .isEmpty) {
                                        _priceController.text = rec
                                            .toStringAsFixed(0);
                                      }
                                    });
                                  },
                                  child: const Text('Adjust & explain'),
                                ),
                              ),
                            ],
                          ),
                          if (_pricingMode == 'ai_adjust') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _aiExplainController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Why are you adjusting the AI price? *',
                                hintText:
                                    'E.g., materials quality, access difficulty, extra prep work...',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (_pricingMode != 'ai_adjust') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please add a brief explanation';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price *',
                hintText: '0.00',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                helperText: 'Your quoted price for this job',
              ),
              keyboardType: TextInputType.number,
              readOnly: _pricingMode == 'ai_accept',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Price must be greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Estimated Duration',
                hintText: '2-3 hours',
                border: OutlineInputBorder(),
                helperText: 'How long will it take? (optional)',
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Tell the customer about your approach...',
                border: OutlineInputBorder(),
                helperText: 'Materials, approach, guarantees, etc. (optional)',
              ),
              maxLines: 5,
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSubmitting ? null : _submitQuote,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Quote'),
            ),

            const SizedBox(height: 16),

            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tips for winning quotes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Price competitively\n'
                      '• Provide detailed estimates\n'
                      '• Respond quickly\n'
                      '• Highlight your experience\n'
                      '• Offer guarantees or warranties',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
