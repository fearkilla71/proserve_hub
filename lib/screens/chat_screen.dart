import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/marketplace_models.dart';
import '../widgets/chat_message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? jobId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.jobId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  final AudioRecorder _recorder = AudioRecorder();
  static const Duration _maxVoiceNoteDuration = Duration(seconds: 45);
  bool _isRecording = false;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  static const int _messagesPageSize = 40;
  DocumentSnapshot? _oldestLoadedMessageDoc;
  final List<Message> _olderMessages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _mySenderName = '';
  final List<Message> _pendingMessages = [];

  StreamSubscription<QuerySnapshot>? _latestMessageSub;
  Timer? _typingStopTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _markConversationAsRead();
    _loadMySenderName();

    // When a new incoming message arrives while this screen is open,
    // update lastRead + clear unread count.
    _latestMessageSub = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          if (snap.docs.isEmpty) return;

          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          final data = snap.docs.first.data();
          final senderId = (data['senderId'] ?? '').toString();
          if (senderId.isEmpty) return;

          // Only update read state for messages from the other user.
          if (senderId != user.uid) {
            _markConversationAsRead();
          }
        });
  }

  @override
  void dispose() {
    _latestMessageSub?.cancel();
    _typingStopTimer?.cancel();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _setTyping(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMySenderName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = (userDoc.data()?['name'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _mySenderName = name.isNotEmpty ? name : (user.email ?? 'Me');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mySenderName = (user.email ?? 'Me');
      });
    }
  }

  Future<void> _markConversationAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'unreadCount.${user.uid}': 0,
            'lastRead.${user.uid}': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _setTyping(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isTyping == value) return;
    _isTyping = value;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'typing.${user.uid}': value});
    } catch (e) {
      // Typing indicators are best-effort.
      debugPrint('Error updating typing indicator: $e');
    }
  }

  void _onComposerChanged(String _) {
    _typingStopTimer?.cancel();
    _setTyping(true);
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  Future<File> _compressImageIfNeeded(String path) async {
    final original = File(path);
    try {
      final stat = await original.stat();
      if (stat.size <= 1024 * 1024) return original;

      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        outPath,
        quality: 80,
        minWidth: 1280,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) return original;
      return File(compressed.path);
    } catch (_) {
      return original;
    }
  }

  Future<void> _sendMessage({
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    String? audioUrl,
    int? audioDurationMs,
    String? text,
    bool setSendingState = true,
    String? pendingId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty &&
        imageUrl == null &&
        fileUrl == null &&
        audioUrl == null) {
      return;
    }

    if (setSendingState) {
      setState(() => _isSending = true);
    }

    try {
      final userName = _mySenderName.trim().isNotEmpty
          ? _mySenderName.trim()
          : (user.email ?? 'Me');

      final messageData = {
        'conversationId': widget.conversationId,
        'senderId': user.uid,
        'senderName': userName,
        'text': messageText,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'readBy': {user.uid: true, widget.otherUserId: false},
      };

      // Add message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation
      String lastMessage = messageText;
      if (audioUrl != null) lastMessage = '🎤 Voice note';
      if (imageUrl != null) lastMessage = '📷 Photo';
      if (fileUrl != null) lastMessage = '📎 ${fileName ?? 'File'}';

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'lastMessage': lastMessage,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageAt': FieldValue.serverTimestamp(),
            'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
            // Best-effort TTL-style cleanup marker (used by scheduled cleanup).
            'expiresAt': Timestamp.fromDate(
              DateTime.now().toUtc().add(const Duration(days: 30)),
            ),
          });

      // Sending a message implies you're no longer "typing".
      _typingStopTimer?.cancel();
      await _setTyping(false);

      if (text == null) {
        _messageController.clear();
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (pendingId != null && mounted) {
        setState(() {
          _pendingMessages.removeWhere((m) => m.id == pendingId);
        });
      }
      if (setSendingState && mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_oldestLoadedMessageDoc == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_oldestLoadedMessageDoc!)
          .limit(_messagesPageSize)
          .get();

      if (snap.docs.isNotEmpty) {
        _oldestLoadedMessageDoc = snap.docs.last;
        final batch = snap.docs.map((d) => Message.fromFirestore(d)).toList();
        if (mounted) {
          setState(() {
            _olderMessages.addAll(batch);
          });
        }
      }

      if (snap.docs.length < _messagesPageSize) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error loading older messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _sendTextMessageOptimistic() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _typingStopTimer?.cancel();
    await _setTyping(false);

    _messageController.clear();

    final pending = Message(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: user.uid,
      senderName: _mySenderName.isNotEmpty
          ? _mySenderName
          : (user.email ?? 'Me'),
      text: messageText,
      timestamp: DateTime.now(),
      isRead: false,
      readBy: {user.uid: true, widget.otherUserId: false},
    );

    if (mounted) {
      setState(() {
        _pendingMessages.insert(0, pending);
      });
    }
    _scrollToBottom();

    await _sendMessage(
      text: messageText,
      setSendingState: false,
      pendingId: pending.id,
    );
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // Enforce 10 MB file size limit
    final fileSize = await image.length();
    if (fileSize > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large. Maximum size is 10 MB.'),
          ),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      final fileToUpload = await _compressImageIfNeeded(image.path);

      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child(
        'chat_images/${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}_${image.name}',
      );

      await imageRef.putFile(fileToUpload);
      final imageUrl = await imageRef.getDownloadURL();

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'zip'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() => _isSending = true);

      final storageRef = FirebaseStorage.instance.ref();
      final fileRef = storageRef.child(
        'chat_files/${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
      );

      await fileRef.putFile(File(file.path!));
      final fileUrl = await fileRef.getDownloadURL();

      await _sendMessage(
        text: '📎 ${file.name}',
        fileUrl: fileUrl,
        fileName: file.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send file: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleVoiceNote() async {
    if (_isSending) return;
    if (_isRecording) {
      await _stopVoiceNote(send: true);
    } else {
      await _startVoiceNote();
    }
  }

  Future<void> _startVoiceNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required.')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
        path: filePath,
      );

      _recordingStartedAt = DateTime.now();
      _recordingTimer?.cancel();
      _recordingSeconds = 0;

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
      }

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!_isRecording) {
          t.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(_recordingStartedAt!);
        if (mounted) {
          setState(() {
            _recordingSeconds = elapsed.inSeconds;
          });
        }
        if (elapsed >= _maxVoiceNoteDuration) {
          t.cancel();
          await _stopVoiceNote(send: true);
        }
      });
    } catch (e) {
      debugPrint('Failed to start voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopVoiceNote({required bool send}) async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();

    final startedAt = _recordingStartedAt;
    _recordingStartedAt = null;

    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }

    try {
      final path = await _recorder.stop();
      if (!send || path == null || path.isEmpty) return;

      final durationMs = startedAt == null
          ? null
          : DateTime.now().difference(startedAt).inMilliseconds;

      setState(() => _isSending = true);

      final storageRef = FirebaseStorage.instance.ref();
      final audioRef = storageRef.child(
        'chat_audio/${widget.conversationId}/${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser!.uid}.m4a',
      );

      await audioRef.putFile(File(path));
      final audioUrl = await audioRef.getDownloadURL();

      await _sendMessage(
        audioUrl: audioUrl,
        audioDurationMs: durationMs,
        text: '🎤 Voice note',
      );
    } catch (e) {
      debugPrint('Failed to send voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, convSnap) {
        final convData = convSnap.data?.data() ?? <String, dynamic>{};

        final typing = (convData['typing'] is Map)
            ? Map<String, dynamic>.from(convData['typing'] as Map)
            : <String, dynamic>{};
        final isOtherTyping = (typing[widget.otherUserId] == true);

        DateTime? otherLastRead;
        if (convData['lastRead'] is Map) {
          final lastRead = Map<String, dynamic>.from(
            convData['lastRead'] as Map,
          );
          final ts = lastRead[widget.otherUserId];
          if (ts is Timestamp) {
            otherLastRead = ts.toDate();
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.otherUserName),
                if (isOtherTyping)
                  Text(
                    'Typing…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.schedule),
                onPressed: () {
                  context.push(
                    '/call-schedule',
                    extra: {
                      'otherUserId': widget.otherUserId,
                      'otherUserName': widget.otherUserName,
                      'conversationId': widget.conversationId,
                    },
                  );
                },
                tooltip: 'Schedule Call',
              ),
              if (widget.jobId != null)
                IconButton(
                  icon: const Icon(Icons.work_outline),
                  onPressed: () {
                    // Navigate to job details
                    context.push('/job/${widget.jobId}');
                  },
                  tooltip: 'View job',
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(widget.conversationId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(_messagesPageSize)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!.docs
                        .map((doc) => Message.fromFirestore(doc))
                        .toList();

                    if (snapshot.data!.docs.isNotEmpty) {
                      _oldestLoadedMessageDoc ??= snapshot.data!.docs.last;
                      if (snapshot.data!.docs.length < _messagesPageSize) {
                        _hasMore = false;
                      }
                    }

                    final combinedMessages = [
                      ..._pendingMessages,
                      ...messages,
                      ..._olderMessages,
                    ];

                    if (combinedMessages.isEmpty) {
                      return const Center(
                        child: Text('No messages yet. Say hello! 👋'),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: combinedMessages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_hasMore && index == combinedMessages.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: _isLoadingMore
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: _loadOlderMessages,
                                      child: const Text('Load older messages'),
                                    ),
                            ),
                          );
                        }

                        final message = combinedMessages[index];
                        final isMe = message.senderId == user.uid;
                        final showDate =
                            index == combinedMessages.length - 1 ||
                            !_isSameDay(
                              message.timestamp,
                              combinedMessages[index + 1].timestamp,
                            );

                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  _formatDate(message.timestamp),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            MessageBubble(
                              message: message,
                              isMe: isMe,
                              otherLastRead: otherLastRead,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _isSending ? null : _pickAndSendImage,
                      tooltip: 'Send Image',
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isSending ? null : _pickAndSendFile,
                      tooltip: 'Send File',
                    ),
                    IconButton(
                      icon: _isRecording
                          ? const Icon(Icons.stop_circle)
                          : const Icon(Icons.mic_none),
                      color: _isRecording
                          ? Theme.of(context).colorScheme.error
                          : null,
                      onPressed: _toggleVoiceNote,
                      tooltip: _isRecording
                          ? 'Stop recording'
                          : 'Record voice note',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _isRecording
                              ? 'Recording… ${_recordingSeconds}s'
                              : 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onChanged: _onComposerChanged,
                        onSubmitted: (_) => _sendTextMessageOptimistic(),
                        enabled: !_isSending && !_isRecording,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send message',
                      icon: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _isSending || _isRecording
                          ? null
                          : _sendTextMessageOptimistic,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }
}
