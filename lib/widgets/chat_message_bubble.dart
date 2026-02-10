import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/marketplace_models.dart';
import 'chat_audio_player.dart';

/// A single chat message bubble (text, image, file, audio).
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final DateTime? otherLastRead;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherLastRead,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bool isAutoFileText =
        message.fileName != null &&
        message.text.trim() == '📎 ${message.fileName}';

    final isPending = message.id.startsWith('pending_');
    final isReadByOther =
        otherLastRead != null && otherLastRead!.isAfter(message.timestamp);

    String deliveryLabel() {
      if (!isMe) return '';
      if (isPending) return 'Sending';
      if (isReadByOther) return 'Read';
      return 'Sent';
    }

    IconData deliveryIcon() {
      if (isPending) return Icons.access_time;
      if (isReadByOther) return Icons.done_all;
      return Icons.done;
    }

    Color deliveryColor() {
      if (isPending) return Colors.white.withValues(alpha: 0.7);
      if (isReadByOther) return Colors.blue.shade300;
      return Colors.white.withValues(alpha: 0.7);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : null,
            bottomLeft: !isMe ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.audioUrl != null && message.audioUrl!.isNotEmpty) ...[
              AudioMessagePlayer(
                url: message.audioUrl!,
                durationMs: message.audioDurationMs,
                isMe: isMe,
              ),
              if (message.imageUrl != null ||
                  message.fileUrl != null ||
                  (message.text.isNotEmpty && !isAutoFileText))
                const SizedBox(height: 8),
            ],
            if (message.fileUrl != null && message.fileUrl!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.15)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: isMe ? Colors.white : scheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        (message.fileName != null &&
                                message.fileName!.isNotEmpty)
                            ? message.fileName!
                            : 'File attachment',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe ? Colors.white : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.imageUrl != null ||
                  (message.text.isNotEmpty && !isAutoFileText))
                const SizedBox(height: 8),
            ],
            if (message.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  placeholder: (context, url) => const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.text.isNotEmpty && !isAutoFileText)
              Text(
                message.text,
                style: TextStyle(color: isMe ? Colors.white : scheme.onSurface),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Text(
                    deliveryLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isPending
                          ? Colors.white.withValues(alpha: 0.7)
                          : (isReadByOther
                                ? Colors.blue.shade200
                                : Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(deliveryIcon(), size: 14, color: deliveryColor()),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
