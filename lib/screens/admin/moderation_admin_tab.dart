import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModerationAdminTab extends StatefulWidget {
  const ModerationAdminTab({super.key});

  @override
  State<ModerationAdminTab> createState() => _ModerationAdminTabState();
}

class _ModerationAdminTabState extends State<ModerationAdminTab> {
  String _filter = 'reported';
  final _date = DateFormat.MMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('community_posts')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading moderation queue: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var posts = snapshot.data!.docs.toList();
        if (_filter == 'reported') {
          posts = posts.where((doc) {
            final data = doc.data();
            return ((data['reportCount'] as num?)?.toInt() ?? 0) > 0;
          }).toList();
        } else if (_filter == 'removed') {
          posts = posts.where((doc) {
            final status = (doc.data()['moderationStatus'] ?? '').toString();
            return status == 'removed';
          }).toList();
        }

        posts.sort((a, b) {
          final ar = (a.data()['reportCount'] as num?)?.toInt() ?? 0;
          final br = (b.data()['reportCount'] as num?)?.toInt() ?? 0;
          if (ar != br) return br.compareTo(ar);
          return _millis(b.data()).compareTo(_millis(a.data()));
        });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          itemCount: posts.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) return _filterCard();
            final doc = posts[index - 1];
            return _postCard(doc.id, doc.data());
          },
        );
      },
    );
  }

  Widget _filterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community moderation',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Review reported posts, remove harmful content, restore false positives, or clear reviewed reports.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Reported'),
                  selected: _filter == 'reported',
                  onSelected: (_) => setState(() => _filter = 'reported'),
                ),
                ChoiceChip(
                  label: const Text('Removed'),
                  selected: _filter == 'removed',
                  onSelected: (_) => setState(() => _filter = 'removed'),
                ),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(String postId, Map<String, dynamic> data) {
    final scheme = Theme.of(context).colorScheme;
    final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
    final status = (data['moderationStatus'] ?? 'active').toString();
    final caption = (data['caption'] ?? '').toString().trim();
    final author = (data['authorName'] ?? 'Unknown author').toString();
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final mediaUrls = (data['mediaUrls'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: reportCount > 0
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  child: Icon(
                    reportCount > 0
                        ? Icons.flag_outlined
                        : Icons.forum_outlined,
                    color: reportCount > 0
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        [
                          'Post $postId',
                          if (createdAt != null) _date.format(createdAt),
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('$reportCount reports'),
                  backgroundColor: reportCount > 0
                      ? scheme.errorContainer
                      : scheme.surfaceContainerHighest,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              caption.isEmpty ? 'No caption' : caption,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${mediaUrls.length} media attachment${mediaUrls.length == 1 ? '' : 's'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    status == 'removed'
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(status),
                  visualDensity: VisualDensity.compact,
                ),
                OutlinedButton.icon(
                  onPressed: () => _updatePost(
                    postId,
                    status == 'removed' ? 'active' : 'removed',
                  ),
                  icon: Icon(
                    status == 'removed'
                        ? Icons.restore_outlined
                        : Icons.block_outlined,
                  ),
                  label: Text(status == 'removed' ? 'Restore' : 'Remove'),
                ),
                OutlinedButton.icon(
                  onPressed: reportCount == 0
                      ? null
                      : () => _clearReports(postId),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark reviewed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePost(String postId, String status) async {
    await FirebaseFirestore.instance
        .collection('community_posts')
        .doc(postId)
        .set({
          'moderationStatus': status,
          'moderationUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Post marked $status.')));
  }

  Future<void> _clearReports(String postId) async {
    await FirebaseFirestore.instance
        .collection('community_posts')
        .doc(postId)
        .set({
          'reportCount': 0,
          'reportsReviewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reports marked reviewed.')));
  }

  static int _millis(Map<String, dynamic> data) {
    final raw = data['lastReportedAt'] ?? data['createdAt'];
    if (raw is Timestamp) return raw.millisecondsSinceEpoch;
    return 0;
  }
}
