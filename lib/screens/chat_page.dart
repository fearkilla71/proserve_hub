import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String jobId;

  const ChatPage({super.key, required this.jobId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  bool _readyChecked = false;
  String? _lockReason;
  bool _didClearUnread = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureChatReady() async {
    if (_readyChecked) return;
    _readyChecked = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _lockReason = 'Please sign in to chat.');
      return;
    }

    final db = FirebaseFirestore.instance;
    final jobSnap = await db.collection('job_requests').doc(widget.jobId).get();
    if (!jobSnap.exists) {
      setState(() => _lockReason = 'Job not found.');
      return;
    }

    final job = jobSnap.data() ?? <String, dynamic>{};
    final requesterUid = (job['requesterUid'] as String?)?.trim() ?? '';
    final claimed = job['claimed'] == true;
    final claimedBy = (job['claimedBy'] as String?)?.trim() ?? '';

    final isParticipant = user.uid == requesterUid || user.uid == claimedBy;

    if (!isParticipant) {
      setState(() => _lockReason = 'You are not a participant in this chat.');
      return;
    }

    if (!claimed || claimedBy.isEmpty) {
      setState(() => _lockReason = 'Chat is locked until the job is accepted.');
      return;
    }

    final chatRef = db.collection('chats').doc(widget.jobId);
    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      await chatRef.set({
        'participants': [requesterUid, claimedBy],
        'unread': {requesterUid: 0, claimedBy: 0},
      });
    }

    // Clear unread for the current user once the chat becomes available.
    if (!_didClearUnread) {
      _didClearUnread = true;
      await chatRef.set({
        'unread': {user.uid: 0},
      }, SetOptions(merge: true));
    }

    if (mounted) setState(() => _lockReason = null);
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final chatRef = db.collection('chats').doc(widget.jobId);

    final chatSnap = await chatRef.get();
    final chatData = chatSnap.data() ?? <String, dynamic>{};
    final participantsRaw = chatData['participants'];
    final participants = participantsRaw is List
        ? participantsRaw.whereType<String>().map((e) => e.trim()).toList()
        : <String>[];

    if (participants.length != 2) return;
    final receiverId = participants.firstWhere(
      (id) => id != user.uid,
      orElse: () => '',
    );
    if (receiverId.isEmpty) return;

    await db.runTransaction((tx) async {
      final messageRef = chatRef.collection('messages').doc();
      tx.set(messageRef, {
        'senderId': user.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Kick off the readiness check once.
    _ensureChatReady();

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          if (_lockReason != null)
            MaterialBanner(
              content: Text(_lockReason!),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.jobId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading chat'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userId = FirebaseAuth.instance.currentUser?.uid;
                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final senderId =
                        (data['senderId'] as String?)?.trim() ?? '';
                    final text = (data['text'] as String?)?.trim() ?? '';
                    final isMe = userId != null && senderId == userId;

                    final bubbleColor = isMe
                        ? scheme.primary
                        : scheme.surfaceContainerHighest;
                    final textColor = isMe
                        ? scheme.onPrimary
                        : scheme.onSurface;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(text, style: TextStyle(color: textColor)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _lockReason == null,
                      decoration: const InputDecoration(
                        hintText: 'Type message…',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _lockReason == null ? _sendMessage : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
