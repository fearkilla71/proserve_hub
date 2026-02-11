import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class CommunityFeedScreen extends StatefulWidget {
  final String title;

  const CommunityFeedScreen({super.key, this.title = 'Community'});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final _postsRef = FirebaseFirestore.instance.collection('community_posts');
  final _dateFormat = DateFormat.yMMMd().add_jm();
  final Map<String, bool> _likeOverrides = {};
  final Map<String, int> _likeDeltas = {};
  final Map<String, TextEditingController> _inlineCommentControllers = {};
  final Map<String, FocusNode> _inlineCommentFocusNodes = {};

  TextEditingController _commentControllerFor(String postId) {
    return _inlineCommentControllers.putIfAbsent(
      postId,
      () => TextEditingController(),
    );
  }

  FocusNode _commentFocusFor(String postId) {
    return _inlineCommentFocusNodes.putIfAbsent(postId, () => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _inlineCommentControllers.values) {
      controller.dispose();
    }
    for (final node in _inlineCommentFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _showNewPostSheet() async {
    final picker = ImagePicker();
    final captionController = TextEditingController();
    var selected = <XFile>[];
    var posting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canPost =
                captionController.text.trim().isNotEmpty || selected.isNotEmpty;

            Future<void> pickImages() async {
              try {
                final picks = await picker.pickMultiImage(imageQuality: 85);
                if (picks.isEmpty) return;
                setSheetState(() {
                  selected = picks;
                });
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Image picker failed: $e')),
                );
              }
            }

            Future<void> submit() async {
              if (posting || !canPost) return;
              setSheetState(() => posting = true);
              try {
                await _createPost(
                  caption: captionController.text.trim(),
                  images: selected,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post published.')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
              } finally {
                if (context.mounted) {
                  setSheetState(() => posting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New post',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: captionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Share a job update, before/after, or tip...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (selected.isNotEmpty)
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final file = selected[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _LocalImageThumb(file: file, size: 86),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemCount: selected.length,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: posting ? null : pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Add photos'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: posting ? null : submit,
                        icon: posting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Post'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _uploadPostImage(String postId, XFile photo) async {
    final bytes = await photo.readAsBytes();
    var uploadBytes = bytes;

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

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final storageRef = FirebaseStorage.instance.ref();
    final name = photo.name.isNotEmpty ? photo.name : 'photo.jpg';
    final path =
        'community_posts/$uid/$postId/${DateTime.now().millisecondsSinceEpoch}_$name';
    final photoRef = storageRef.child(path);
    await photoRef.putData(uploadBytes);
    return await photoRef.getDownloadURL();
  }

  Future<Map<String, String>> _resolveAuthorProfile(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? {};
      final name = (data['name'] ?? data['companyName'] ?? data['businessName'])
          ?.toString()
          .trim();
      final role = (data['role'] ?? '').toString().trim();
      return {
        'name': (name == null || name.isEmpty)
            ? (user.email ?? 'Member')
            : name,
        'role': role.isEmpty ? 'member' : role,
      };
    } catch (_) {
      return {'name': user.email ?? 'Member', 'role': 'member'};
    }
  }

  Future<void> _createPost({
    required String caption,
    required List<XFile> images,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in to post.');
    }

    final docRef = _postsRef.doc();
    final profile = await _resolveAuthorProfile(user);

    final mediaUrls = <String>[];
    for (final img in images) {
      final url = await _uploadPostImage(docRef.id, img);
      mediaUrls.add(url);
    }

    await docRef.set({
      'authorId': user.uid,
      'authorName': profile['name'],
      'authorRole': profile['role'],
      'caption': caption,
      'mediaUrls': mediaUrls,
      'likeCount': 0,
      'reportCount': 0,
      'moderationStatus': 'active',
      'lastReportedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _formatTimeAgo(Timestamp? createdAt) {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final date = createdAt.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return DateFormat.MMMd().format(date);
  }

  Future<void> _openMediaViewer(List<String> urls, int initialIndex) async {
    final pageController = PageController(initialPage: initialIndex);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                itemCount: urls.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: urls[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              if (urls.length > 1)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedBuilder(
                      animation: pageController,
                      builder: (context, _) {
                        final page = pageController.hasClients
                            ? (pageController.page ??
                                  pageController.initialPage)
                            : pageController.initialPage;
                        final index = page.round() + 1;
                        return Text(
                          '$index / ${urls.length}',
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _createCommentFromText(String postId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required to comment.')),
      );
      return false;
    }

    try {
      final profile = await _resolveAuthorProfile(user);
      await _postsRef.doc(postId).collection('comments').add({
        'authorId': user.uid,
        'authorName': profile['name'],
        'authorRole': profile['role'],
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      return false;
    }
  }

  Future<void> _toggleLike(String postId, bool currentlyLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    HapticFeedback.selectionClick();
    final delta = currentlyLiked ? -1 : 1;
    setState(() {
      _likeOverrides[postId] = !currentlyLiked;
      _likeDeltas[postId] = (_likeDeltas[postId] ?? 0) + delta;
    });

    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final likeSnap = await tx.get(likeRef);
        if (likeSnap.exists) {
          tx.delete(likeRef);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(likeRef, {
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });

      setState(() {
        _likeOverrides.remove(postId);
        _likeDeltas.remove(postId);
      });
    } catch (e) {
      setState(() {
        _likeOverrides.remove(postId);
        _likeDeltas.remove(postId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
    }
  }

  Future<void> _reportPost(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required to report.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    // Prevent duplicate reports from the same user.
    final existing = await _postsRef
        .doc(postId)
        .collection('reports')
        .where('authorId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('You have already reported this post.')),
      );
      return;
    }

    final result = await showDialog<_ReportResult>(
      context: context,
      builder: (context) => const _ReportDialog(),
    );

    if (result == null) return;
    final selected = result.reason;
    final details = result.details;

    final reportRef = _postsRef.doc(postId).collection('reports').doc();
    await reportRef.set({
      'authorId': user.uid,
      'reason': selected,
      'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _postsRef.doc(postId).update({
      'reportCount': FieldValue.increment(1),
      'lastReportedAt': FieldValue.serverTimestamp(),
    });

    // Auto-hide posts that reach the report threshold.
    final postDoc = await _postsRef.doc(postId).get();
    final count = (postDoc.data()?['reportCount'] as num?)?.toInt() ?? 0;
    if (count >= 3) {
      await _postsRef.doc(postId).update({'moderationStatus': 'hidden'});
    }

    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Report submitted.')));
  }

  Future<void> _setModerationStatus(String postId, String status) async {
    await _postsRef.doc(postId).update({'moderationStatus': status});
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will remove the post and comments.'),
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
    if (!mounted || confirmed != true) return;

    try {
      await _postsRef.doc(postId).delete();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post removed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $e')));
    }
  }

  Future<void> _showAdminReview() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _postsRef
                .where('reportCount', isGreaterThan: 0)
                .orderBy('reportCount', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No reported posts right now.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final author = (data['authorName'] ?? 'Member').toString();
                  final caption = (data['caption'] ?? '').toString();
                  final reportCount =
                      (data['reportCount'] as num?)?.toInt() ?? 0;
                  final status = (data['moderationStatus'] ?? 'active')
                      .toString();

                  return ListTile(
                    title: Text(author),
                    subtitle: Text(
                      caption.isEmpty ? '(no caption)' : caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Text('Reports: $reportCount'),
                        TextButton(
                          onPressed: () =>
                              _setModerationStatus(doc.id, 'removed'),
                          child: const Text('Hide'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _setModerationStatus(doc.id, 'active'),
                          child: const Text('Restore'),
                        ),
                        if (status != 'active')
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('($status)'),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteComment(String postId, String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
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
    if (!mounted || confirmed != true) return;

    try {
      await _postsRef
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete comment: $e')));
    }
  }

  Widget _buildMedia(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => _openMediaViewer(urls, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: urls.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openMediaViewer(urls, index),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: urls[index],
                      width: 240,
                      height: 180,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}/${urls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemCount: urls.length,
      ),
    );
  }

  Widget _buildComments(String postId) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _postsRef
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Text(
            'No comments yet. Be the first to comment.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }

        final ordered = docs.toList().reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ordered.map((doc) {
            final data = doc.data();
            final name = (data['authorName'] ?? 'Member').toString();
            final text = (data['text'] ?? '').toString();
            final authorId = (data['authorId'] ?? '').toString();
            final canDelete = currentUid != null && authorId == currentUid;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            text,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'Delete comment',
                        onPressed: () => _deleteComment(postId, doc.id),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInlineCommentComposer(String postId) {
    final controller = _commentControllerFor(postId);
    final focusNode = _commentFocusFor(postId);
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> submit() async {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      controller.clear();
      focusNode.unfocus();
      HapticFeedback.selectionClick();
      await _createCommentFromText(postId, text);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onSubmitted: (_) => submit(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 18),
            color: colorScheme.primary,
            onPressed: submit,
            tooltip: 'Post comment',
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isAdmin,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final data = doc.data() ?? {};
    final author = (data['authorName'] ?? 'Member').toString();
    final role = (data['authorRole'] ?? '').toString();
    final authorId = (data['authorId'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final moderationStatus = (data['moderationStatus'] ?? 'active').toString();
    final isAuthor = currentUid != null && authorId == currentUid;
    final urlsRaw = data['mediaUrls'];
    final urls = urlsRaw is List
        ? urlsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final baseLikeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final likeCount = baseLikeCount + (_likeDeltas[doc.id] ?? 0);
    final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
    final createdAt = data['createdAt'];
    final timestamp = createdAt is Timestamp
        ? _dateFormat.format(createdAt.toDate())
        : '';
    final timeAgo = createdAt is Timestamp ? _formatTimeAgo(createdAt) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Text(
                    author.isNotEmpty ? author[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (role.isNotEmpty ||
                          timestamp.isNotEmpty ||
                          (isAdmin && moderationStatus != 'active'))
                        Text(
                          [
                            if (role.isNotEmpty) role,
                            if (timestamp.isNotEmpty) timestamp,
                            if (isAdmin && moderationStatus != 'active')
                              moderationStatus,
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeAgo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'report') {
                      _reportPost(doc.id);
                    }
                    if (value == 'delete') {
                      _deletePost(doc.id);
                    }
                    if (value == 'hide') {
                      _setModerationStatus(doc.id, 'removed');
                    }
                    if (value == 'restore') {
                      _setModerationStatus(doc.id, 'active');
                    }
                  },
                  itemBuilder: (context) {
                    return <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report'),
                      ),
                      if (isAuthor)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete post'),
                        ),
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'hide',
                          child: Text('Hide post'),
                        ),
                      if (isAdmin)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore post'),
                        ),
                    ];
                  },
                ),
              ],
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(caption, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (urls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMedia(urls),
            ],
            const SizedBox(height: 12),
            _buildComments(doc.id),
            const SizedBox(height: 10),
            _buildInlineCommentComposer(doc.id),
            const SizedBox(height: 6),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _postsRef
                  .doc(doc.id)
                  .collection('likes')
                  .doc(FirebaseAuth.instance.currentUser?.uid ?? 'missing')
                  .snapshots(),
              builder: (context, likeSnap) {
                final serverLiked = likeSnap.data?.exists == true;
                final override = _likeOverrides[doc.id];
                final isLiked = override ?? serverLiked;
                final focusNode = _commentFocusFor(doc.id);

                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _toggleLike(doc.id, isLiked),
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isLiked ? colorScheme.error : null,
                      ),
                      label: Text('$likeCount'),
                    ),
                    TextButton.icon(
                      onPressed: () => focusNode.requestFocus(),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Comment'),
                    ),
                    if (reportCount > 0)
                      Text(
                        '$reportCount reports',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final adminStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: adminStream,
      builder: (context, adminSnap) {
        final isAdmin = adminSnap.data?.exists == true;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Share wins, tips, and project updates.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: _showAdminReview,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Review reports'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _showNewPostSheet,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('New Post'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: isAdmin
                  ? _postsRef
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots()
                  : _postsRef
                        .where('moderationStatus', isEqualTo: 'active')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('Community feed error: ${snap.error}');
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Could not load community posts.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snap.error}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snap.data!.docs.where((doc) {
                  final data = doc.data();
                  final status = (data['moderationStatus'] ?? 'active')
                      .toString();
                  // Non-admins see only 'active' (server-side filtered).
                  // Admins see all statuses in-app.
                  return isAdmin || status == 'active';
                }).toList();

                if (docs.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Start the conversation',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Share a before/after, a win, or a quick tip to help the community.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _showNewPostSheet,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Start a post'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: docs
                      .map((doc) => _buildPostCard(doc, isAdmin: isAdmin))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _LocalImageThumb extends StatelessWidget {
  final XFile file;
  final double size;

  const _LocalImageThumb({required this.file, required this.size});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || !snap.hasData) {
          return Container(
            width: size,
            height: size,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Image.memory(
          snap.data!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _ReportResult {
  final String reason;
  final String details;

  const _ReportResult({required this.reason, required this.details});
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const _reasons = [
    'Spam',
    'Offensive content',
    'Harassment',
    'Scam or fraud',
    'Other',
  ];

  final TextEditingController _detailsController = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: (value) => setState(() => _selectedReason = value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _reasons
                  .map(
                    (reason) => RadioListTile<String>(
                      dense: true,
                      title: Text(reason),
                      value: reason,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsController,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedReason == null
              ? null
              : () => Navigator.pop(
                  context,
                  _ReportResult(
                    reason: _selectedReason!,
                    details: _detailsController.text.trim(),
                  ),
                ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
