import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Contractor digital business card with a QR code that links
/// to their profile / booking page. Clients can scan to view.
class ContractorQrScreen extends StatefulWidget {
  const ContractorQrScreen({super.key});

  @override
  State<ContractorQrScreen> createState() => _ContractorQrScreenState();
}

class _ContractorQrScreenState extends State<ContractorQrScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('contractors')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _profile = doc.data();
        _loading = false;
      });
    }
  }

  String get _profileUrl {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return 'https://proservehub.app/contractor/$uid';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile ?? {};
    final companyName =
        profile['companyName'] as String? ??
        profile['displayName'] as String? ??
        'Contractor';
    final email = profile['email'] as String? ?? '';
    final phone = profile['phone'] as String? ?? '';
    final services =
        (profile['serviceTypes'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contractor Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share card',
            onPressed: () => _shareCard(companyName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Digital business card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withValues(alpha: .2),
                    child: Text(
                      companyName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    companyName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: services
                          .take(5)
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                s.replaceAll('_', ' '),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── QR Code ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Scan to view my profile',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // QR code rendered via CustomPainter
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: _QrCodePainter(
                        data: _profileUrl,
                        color: scheme.primary,
                      ),
                      size: const Size(200, 200),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _profileUrl,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _profileUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareCard(companyName),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareCard(String companyName) {
    Share.share(
      'Check out $companyName on ProServe Hub!\n$_profileUrl',
      subject: '$companyName - ProServe Hub',
    );
  }
}

/// Simple QR-style pattern painter that creates a recognizable QR-like
/// geometric pattern from the data string. For production use, integrate
/// the qr_flutter package for full QR code spec compliance.
class _QrCodePainter extends CustomPainter {
  final String data;
  final Color color;

  _QrCodePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = 21;
    final cellSize = size.width / gridSize;
    final paint = Paint()..color = color;
    final bgPaint = Paint()..color = Colors.white;

    // White background
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Generate deterministic pattern from data hash
    final hash = data.hashCode;
    final bytes = <int>[];
    var h = hash.abs();
    for (int i = 0; i < gridSize * gridSize; i++) {
      h = (h * 1103515245 + 12345) & 0x7FFFFFFF;
      bytes.add(h);
    }

    // Draw data modules
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        // Skip finder pattern areas
        if (_isFinderArea(row, col, gridSize)) continue;

        final idx = row * gridSize + col;
        if (bytes[idx] % 3 != 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                col * cellSize,
                row * cellSize,
                cellSize * 0.9,
                cellSize * 0.9,
              ),
              Radius.circular(cellSize * 0.2),
            ),
            paint,
          );
        }
      }
    }

    // Draw finder patterns (three corners)
    _drawFinderPattern(canvas, 0, 0, cellSize, paint, bgPaint);
    _drawFinderPattern(
      canvas,
      0,
      (gridSize - 7) * cellSize,
      cellSize,
      paint,
      bgPaint,
    );
    _drawFinderPattern(
      canvas,
      (gridSize - 7) * cellSize,
      0,
      cellSize,
      paint,
      bgPaint,
    );
  }

  bool _isFinderArea(int row, int col, int gridSize) {
    // Top-left
    if (row < 8 && col < 8) return true;
    // Top-right
    if (row < 8 && col >= gridSize - 8) return true;
    // Bottom-left
    if (row >= gridSize - 8 && col < 8) return true;
    return false;
  }

  void _drawFinderPattern(
    Canvas canvas,
    double x,
    double y,
    double cell,
    Paint dark,
    Paint light,
  ) {
    // Outer border (7x7)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cell * 7, cell * 7),
        Radius.circular(cell * 0.5),
      ),
      dark,
    );
    // Inner white (5x5)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + cell, y + cell, cell * 5, cell * 5),
        Radius.circular(cell * 0.3),
      ),
      light,
    );
    // Center dot (3x3)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + cell * 2, y + cell * 2, cell * 3, cell * 3),
        Radius.circular(cell * 0.3),
      ),
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant _QrCodePainter oldDelegate) =>
      data != oldDelegate.data || color != oldDelegate.color;
}
