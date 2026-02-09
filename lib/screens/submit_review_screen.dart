import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/marketplace_models.dart';

class SubmitReviewScreen extends StatefulWidget {
  final String jobId;
  final String contractorId;

  const SubmitReviewScreen({
    super.key,
    required this.jobId,
    required this.contractorId,
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  double _quality = 5.0;
  double _timeliness = 5.0;
  double _communication = 5.0;
  final List<XFile> _selectedPhotos = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Widget _categoryRatingRow(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: value.toStringAsFixed(0),
            onChanged: _isSubmitting ? null : onChanged,
          ),
        ),
        SizedBox(width: 28, child: Text(value.toStringAsFixed(0))),
      ],
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> photos = await picker.pickMultiImage();

      if (photos.isEmpty) return;

      // Limit to 5 photos total
      final remainingSlots = 5 - _selectedPhotos.length;
      final photosToAdd = photos.take(remainingSlots).toList();

      setState(() {
        _selectedPhotos.addAll(photosToAdd);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking photos: $e')));
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<String> _uploadPhoto(XFile photo) async {
    final bytes = await photo.readAsBytes();
    var uploadBytes = bytes;

    // Compress if larger than 1MB
    if (bytes.length > 1024 * 1024) {
      final compressed = await FlutterImageCompress.compressWithList(
        Uint8List.fromList(bytes),
        minWidth: 1920,
        minHeight: 1920,
        quality: 85,
      );
      if (compressed.length < bytes.length) {
        uploadBytes = compressed;
      }
    }

    final storageRef = FirebaseStorage.instance.ref();
    final photoRef = storageRef.child(
      'review_photos/${widget.jobId}/${DateTime.now().millisecondsSinceEpoch}_${photo.name}',
    );

    await photoRef.putData(uploadBytes);
    return await photoRef.getDownloadURL();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a review')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Verify job completion and ownership
      final jobDoc = await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .get();

      final jobData = jobDoc.data();
      if (jobData == null) {
        throw Exception('Job not found');
      }

      final requesterUid = (jobData['requesterUid'] as String?)?.trim() ?? '';
      if (requesterUid.isEmpty || requesterUid != user.uid) {
        throw Exception('Only the customer who requested this job can review');
      }

      final status = (jobData['status'] as String?)?.trim().toLowerCase() ?? '';
      if (status != 'completed') {
        throw Exception('You can only review after the job is completed');
      }

      // Prevent duplicate reviews for the same job/customer
      final existing = await FirebaseFirestore.instance
          .collection('reviews')
          .where('jobId', isEqualTo: widget.jobId)
          .get();
      final alreadyReviewed = existing.docs.any((doc) {
        final data = doc.data();
        final customerId = (data['customerId'] as String?)?.trim() ?? '';
        return customerId == user.uid;
      });
      if (alreadyReviewed) {
        throw Exception('You already submitted a review for this job');
      }

      // Get user name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Anonymous';

      // Upload photos
      final photoUrls = <String>[];
      for (final photo in _selectedPhotos) {
        final url = await _uploadPhoto(photo);
        photoUrls.add(url);
      }

      final isVerified = true;

      final overall = ((_quality + _timeliness + _communication) / 3.0);

      // Create review
      final review = Review(
        id: '',
        jobId: widget.jobId,
        contractorId: widget.contractorId,
        customerId: user.uid,
        customerName: userName,
        rating: overall,
        qualityRating: _quality,
        timelinessRating: _timeliness,
        communicationRating: _communication,
        comment: _commentController.text.trim(),
        photoUrls: photoUrls,
        createdAt: DateTime.now(),
        contractorResponse: null,
        responseDate: null,
        verified: isVerified,
      );

      final reviewId = '${widget.jobId}_${user.uid}';
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(reviewId)
          .set(review.toMap());

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
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
      appBar: AppBar(title: const Text('Write a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Ratings
              const Text(
                'Rate your experience',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _categoryRatingRow(
                context,
                label: 'Quality',
                value: _quality,
                onChanged: (v) => setState(() => _quality = v),
              ),
              const SizedBox(height: 12),
              _categoryRatingRow(
                context,
                label: 'Timeliness',
                value: _timeliness,
                onChanged: (v) => setState(() => _timeliness = v),
              ),
              const SizedBox(height: 12),
              _categoryRatingRow(
                context,
                label: 'Communication',
                value: _communication,
                onChanged: (v) => setState(() => _communication = v),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Overall: ${((_quality + _timeliness + _communication) / 3.0).toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Comment Section
              const Text(
                'Share your experience',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commentController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText:
                      'Tell us about your experience with this contractor...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please write a comment';
                  }
                  if (value.trim().length < 20) {
                    return 'Comment must be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Photos Section
              const Text(
                'Add photos (optional)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Show before/after photos or highlight quality of work',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Photo Grid
              if (_selectedPhotos.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _selectedPhotos.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_selectedPhotos[i].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () => _removePhoto(i),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

              if (_selectedPhotos.length < 5) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('Add Photos (${_selectedPhotos.length}/5)'),
                ),
              ],

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Review'),
                ),
              ),

              const SizedBox(height: 16),

              // Tips Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Review Tips',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('• Be specific about quality and service'),
                      const Text('• Mention professionalism and communication'),
                      const Text('• Include before/after photos if applicable'),
                      const Text('• Be honest but constructive'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _getRatingLabel removed: UI now shows category averages.
}
