import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../l10n/app_localizations.dart';
import '../models/marketplace_models.dart';
import '../utils/profanity_filter.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: List.generate(5, (i) {
              final starValue = (i + 1).toDouble();
              final filled = value >= starValue;
              return Semantics(
                label: l10n.reviewCategoryRatingSemantics(label, i + 1),
                selected: filled,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: _isSubmitting ? null : () => onChanged(starValue),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? Colors.amber.shade700 : scheme.outline,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorPickingPhotos('$e'))));
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
    final l10n = AppLocalizations.of(context)!;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewSignInRequired)));
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
        throw Exception(l10n.jobNotFoundTitle);
      }

      final requesterUid = (jobData['requesterUid'] as String?)?.trim() ?? '';
      if (requesterUid.isEmpty || requesterUid != user.uid) {
        throw Exception(l10n.onlyRequestingCustomerCanReview);
      }

      final status = (jobData['status'] as String?)?.trim().toLowerCase() ?? '';
      if (status != 'completed') {
        throw Exception(l10n.reviewOnlyAfterCompleted);
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
        throw Exception(l10n.reviewAlreadySubmittedForJob);
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
          SnackBar(content: Text(l10n.reviewSubmittedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorSubmittingReview(message))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final overall = ((_quality + _timeliness + _communication) / 3.0);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.writeReviewTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.verifiedReviewTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(l10n.verifiedReviewSubtitle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.rateYourExperience,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _categoryRatingRow(
                  context,
                  label: l10n.quality,
                  value: _quality,
                  onChanged: (v) => setState(() => _quality = v),
                ),
                _categoryRatingRow(
                  context,
                  label: l10n.timeliness,
                  value: _timeliness,
                  onChanged: (v) => setState(() => _timeliness = v),
                ),
                _categoryRatingRow(
                  context,
                  label: l10n.communication,
                  value: _communication,
                  onChanged: (v) => setState(() => _communication = v),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        l10n.overallRatingValue(overall.toStringAsFixed(1)),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.shareYourExperience,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commentController,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.reviewExperienceHint,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.reviewCommentRequired;
                    }
                    if (value.trim().length < 20) {
                      return l10n.reviewCommentTooShort;
                    }
                    if (ProfanityFilter.containsProfanity(value)) {
                      return l10n.reviewRemoveInappropriateLanguage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.addPhotosOptional,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.reviewPhotosSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
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
                                semanticLabel: l10n.reviewPhotoSemantics(i + 1),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Tooltip(
                                message: l10n.removePhoto,
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
                    label: Text(l10n.addPhotosCount(_selectedPhotos.length)),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitReview,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rate_review_outlined),
                    label: Text(
                      _isSubmitting ? l10n.submitting : l10n.submitReview,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
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
                            Text(
                              l10n.reviewTips,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.reviewTipSpecific),
                        Text(l10n.reviewTipProfessionalism),
                        Text(l10n.reviewTipPhotos),
                        Text(l10n.reviewTipHonest),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _getRatingLabel removed: UI now shows category averages.
}
