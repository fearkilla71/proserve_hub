import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const VideoCallScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  Timer? _callTimer;
  int _callDuration = 0;
  String _callStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _endCall();
    super.dispose();
  }

  Future<void> _startCall() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Create call record
      await FirebaseFirestore.instance.collection('calls').add({
        'conversationId': widget.conversationId,
        'callerId': user.uid,
        'receiverId': widget.otherUserId,
        'type': 'video',
        'status': 'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _callStatus = 'Connected';
      });

      // Start call duration timer
      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _callDuration++;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _callStatus = 'Connection failed';
        });
      }
    }
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();

    try {
      // Update call record
      final calls = await FirebaseFirestore.instance
          .collection('calls')
          .where('conversationId', isEqualTo: widget.conversationId)
          .where('status', isEqualTo: 'ongoing')
          .get();

      for (var doc in calls.docs) {
        await doc.reference.update({
          'status': 'completed',
          'endedAt': FieldValue.serverTimestamp(),
          'duration': _callDuration,
        });
      }
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video preview (placeholder)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _callStatus,
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_callDuration),
                    style: TextStyle(fontSize: 18, color: Colors.grey[300]),
                  ),
                ],
              ),
            ),

            // Local video preview (small)
            if (!_isVideoOff)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                      },
                      backgroundColor: _isMuted ? Colors.red : Colors.grey[800],
                    ),

                    // Video toggle button
                    _buildControlButton(
                      icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                      label: _isVideoOff ? 'Start Video' : 'Stop Video',
                      onPressed: () {
                        setState(() {
                          _isVideoOff = !_isVideoOff;
                        });
                      },
                      backgroundColor: _isVideoOff
                          ? Colors.red
                          : Colors.grey[800],
                    ),

                    // End call button
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      backgroundColor: Colors.red,
                      size: 64,
                    ),

                    // Switch camera button
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      label: 'Flip',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Camera switched'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      backgroundColor: Colors.grey[800],
                    ),

                    // More options button
                    _buildControlButton(
                      icon: Icons.more_vert,
                      label: 'More',
                      onPressed: () {
                        _showMoreOptions();
                      },
                      backgroundColor: Colors.grey[800],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
    double size = 56,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: backgroundColor ?? Colors.grey[800],
          borderRadius: BorderRadius.circular(size / 2),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.white),
              title: const Text(
                'Open Chat',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                // Navigate to chat would go here
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share, color: Colors.white),
              title: const Text(
                'Share Screen',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Screen sharing started')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
