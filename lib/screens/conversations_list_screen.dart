import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/marketplace_models.dart';
import '../widgets/skeleton.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();
  late TabController _tabController;

  // Quick-reply templates
  static const _quickReplies = [
    'On my way!',
    'I\'ll get back to you shortly.',
    'Sounds good, let\'s proceed.',
    'Can we schedule a call?',
    'Thanks for the update!',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: Text('Please sign in to view messages')),
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              )
            : const Text('Inbox'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            tooltip: 'Mark all read',
            onPressed: () => _markAllRead(user.uid),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
            Tab(text: 'Jobs'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participantIds', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              itemCount: 8,
              itemBuilder: (context, index) {
                return const SkeletonListTile(showSubtitle: true);
              },
            );
          }

          final convoDocs = snapshot.data?.docs ?? [];
          var conversations = convoDocs.map(Conversation.fromFirestore).toList()
            ..sort((a, b) {
              final aTime =
                  a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

          // Total unread badge
          int totalUnread = 0;
          for (final c in conversations) {
            totalUnread += c.unreadCount[user.uid] ?? 0;
          }

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            conversations = conversations.where((c) {
              final names = c.participantNames.values.join(' ').toLowerCase();
              if (names.contains(q)) return true;
              final msg = (c.lastMessage ?? '').toLowerCase();
              if (msg.contains(q)) return true;
              return false;
            }).toList();
          }

          // Apply tab filter
          final tabIndex = _tabController.index;
          List<Conversation> filtered;
          if (tabIndex == 1) {
            // Unread only
            filtered = conversations
                .where((c) => (c.unreadCount[user.uid] ?? 0) > 0)
                .toList();
          } else if (tabIndex == 2) {
            // Job-related — has jobId
            filtered = conversations.where((c) => c.jobId != null).toList();
          } else {
            filtered = conversations;
          }

          return Column(
            children: [
              // Unread summary bar
              if (totalUnread > 0 && tabIndex == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: scheme.primaryContainer.withValues(alpha: .4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_email_unread,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalUnread unread message${totalUnread > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey.withValues(alpha: .5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tabIndex == 1
                                  ? 'All caught up!'
                                  : tabIndex == 2
                                  ? 'No job conversations'
                                  : 'No conversations yet',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start chatting with contractors about your jobs',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _ConversationTile(
                            conversation: filtered[index],
                            userId: user.uid,
                            quickReplies: _quickReplies,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _markAllRead(String uid) async {
    HapticFeedback.mediumImpact();
    final snap = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'unreadCount.$uid': 0});
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All marked as read')));
    }
  }
}

/// Enhanced conversation tile with swipe quick-reply.
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String userId;
  final List<String> quickReplies;

  const _ConversationTile({
    required this.conversation,
    required this.userId,
    required this.quickReplies,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final otherParticipantId = conversation.participantIds.firstWhere(
      (id) => id != userId,
      orElse: () => '',
    );
    final otherName =
        conversation.participantNames[otherParticipantId] ?? 'Unknown';
    final unread = conversation.unreadCount[userId] ?? 0;
    final jobId = conversation.jobId;
    final jobTitle = jobId != null ? 'Job' : null;

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        // Show quick-reply sheet instead of dismissing
        _showQuickReplySheet(context, conversation.id);
        return false;
      },
      background: Container(
        color: scheme.tertiaryContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, color: scheme.onTertiaryContainer),
            Text(
              'Quick Reply',
              style: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer),
            ),
          ],
        ),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(child: Text(otherName[0].toUpperCase())),
            if (unread > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherName,
                style: TextStyle(
                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (jobId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  jobTitle ?? 'Job',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          conversation.lastMessage ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (conversation.lastMessageTime != null)
              Text(
                _formatTime(conversation.lastMessageTime!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (unread > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          context.push(
            '/chat/${conversation.id}',
            extra: {
              'otherUserId': otherParticipantId,
              'otherUserName': otherName,
            },
          );
        },
      ),
    );
  }

  void _showQuickReplySheet(BuildContext context, String conversationId) {
    final replyCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Reply',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: quickReplies.map((r) {
                  return ActionChip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendQuickReply(context, conversationId, r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = replyCtrl.text.trim();
                      if (text.isEmpty) return;
                      Navigator.pop(ctx);
                      _sendQuickReply(context, conversationId, text);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendQuickReply(
    BuildContext context,
    String conversationId,
    String text,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': userId,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'text',
          });
      // Update conversation lastMessage
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': userId,
          });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reply sent')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return DateFormat.jm().format(time);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(time);
    return DateFormat.MMMd().format(time);
  }
}
