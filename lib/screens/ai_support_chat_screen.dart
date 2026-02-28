import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/ai_support_service.dart';
import '../theme/proserve_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Support Chat Screen
//
// A lightweight conversational support assistant powered by GPT-4o-mini.
// Persists history in Firestore and restores it when the user returns.
// ─────────────────────────────────────────────────────────────────────────────

class AiSupportChatScreen extends StatefulWidget {
  const AiSupportChatScreen({super.key});

  @override
  State<AiSupportChatScreen> createState() => _AiSupportChatScreenState();
}

class _AiSupportChatScreenState extends State<AiSupportChatScreen>
    with TickerProviderStateMixin {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  /// Full conversation history sent to the AI on each turn.
  final List<Map<String, String>> _messages = [];

  /// Display messages shown in the UI.
  final List<_ChatMessage> _displayMessages = [];

  bool _isTyping = false;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ──────────────────── History Persistence ────────────────────

  Future<void> _loadHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingHistory = false);
      _addWelcomeMessage();
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(uid)
          .collection('messages')
          .orderBy('createdAt')
          .limitToLast(40)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString();
        final content = (data['content'] ?? '').toString();
        if (role.isEmpty || content.isEmpty) continue;

        _messages.add({'role': role, 'content': content});
        _displayMessages.add(_ChatMessage(
          text: content,
          isUser: role == 'user',
          timestamp: (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('[AiSupport] Failed to load history: $e');
    }

    setState(() => _loadingHistory = false);

    if (_displayMessages.isEmpty) {
      _addWelcomeMessage();
    }

    _scrollToBottom();
  }

  void _addWelcomeMessage() {
    setState(() {
      _displayMessages.add(_ChatMessage(
        text: 'Hi! 👋 I\'m your ProServe Hub support assistant. '
            'I can help with questions about the app, your account, '
            'pricing, how to post a job, find contractors, and more.\n\n'
            'What can I help you with?',
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: const [
          'How do I post a job?',
          'How does escrow work?',
          'What are the contractor plans?',
          'I need help with my account',
        ],
      ));
    });
  }

  // ──────────────────── Conversation Logic ────────────────────

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _chatController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _chatController.clear();
    HapticFeedback.selectionClick();

    setState(() {
      _displayMessages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    _messages.add({'role': 'user', 'content': text});

    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      final reply = await AiSupportService.instance.send(_messages);

      _messages.add({'role': 'assistant', 'content': reply});

      setState(() {
        _isTyping = false;
        _displayMessages.add(_ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _displayMessages.add(_ChatMessage(
          text: 'Sorry, I had trouble connecting. Please try again in a moment.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will delete your support conversation history. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Delete Firestore messages
      final batch = FirebaseFirestore.instance.batch();
      final snap = await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(uid)
          .collection('messages')
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
        FirebaseFirestore.instance.collection('support_chats').doc(uid),
      );
      await batch.commit();
    }

    setState(() {
      _messages.clear();
      _displayMessages.clear();
    });
    _addWelcomeMessage();
  }

  // ──────────────────── Build UI ────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ProServeColors.accent2.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent,
                size: 18,
                color: ProServeColors.accent2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Support',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') _clearHistory();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Clear History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loadingHistory
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ProServeColors.accent2.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Powered by AI — available 24/7',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ProServeColors.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 11,
                          color: ProServeColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount:
                        _displayMessages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayMessages.length && _isTyping) {
                        return _buildTypingIndicator(scheme);
                      }
                      final msg = _displayMessages[index];
                      if (msg.isUser) {
                        return _buildUserBubble(msg, scheme);
                      }
                      return _buildAiBubble(msg, scheme);
                    },
                  ),
                ),

                // Input area
                _buildInputArea(scheme),
              ],
            ),
    );
  }

  // ──────────────────── Widgets ────────────────────

  Widget _buildTypingIndicator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiAvatar(scheme),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (_, value, child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity:
                            0.3 + 0.7 * ((value + i * 0.33) % 1.0),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiAvatar(ColorScheme scheme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ProServeColors.accent2, ProServeColors.accent3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.support_agent, size: 16, color: Colors.white),
    );
  }

  Widget _buildUserBubble(_ChatMessage msg, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: ProServeColors.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBubble(_ChatMessage msg, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aiAvatar(scheme),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isError
                        ? scheme.errorContainer.withValues(alpha: 0.3)
                        : scheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: SelectableText(
                    msg.text,
                    style: TextStyle(
                      color: msg.isError
                          ? scheme.error
                          : scheme.onSurface,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Quick replies
          if (msg.quickReplies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: msg.quickReplies.map((reply) {
                  return ActionChip(
                    label: Text(
                      reply,
                      style: TextStyle(
                        fontSize: 13,
                        color: ProServeColors.accent2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor:
                        ProServeColors.accent2.withValues(alpha: 0.1),
                    side: BorderSide(
                      color:
                          ProServeColors.accent2.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _sendMessage(reply),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(ColorScheme scheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Ask a question…',
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _isTyping ? null : () => _sendMessage(),
            icon: const Icon(Icons.send_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: ProServeColors.accent2,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  ProServeColors.accent2.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Display model
// ─────────────────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final List<String> quickReplies;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.quickReplies = const [],
  });
}
