import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Inline audio player for voice-note messages.
class AudioMessagePlayer extends StatefulWidget {
  final String url;
  final int? durationMs;
  final bool isMe;

  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.durationMs,
    required this.isMe,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.durationMs != null
        ? Duration(milliseconds: widget.durationMs!)
        : null;

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _duration ??= dur);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.isMe ? Colors.white : scheme.onSurface;
    final bg = widget.isMe
        ? Colors.white.withValues(alpha: 0.15)
        : scheme.surface;

    final dur = _duration;
    final total = dur ?? const Duration(seconds: 0);
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: fg),
            onPressed: () async {
              try {
                if (_isPlaying) {
                  await _player.pause();
                } else {
                  await _player.play(UrlSource(widget.url));
                }
              } catch (e) {
                debugPrint('Audio play failed: $e');
              }
            },
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            dur != null ? _fmt(dur) : 'Voice note',
            style: TextStyle(color: fg, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
