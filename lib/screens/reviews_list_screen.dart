import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/marketplace_models.dart';

class ReviewsListScreen extends StatefulWidget {
  final String contractorId;

  const ReviewsListScreen({super.key, required this.contractorId});

  @override
  State<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends State<ReviewsListScreen> {
  String _sortBy = 'recent'; // recent, highest, lowest

  static const int _pageSize = 25;
  DocumentSnapshot? _oldestLoadedReviewDoc;
  final List<Review> _olderReviews = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  Query _reviewsQueryBase() {
    Query query = FirebaseFirestore.instance
        .collection('reviews')
        .where('contractorId', isEqualTo: widget.contractorId);

    switch (_sortBy) {
      case 'recent':
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'highest':
        query = query.orderBy('rating', descending: true);
        break;
      case 'lowest':
        query = query.orderBy('rating', descending: false);
        break;
    }

    return query;
  }

  Future<void> _loadMoreReviews() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_oldestLoadedReviewDoc == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snap = await _reviewsQueryBase()
          .startAfterDocument(_oldestLoadedReviewDoc!)
          .limit(_pageSize)
          .get();

      if (snap.docs.isNotEmpty) {
        _oldestLoadedReviewDoc = snap.docs.last;
        final batch = snap.docs.map((d) => Review.fromFirestore(d)).toList();
        if (mounted) {
          setState(() {
            _olderReviews.addAll(batch);
          });
        }
      }

      if (snap.docs.length < _pageSize) {
        _hasMore = false;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _oldestLoadedReviewDoc = null;
                _olderReviews.clear();
                _isLoadingMore = false;
                _hasMore = true;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'recent', child: Text('Most Recent')),
              const PopupMenuItem(
                value: 'highest',
                child: Text('Highest Rated'),
              ),
              const PopupMenuItem(value: 'lowest', child: Text('Lowest Rated')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Rating Summary
          _buildRatingSummary(),
          const Divider(),

          // Reviews List
          Expanded(child: _buildReviewsList()),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contractors')
          .doc(widget.contractorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final avgRatingRaw = data['avgRating'] ?? data['averageRating'];
        final countRaw = data['reviewCount'] ?? data['totalReviews'];
        final avgRating = (avgRatingRaw is num) ? avgRatingRaw.toDouble() : 0.0;
        final reviewCount = (countRaw is num) ? countRaw.toInt() : 0;

        if (reviewCount <= 0) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No reviews yet'),
          );
        }

        double? avgFromSumCount(String sumKey, String countKey) {
          final sumRaw = data[sumKey];
          final countRaw = data[countKey];
          final sum = (sumRaw is num) ? sumRaw.toDouble() : 0.0;
          final count = (countRaw is num) ? countRaw.toInt() : 0;
          if (count <= 0) return null;
          return sum / count;
        }

        final avgQuality = avgFromSumCount('qualitySum', 'qualityCount');
        final avgTimeliness = avgFromSumCount(
          'timelinessSum',
          'timelinessCount',
        );
        final avgCommunication = avgFromSumCount(
          'communicationSum',
          'communicationCount',
        );

        final ratingCounts = <int, int>{};
        final countsMapRaw = data['ratingCounts'];
        final countsMap = countsMapRaw is Map
            ? countsMapRaw.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
        for (var i = 1; i <= 5; i++) {
          final v = countsMap['$i'];
          ratingCounts[i] = v is num ? v.toInt() : 0;
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Average Rating
              Column(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < avgRating.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$reviewCount reviews',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (avgQuality != null ||
                      avgTimeliness != null ||
                      avgCommunication != null) ...[
                    const SizedBox(height: 12),
                    if (avgQuality != null)
                      Text(
                        'Quality: ${avgQuality.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (avgTimeliness != null)
                      Text(
                        'Timeliness: ${avgTimeliness.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (avgCommunication != null)
                      Text(
                        'Communication: ${avgCommunication.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(width: 32),

              // Rating Distribution
              Expanded(
                child: Column(
                  children: [
                    for (var i = 5; i >= 1; i--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('$i'),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: reviewCount <= 0
                                    ? 0
                                    : (ratingCounts[i] ?? 0) / reviewCount,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '${ratingCounts[i] ?? 0}',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    Query query = _reviewsQueryBase();

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(_pageSize).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                const Text('No reviews yet', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'Be the first to leave a review!',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isNotEmpty) {
          _oldestLoadedReviewDoc ??= docs.last;
          if (docs.length < _pageSize) {
            _hasMore = false;
          }
        }

        final firstPageReviews = docs
            .map((d) => Review.fromFirestore(d))
            .toList();
        final allReviews = [...firstPageReviews, ..._olderReviews];

        final reviews = allReviews;

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reviews.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  return ReviewCard(
                    review: reviews[index],
                    contractorId: widget.contractorId,
                  );
                },
              ),
            ),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: _isLoadingMore
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _loadMoreReviews,
                          child: const Text('Load more reviews'),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ReviewCard extends StatefulWidget {
  final Review review;
  final String contractorId;

  const ReviewCard({
    super.key,
    required this.review,
    required this.contractorId,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  final _responseController = TextEditingController();
  bool _isRespondingMode = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submitResponse() async {
    final response = _responseController.text.trim();
    if (response.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.review.id)
          .update({
            'contractorResponse': response,
            'responseDate': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          _isRespondingMode = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response posted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error posting response: $e')));
      }
    }
  }

  Widget _templateChip(String text) {
    final preview = text.length > 30 ? '${text.substring(0, 30)}...' : text;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(preview, style: const TextStyle(fontSize: 12)),
        onPressed: () {
          _responseController.text = text;
          _responseController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        },
      ),
    );
  }

  bool _canRespond() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null &&
        currentUser.uid == widget.contractorId &&
        widget.review.contractorResponse == null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Info & Rating
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                widget.review.customerName.isNotEmpty
                    ? widget.review.customerName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.review.customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.review.verified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    DateFormat.yMMMd().format(widget.review.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < widget.review.rating.round()
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Comment
        Text(widget.review.comment),
        const SizedBox(height: 12),

        if (widget.review.qualityRating != null ||
            widget.review.timelinessRating != null ||
            widget.review.communicationRating != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.review.qualityRating != null)
                Chip(
                  label: Text(
                    'Quality ${widget.review.qualityRating!.toStringAsFixed(0)}/5',
                  ),
                ),
              if (widget.review.timelinessRating != null)
                Chip(
                  label: Text(
                    'Timeliness ${widget.review.timelinessRating!.toStringAsFixed(0)}/5',
                  ),
                ),
              if (widget.review.communicationRating != null)
                Chip(
                  label: Text(
                    'Communication ${widget.review.communicationRating!.toStringAsFixed(0)}/5',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Photos
        if (widget.review.photoUrls.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.review.photoUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.review.photoUrls[index],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 100,
                      height: 100,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                );
              },
            ),
          ),

        // Contractor Response
        if (widget.review.contractorResponse != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Contractor Response',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (widget.review.responseDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMd().format(widget.review.responseDate!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.review.contractorResponse!),
              ],
            ),
          ),
        ],

        // Response Input
        if (_canRespond()) ...[
          const SizedBox(height: 12),
          if (_isRespondingMode)
            Column(
              children: [
                // Quick response templates
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _templateChip('Thank you for your kind review!'),
                      _templateChip(
                        'We appreciate your feedback and look forward '
                        'to working with you again.',
                      ),
                      _templateChip(
                        'Thank you for choosing us. We value your '
                        'trust and support!',
                      ),
                      _templateChip(
                        'We\'re glad you\'re satisfied with our work. '
                        'Please don\'t hesitate to reach out anytime.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _responseController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a professional response...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _isRespondingMode = false;
                                _responseController.clear();
                              });
                            },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submitResponse,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Post Response'),
                    ),
                  ],
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isRespondingMode = true);
              },
              icon: const Icon(Icons.reply),
              label: const Text('Respond'),
            ),
        ],
      ],
    );
  }
}
