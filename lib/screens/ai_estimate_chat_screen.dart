import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../theme/proserve_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Estimate Chat Screen
//
// Conversational AI estimator — replaces the rigid step-by-step wizard with a
// natural chat experience.  The AI asks smart follow-up questions relevant to
// the selected service, then provides a price estimate with breakdown.
// ─────────────────────────────────────────────────────────────────────────────

class AiEstimateChatScreen extends StatefulWidget {
  /// The service type key (e.g. "interior_painting", "drywall_repair").
  final String serviceType;

  /// Human-readable service name (e.g. "Interior Painting").
  final String serviceName;

  const AiEstimateChatScreen({
    super.key,
    required this.serviceType,
    required this.serviceName,
  });

  @override
  State<AiEstimateChatScreen> createState() => _AiEstimateChatScreenState();
}

class _AiEstimateChatScreenState extends State<AiEstimateChatScreen>
    with TickerProviderStateMixin {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  /// Full conversation history sent to the AI on each turn.
  final List<Map<String, String>> _messages = [];

  /// Display messages (includes typing indicator, quick replies, etc.).
  final List<_ChatMessage> _displayMessages = [];

  bool _isTyping = false;
  bool _estimateReady = false;
  Map<String, dynamic>? _estimateResult;

  // Collected data from conversation
  String _zip = '';

  @override
  void initState() {
    super.initState();
    // Start the conversation
    WidgetsBinding.instance.addPostFrameCallback((_) => _startConversation());
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ──────────────────── Conversation Logic ────────────────────

  Future<void> _startConversation() async {
    // Send the initial system context to the AI and get its first question
    await _sendToAi(isInitial: true);
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _chatController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _chatController.clear();
    HapticFeedback.selectionClick();

    // Add user message to display
    setState(() {
      _displayMessages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
    });

    _scrollToBottom();

    // Add to conversation history
    _messages.add({'role': 'user', 'content': text});

    // Send to AI
    await _sendToAi();
  }

  Future<void> _sendToAi({bool isInitial = false}) async {
    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';

      // Build the request
      final payload = {
        'serviceType': widget.serviceType,
        'serviceName': widget.serviceName,
        'messages': _messages,
        'isInitial': isInitial,
      };

      Map<String, dynamic> result;
      try {
        // Try callable first
        final callable = FirebaseFunctions.instance.httpsCallable(
          'aiEstimateChat',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        );
        final response = await callable.call(payload);
        result = Map<String, dynamic>.from(response.data as Map);
      } catch (_) {
        // Fall back to HTTP
        final url = Uri.parse(
          'https://us-central1-proserve-hub-ada0e.cloudfunctions.net/aiEstimateChatHttp',
        );
        final httpResp = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (idToken.isNotEmpty) 'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(payload),
        );
        if (httpResp.statusCode != 200) {
          throw Exception('Server error: ${httpResp.statusCode}');
        }
        result = jsonDecode(httpResp.body) as Map<String, dynamic>;
      }

      final aiMessage = (result['message'] ?? '').toString();
      final quickReplies =
          (result['quickReplies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final done = result['estimateReady'] == true;
      final estimate = result['estimate'] as Map<String, dynamic>?;
      final collectedZip = (result['collectedData']?['zip'] ?? '').toString();

      if (collectedZip.isNotEmpty) _zip = collectedZip;

      // Add AI message to conversation history
      _messages.add({'role': 'assistant', 'content': aiMessage});

      setState(() {
        _isTyping = false;
        _displayMessages.add(
          _ChatMessage(
            text: aiMessage,
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: quickReplies,
          ),
        );

        if (done && estimate != null) {
          _estimateReady = true;
          _estimateResult = estimate;
        }
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _displayMessages.add(
          _ChatMessage(
            text:
                'Sorry, I had trouble connecting. Please try again in a moment.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
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

  Future<void> _acceptEstimate() async {
    if (_estimateResult == null) return;
    HapticFeedback.mediumImpact();

    // Create the job request in Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final est = _estimateResult!;
    final jobData = <String, dynamic>{
      'service': widget.serviceName,
      'serviceType': widget.serviceType,
      'requesterUid': uid,
      'zip': _zip,
      'location': _zip,
      'status': 'open',
      'claimed': false,
      'instantBook': false,
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'ai_chat_estimate',
      // Store AI-collected details
      'aiChatDetails': est['collectedDetails'] ?? {},
      'description': est['description'] ?? '',
      'quantity': est['quantity'] ?? 0,
    };

    final docRef = await FirebaseFirestore.instance
        .collection('job_requests')
        .add(jobData);

    if (!mounted) return;

    // Navigate to the AI price offer screen with the estimate data
    context.push(
      '/ai-price-offer/${docRef.id}',
      extra: {
        'service': widget.serviceName,
        'zip': _zip,
        'quantity': (est['quantity'] as num?)?.toDouble() ?? 0.0,
        'urgent': false,
        'jobDetails': est['collectedDetails'] ?? {},
      },
    );
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
                color: ProServeColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: ProServeColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI Estimator',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Service banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ProServeColors.accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.handyman, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  widget.serviceName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ProServeColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: ProServeColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Private',
                        style: TextStyle(
                          fontSize: 11,
                          color: ProServeColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _displayMessages.length + (_isTyping ? 1 : 0),
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

          // Estimate card (shown when AI is done)
          if (_estimateReady && _estimateResult != null)
            _buildEstimateCard(scheme),

          // Input area
          if (!_estimateReady) _buildInputArea(scheme),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiAvatar(scheme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
                        opacity: 0.3 + 0.7 * ((value + i * 0.33) % 1.0),
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
          colors: [ProServeColors.accent, ProServeColors.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
    );
  }

  Widget _buildUserBubble(_ChatMessage msg, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48), // Left padding for alignment
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isError ? scheme.error : scheme.onSurface,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Quick reply chips
          if (msg.quickReplies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.quickReplies.map((reply) {
                  return ActionChip(
                    label: Text(
                      reply,
                      style: TextStyle(
                        color: ProServeColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    side: BorderSide(
                      color: ProServeColors.accent.withValues(alpha: 0.3),
                    ),
                    backgroundColor: ProServeColors.accent.withValues(
                      alpha: 0.08,
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
      ),
    );
  }

  Widget _buildEstimateCard(ColorScheme scheme) {
    final est = _estimateResult!;
    final low = (est['low'] as num?)?.toDouble() ?? 0;
    final recommended = (est['recommended'] as num?)?.toDouble() ?? 0;
    final premium = (est['premium'] as num?)?.toDouble() ?? 0;
    final description = (est['description'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            ProServeColors.accent.withValues(alpha: 0.1),
            ProServeColors.accent2.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: ProServeColors.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: ProServeColors.accent),
              const SizedBox(width: 8),
              Text(
                'AI Estimate Ready',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ProServeColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _priceColumn('Budget', low, scheme),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ProServeColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '\$${recommended.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: ProServeColors.accent,
                          ),
                    ),
                    Text(
                      'Recommended',
                      style: TextStyle(
                        fontSize: 11,
                        color: ProServeColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _priceColumn('Premium', premium, scheme),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _acceptEstimate,
              icon: const Icon(Icons.bolt, size: 20),
              label: Text(
                'See Full Price & Book',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: ProServeColors.accent,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _estimateReady = false;
                  _estimateResult = null;
                });
                _sendMessage("I'd like to adjust some details");
              },
              child: Text(
                'Adjust details',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceColumn(String label, double price, ColorScheme scheme) {
    return Column(
      children: [
        Text(
          '\$${price.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea(ColorScheme scheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTyping
                  ? scheme.surfaceContainerHighest
                  : ProServeColors.accent,
            ),
            child: IconButton(
              onPressed: _isTyping ? null : () => _sendMessage(),
              icon: Icon(
                Icons.arrow_upward,
                color: _isTyping ? scheme.onSurfaceVariant : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────── Data Model ────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> quickReplies;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickReplies = const [],
    this.isError = false,
  });
}
