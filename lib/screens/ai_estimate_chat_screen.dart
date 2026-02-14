import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../theme/proserve_theme.dart';

/// Recursively converts nested maps (from Firebase callable
/// responses) into `Map<String,dynamic>` so that `as` casts don't throw.
dynamic _deepCast(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries) e.key.toString(): _deepCast(e.value),
    };
  }
  if (value is List) return value.map(_deepCast).toList();
  return value;
}

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

  // ── Room counter state (interior painting) ──
  final Map<String, int> _roomCounts = {
    'Bedrooms': 0,
    'Bathrooms': 0,
    'Kitchens': 0,
    'Living Rooms': 0,
    'Dining Rooms': 0,
    'Closets': 0,
    'Laundry Rooms': 0,
    'Garage': 0,
  };
  bool _roomCountersSent = false;

  int get _totalRooms => _roomCounts.values.fold(0, (a, b) => a + b);

  bool _isRoomQuickReplies(List<String> replies) {
    if (_roomCountersSent) return false;
    const paintTypes = ['interior_painting', 'painting'];
    if (!paintTypes.contains(widget.serviceType)) return false;
    const roomKeywords = [
      'bedroom',
      'bathroom',
      'kitchen',
      'living',
      'dining',
      'closet',
      'laundry',
      'garage',
    ];
    int matches = 0;
    for (final r in replies) {
      final lower = r.toLowerCase();
      if (roomKeywords.any((k) => lower.contains(k))) matches++;
    }
    return matches >= 2;
  }

  void _submitRoomCounters() {
    final parts = <String>[];
    _roomCounts.forEach((label, roomCount) {
      if (roomCount > 0) parts.add('$roomCount $label');
    });
    if (parts.isEmpty) return;
    _roomCountersSent = true;
    setState(() {});
    _sendMessage(parts.join(', '));
  }

  // Pending photo attachments
  final List<_PendingImage> _pendingImages = [];

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

  // ──────────────────── Photo Handling ────────────────────

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        // Allow multiple photos from gallery
        final picks = await picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 70,
        );
        for (final xf in picks) {
          final bytes = await xf.readAsBytes();
          final mime = xf.mimeType ?? 'image/jpeg';
          setState(
            () => _pendingImages.add(_PendingImage(bytes: bytes, mime: mime)),
          );
        }
      } else {
        final xf = await picker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 70,
        );
        if (xf != null) {
          final bytes = await xf.readAsBytes();
          final mime = xf.mimeType ?? 'image/jpeg';
          setState(
            () => _pendingImages.add(_PendingImage(bytes: bytes, mime: mime)),
          );
        }
      }
      _scrollToBottom();
    } catch (_) {}
  }

  void _showPhotoOptions() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _chatController.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;
    if (_isTyping) return;

    _chatController.clear();
    HapticFeedback.selectionClick();

    // Capture pending images for this message
    final attachedImages = List<_PendingImage>.from(_pendingImages);

    // Add user message to display (with any attached images)
    setState(() {
      _pendingImages.clear();
      _displayMessages.add(
        _ChatMessage(
          text: text.isNotEmpty
              ? text
              : '📷 ${attachedImages.length} photo${attachedImages.length > 1 ? 's' : ''} attached',
          isUser: true,
          timestamp: DateTime.now(),
          imageAttachments: attachedImages,
        ),
      );
    });

    _scrollToBottom();

    // Add to conversation history
    final msgText = text.isNotEmpty
        ? text
        : 'Here are photos of the project area.';
    _messages.add({'role': 'user', 'content': msgText});

    // Send to AI (with images if present)
    await _sendToAi(attachedImages: attachedImages);
  }

  Future<void> _sendToAi({
    bool isInitial = false,
    List<_PendingImage>? attachedImages,
  }) async {
    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';

      // Convert images to base64 payload
      final imagePayload = <Map<String, String>>[];
      for (final img in (attachedImages ?? [])) {
        imagePayload.add({'b64': base64Encode(img.bytes), 'mime': img.mime});
      }

      // Build the request
      final payload = <String, dynamic>{
        'serviceType': widget.serviceType,
        'serviceName': widget.serviceName,
        'messages': _messages,
        'isInitial': isInitial,
        if (imagePayload.isNotEmpty) 'images': imagePayload,
      };

      Map<String, dynamic> result;
      // Use HTTP for image uploads (callable has payload size limits)
      final useHttp = imagePayload.isNotEmpty;
      try {
        if (useHttp) throw Exception('prefer HTTP for images');
        // Try callable first (text-only)
        final callable = FirebaseFunctions.instance.httpsCallable(
          'aiEstimateChat',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
        final response = await callable.call(payload);
        result = _deepCast(response.data) as Map<String, dynamic>;
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
      final estimate = result['estimate'] != null
          ? _deepCast(result['estimate']) as Map<String, dynamic>
          : null;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Show attached images above the message text
          if (msg.imageAttachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 6),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: msg.imageAttachments.map((img) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      img.bytes,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 48), // Left padding for alignment
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
          // Quick reply chips or room counters
          if (msg.quickReplies.isNotEmpty &&
              _isRoomQuickReplies(msg.quickReplies))
            _buildRoomCounters(scheme)
          else if (msg.quickReplies.isNotEmpty)
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

  // ──────────────────── Room Counter Widget ────────────────────

  Widget _buildRoomCounters(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 12, right: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ProServeColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your rooms',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ..._roomCounts.entries.map((e) => _roomCounterRow(e.key, scheme)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _totalRooms > 0 ? _submitRoomCounters : null,
                style: FilledButton.styleFrom(
                  backgroundColor: ProServeColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  _totalRooms == 0
                      ? 'Select at least 1 room'
                      : 'Continue  ·  $_totalRooms room${_totalRooms == 1 ? '' : 's'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomCounterRow(String label, ColorScheme scheme) {
    final count = _roomCounts[label] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: count > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          IconButton(
            onPressed: count > 0
                ? () => setState(() => _roomCounts[label] = count - 1)
                : null,
            icon: Icon(
              Icons.remove_circle_outline,
              color: count > 0
                  ? ProServeColors.accent
                  : scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            iconSize: 28,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: count > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: count < 20
                ? () => setState(() => _roomCounts[label] = count + 1)
                : null,
            icon: Icon(
              Icons.add_circle_outline,
              color: count < 20
                  ? ProServeColors.accent
                  : scheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            iconSize: 28,
            visualDensity: VisualDensity.compact,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pending images preview strip
        if (_pendingImages.isNotEmpty)
          Container(
            height: 80,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            alignment: Alignment.centerLeft,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingImages.length,
              separatorBuilder: (_, i2) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _pendingImages[i].bytes,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _pendingImages.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.of(context).padding.bottom + 8,
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
              // Photo button
              IconButton(
                onPressed: _isTyping ? null : _showPhotoOptions,
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _isTyping
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                      : ProServeColors.accent,
                ),
                tooltip: 'Attach photos',
              ),
              const SizedBox(width: 4),
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
                  color:
                      (_isTyping ||
                          (_chatController.text.trim().isEmpty &&
                              _pendingImages.isEmpty))
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
        ),
      ],
    );
  }
}

// ──────────────────── Data Models ────────────────────

class _PendingImage {
  final Uint8List bytes;
  final String mime;
  const _PendingImage({required this.bytes, required this.mime});
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> quickReplies;
  final bool isError;
  final List<_PendingImage> imageAttachments;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickReplies = const [],
    this.isError = false,
    this.imageAttachments = const [],
  });
}
