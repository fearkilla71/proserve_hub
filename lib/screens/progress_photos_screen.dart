import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class ProgressPhotosScreen extends StatefulWidget {
  final String jobId;
  final bool canUpload;

  const ProgressPhotosScreen({
    super.key,
    required this.jobId,
    this.canUpload = false,
  });

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      // Compress image
      Uint8List imageData = await image.readAsBytes();
      if (imageData.length > 1024 * 1024) {
        // Compress if > 1MB
        final result = await FlutterImageCompress.compressWithList(
          imageData,
          minWidth: 1920,
          minHeight: 1920,
          quality: 70,
        );
        imageData = Uint8List.fromList(result);
      }

      // Upload to Storage
      final photoId = FirebaseFirestore.instance.collection('_').doc().id;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('progress_photos')
          .child(widget.jobId)
          .child('$photoId.jpg');

      await storageRef.putData(imageData);
      final photoUrl = await storageRef.getDownloadURL();

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .collection('progress_photos')
          .doc(photoId)
          .set({
            'photoUrl': photoUrl,
            'uploadedBy': user.uid,
            'uploadedAt': FieldValue.serverTimestamp(),
            'caption': '',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deletePhoto(String photoId, String photoUrl) async {
    try {
      // Delete from Storage
      final ref = FirebaseStorage.instance.refFromURL(photoUrl);
      await ref.delete();

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('job_requests')
          .doc(widget.jobId)
          .collection('progress_photos')
          .doc(photoId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting photo: $e')));
      }
    }
  }

  Future<void> _updateCaption(String photoId, String currentCaption) async {
    final controller = TextEditingController(text: currentCaption);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Add a caption...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .collection('progress_photos')
            .doc(photoId)
            .update({'caption': result});

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Caption updated')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating caption: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Photos'),
        actions: [
          if (widget.canUpload) ...[
            if (_isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.add_a_photo),
                onPressed: _pickAndUploadPhoto,
              ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('job_requests')
            .doc(widget.jobId)
            .collection('progress_photos')
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final photos = snapshot.data!.docs;

          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No progress photos yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the camera icon to add photos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index].data() as Map<String, dynamic>;
              final photoId = photos[index].id;
              final photoUrl = photo['photoUrl'] as String;
              final caption = photo['caption'] as String? ?? '';
              final uploadedBy = photo['uploadedBy'] as String;
              final uploadedAt = photo['uploadedAt'] as Timestamp?;
              final currentUser = FirebaseAuth.instance.currentUser;
              final canEdit =
                  widget.canUpload && currentUser?.uid == uploadedBy;

              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showFullImage(photoUrl, caption),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                            ),
                            if (canEdit)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: PopupMenuButton(
                                  icon: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.more_vert,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'caption',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit),
                                          SizedBox(width: 8),
                                          Text('Edit Caption'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'caption') {
                                      _updateCaption(photoId, caption);
                                    } else if (value == 'delete') {
                                      _showDeleteDialog(photoId, photoUrl);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (caption.isNotEmpty)
                            Text(
                              caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          if (uploadedAt != null)
                            Text(
                              DateFormat(
                                'MMM d, h:mm a',
                              ).format(uploadedAt.toDate()),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
        },
      ),
    );
  }

  void _showFullImage(String photoUrl, String caption) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(photoUrl, fit: BoxFit.contain),
              ),
            ),
            if (caption.isNotEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(caption)),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String photoId, String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(photoId, photoUrl);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
