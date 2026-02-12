import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';

class PortfolioScreen extends StatefulWidget {
  final String? contractorId;
  final bool isEditable;

  const PortfolioScreen({
    super.key,
    this.contractorId,
    this.isEditable = false,
  });

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isUploading = false;
  List<Map<String, dynamic>> _portfolioItems = [];

  /// Subcollection reference for the contractor's portfolio.
  CollectionReference<Map<String, dynamic>> get _portfolioRef =>
      FirebaseFirestore.instance
          .collection('contractors')
          .doc(_userId)
          .collection('portfolio');

  String get _userId =>
      widget.contractorId ?? FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _portfolioRef
          .orderBy('uploadedAt', descending: true)
          .get();

      setState(() {
        _portfolioItems = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading portfolio: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      var imageData = await image.readAsBytes();

      // Compress if > 1MB
      if (imageData.length > 1024 * 1024) {
        final result = await FlutterImageCompress.compressWithList(
          imageData,
          minWidth: 1920,
          minHeight: 1920,
          quality: 75,
        );
        imageData = Uint8List.fromList(result);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance.ref().child(
        'portfolio/$_userId/$timestamp.jpg',
      );

      await storageRef.putData(imageData);
      final url = await storageRef.getDownloadURL();

      if (!mounted) return;

      // Show dialog for title and description
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _AddPhotoDialog(),
      );

      if (result != null) {
        final newItem = {
          'url': url,
          'title': result['title'] ?? '',
          'description': result['description'] ?? '',
          'type': 'image',
          'uploadedAt': FieldValue.serverTimestamp(),
        };

        await _portfolioRef.add(newItem);

        await _loadPortfolio();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo added to portfolio!')),
          );
        }
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

  void _showAddMediaSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Add Photo'),
              subtitle: const Text('Upload an image from your gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Add Video'),
              subtitle: const Text('Upload a short video (max 60 s)'),
              onTap: () {
                Navigator.pop(ctx);
                _addVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );

    if (video == null) return;

    setState(() => _isUploading = true);

    try {
      final videoData = await video.readAsBytes();

      // Reject files larger than 50 MB.
      if (videoData.length > 50 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video too large. Please keep it under 50 MB.'),
            ),
          );
        }
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = video.name.split('.').last;
      final storageRef = FirebaseStorage.instance.ref().child(
        'portfolio/$_userId/$timestamp.$ext',
      );

      await storageRef.putData(
        videoData,
        SettableMetadata(contentType: 'video/$ext'),
      );
      final url = await storageRef.getDownloadURL();

      if (!mounted) return;

      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _AddPhotoDialog(isVideo: true),
      );

      if (result != null) {
        final newItem = {
          'url': url,
          'title': result['title'] ?? '',
          'description': result['description'] ?? '',
          'type': 'video',
          'uploadedAt': FieldValue.serverTimestamp(),
        };

        await _portfolioRef.add(newItem);
        await _loadPortfolio();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video added to portfolio!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading video: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> item) async {
    final isVideo = item['type'] == 'video';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${isVideo ? 'Video' : 'Photo'}'),
        content: Text(
          'Are you sure you want to delete this ${isVideo ? 'video' : 'photo'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final docId = item['id'] as String?;
      if (docId != null) {
        await _portfolioRef.doc(docId).delete();
      }

      await _loadPortfolio();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      floatingActionButton: widget.isEditable && !_isUploading
          ? FloatingActionButton.extended(
              onPressed: _showAddMediaSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Media'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _portfolioItems.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _portfolioItems.length,
              itemBuilder: (context, index) {
                final item = _portfolioItems[index];
                return _buildPortfolioCard(item);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isEditable
                  ? 'No portfolio items yet'
                  : 'No media available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isEditable
                  ? 'Showcase your work by adding photos and videos'
                  : 'This contractor hasn\'t added any portfolio items yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.isEditable) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showAddMediaSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add First Item'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioCard(Map<String, dynamic> item) {
    final isVideo = item['type'] == 'video';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => isVideo ? _showVideoPlayer(item) : _showFullImage(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideo)
                    Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 56,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: item['url'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  if (isVideo)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'VIDEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.isEditable)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        icon: const Icon(Icons.delete),
                        iconSize: 20,
                        onPressed: () => _deletePhoto(item),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.9),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (item['title'] != null && item['title'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  item['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(
        url: item['url'] as String,
        title: item['title'] as String? ?? 'Video',
        description: item['description'] as String? ?? '',
      ),
    );
  }

  void _showFullImage(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(item['title'] ?? 'Photo'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: item['url'],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            if (item['description'] != null &&
                item['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(item['description']),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoDialog extends StatefulWidget {
  final bool isVideo;
  const _AddPhotoDialog({this.isVideo = false});

  @override
  State<_AddPhotoDialog> createState() => _AddPhotoDialogState();
}

class _AddPhotoDialogState extends State<_AddPhotoDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isVideo ? 'Video' : 'Photo';
    return AlertDialog(
      title: Text('Add $label Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Kitchen Remodel - Before',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Complete kitchen renovation...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── Video Player Dialog ────────────────────────────────────────────────

class _VideoPlayerDialog extends StatefulWidget {
  final String url;
  final String title;
  final String description;

  const _VideoPlayerDialog({
    required this.url,
    required this.title,
    required this.description,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  bool _initialised = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialised = true);
              _controller.play();
            }
          })
          .catchError((e) {
            if (mounted) setState(() => _error = e.toString());
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBar(
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading video: $_error'),
            )
          else if (!_initialised)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_controller),
                  _VideoControls(controller: _controller),
                ],
              ),
            ),
          if (widget.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.description),
            ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        return Container(
          color: Colors.black38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  value.isPlaying ? controller.pause() : controller.play();
                },
              ),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
