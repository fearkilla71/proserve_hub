import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class RenderToolScreen extends StatefulWidget {
  const RenderToolScreen({super.key});

  @override
  State<RenderToolScreen> createState() => _RenderToolScreenState();
}

enum _RenderMode { ai, manual }

class _AiHistoryItem {
  final Uint8List imageBytes;
  final Color wallColor;
  final Color cabinetColor;
  final bool wallsEnabled;
  final bool cabinetsEnabled;
  final String? prompt;
  final DateTime createdAt;

  const _AiHistoryItem({
    required this.imageBytes,
    required this.wallColor,
    required this.cabinetColor,
    required this.wallsEnabled,
    required this.cabinetsEnabled,
    required this.prompt,
    required this.createdAt,
  });
}

class _RenderToolScreenState extends State<RenderToolScreen> {
  final _boundaryKey = GlobalKey();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();

  Uint8List? _originalBytes;
  ui.Image? _originalImage;
  ui.Image? _aiImage;

  _RenderMode _mode = _RenderMode.ai;
  bool _showOriginal = false;
  bool _compareMode = false;
  double _sliderX = 0.5; // 0.0 = all original, 1.0 = all edited

  bool _aiBusy = false;
  Color _wallColor = const Color(0xFF2E7DFF);
  Color _cabinetColor = const Color(0xFF00BFA5);
  bool _wallsEnabled = true;
  bool _cabinetsEnabled = true;

  final List<_AiHistoryItem> _aiHistory = <_AiHistoryItem>[];

  // Manual fallback
  final List<_Stroke> _strokes = <_Stroke>[];
  _Stroke? _activeStroke;
  Color _paintColor = const Color(0xFF2E7DFF);
  double _paintOpacity = 0.55;
  double _brushSize = 22;
  bool _eraserMode = false;

  bool _exporting = false;
  bool _saving = false;

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    _originalImage?.dispose();
    _aiImage?.dispose();
    super.dispose();
  }

  double _descriptionScoreFor(String prompt) {
    final p = prompt.trim();
    if (p.isEmpty) return 0.0;

    // Simple local heuristic: more detail -> higher score.
    final tokens = p
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9#]+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final lengthScore = (p.length / 140).clamp(0.0, 1.0);
    final tokenScore = (tokens.length / 18).clamp(0.0, 1.0);

    final hasAction = tokens.any(
      (t) =>
          t.contains('paint') || t.contains('recolor') || t.contains('change'),
    );
    final hasTargets =
        tokens.any((t) => t.contains('wall')) ||
        tokens.any((t) => t.contains('cabinet')) ||
        tokens.any((t) => t.contains('trim'));
    final hasColor =
        tokens.any((t) => t.startsWith('#') && t.length == 7) ||
        tokens.any(
          (t) => <String>{
            'white',
            'offwhite',
            'cream',
            'beige',
            'gray',
            'greige',
            'black',
            'navy',
            'blue',
            'green',
            'sage',
            'charcoal',
            'taupe',
          }.contains(t),
        );

    final bonus =
        ((hasAction ? 0.15 : 0.0) +
                (hasTargets ? 0.15 : 0.0) +
                (hasColor ? 0.15 : 0.0))
            .clamp(0.0, 0.35);

    return (0.45 * lengthScore + 0.55 * tokenScore + bonus).clamp(0.0, 1.0);
  }

  Future<void> _openPhotoPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAdvancedSheet() async {
    final original = _originalImage;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Advanced',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    if (original != null)
                      TextButton.icon(
                        onPressed: _aiBusy ? null : _runAiRender,
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(_aiBusy ? 'Rendering…' : 'Render'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SegmentedButton<_RenderMode>(
                  segments: const [
                    ButtonSegment(
                      value: _RenderMode.ai,
                      label: Text('AI'),
                      icon: Icon(Icons.auto_fix_high),
                    ),
                    ButtonSegment(
                      value: _RenderMode.manual,
                      label: Text('Manual'),
                      icon: Icon(Icons.brush),
                    ),
                  ],
                  selected: <_RenderMode>{_mode},
                  onSelectionChanged: (s) {
                    final v = s.isEmpty ? _RenderMode.ai : s.first;
                    setState(() => _mode = v);
                  },
                ),
                const SizedBox(height: 10),
                if (_mode == _RenderMode.ai)
                  _AiOptionsBar(
                    wallColor: _wallColor,
                    cabinetColor: _cabinetColor,
                    wallsEnabled: _wallsEnabled,
                    cabinetsEnabled: _cabinetsEnabled,
                    busy: _aiBusy,
                    onPickWallColor: () async {
                      if (!_wallsEnabled) return;
                      final picked = await _pickColorSheet(
                        title: 'Pick wall color',
                        current: _wallColor,
                      );
                      if (!mounted || picked == null) return;
                      setState(() => _wallColor = picked);
                    },
                    onPickCabinetColor: () async {
                      if (!_cabinetsEnabled) return;
                      final picked = await _pickColorSheet(
                        title: 'Pick cabinet color',
                        current: _cabinetColor,
                      );
                      if (!mounted || picked == null) return;
                      setState(() => _cabinetColor = picked);
                    },
                    onToggleWalls: (v) => setState(() => _wallsEnabled = v),
                    onToggleCabinets: (v) =>
                        setState(() => _cabinetsEnabled = v),
                  )
                else
                  _ManualControlsBar(
                    paintColor: _paintColor,
                    opacity: _paintOpacity,
                    brushSize: _brushSize,
                    eraserMode: _eraserMode,
                    canUndo: _strokes.isNotEmpty,
                    onPickColor: () async {
                      final picked = await _pickColorSheet(
                        title: 'Pick paint color',
                        current: _paintColor,
                      );
                      if (!mounted || picked == null) return;
                      setState(() => _paintColor = picked);
                    },
                    onOpacityChanged: (v) => setState(() => _paintOpacity = v),
                    onBrushSizeChanged: (v) => setState(() => _brushSize = v),
                    onToggleEraser: () =>
                        setState(() => _eraserMode = !_eraserMode),
                    onUndo: () {
                      if (_strokes.isEmpty) return;
                      setState(() => _strokes.removeLast());
                    },
                    onClear: () {
                      if (_strokes.isEmpty) return;
                      setState(() => _strokes.clear());
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );
      if (!mounted || picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _originalBytes = bytes;
        _originalImage?.dispose();
        _originalImage = frame.image;
        _aiImage?.dispose();
        _aiImage = null;
        _mode = _RenderMode.ai;
        _showOriginal = false;
        _strokes.clear();
        _activeStroke = null;

        _aiHistory.clear();

        _promptController.text = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load photo: $e')));
    }
  }

  String _toHexRgb(Color c) {
    final v = c.toARGB32() & 0x00FFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _runAiRender() async {
    if (_aiBusy) return;
    final bytes = _originalBytes;
    if (bytes == null || bytes.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required to use AI render.')),
      );
      return;
    }

    final prompt = _promptController.text.trim();
    final isPromptMode = prompt.isNotEmpty;
    const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    final callableName = isPromptMode ? 'aiRenderPromptAny' : 'aiRenderRecolor';

    if (!isPromptMode && !_wallsEnabled && !_cabinetsEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select Walls and/or Cabinets to render.'),
        ),
      );
      return;
    }

    setState(() => _aiBusy = true);
    try {
      // Prompt mode: prioritize speed (smaller upload + faster encode).
      // Recolor mode: keep higher resolution for better wall/cabinet boundaries.
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: isPromptMode ? 640 : 1024,
        minHeight: isPromptMode ? 640 : 1024,
        quality: isPromptMode ? 75 : 85,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      final payload = <String, dynamic>{
        'imageBase64': base64Encode(compressed),
        if (isPromptMode) 'prompt': prompt,
        if (!isPromptMode) ...<String, dynamic>{
          'wallColor': _toHexRgb(_wallColor),
          'cabinetColor': _toHexRgb(_cabinetColor),
          'wallsEnabled': _wallsEnabled,
          'cabinetsEnabled': _cabinetsEnabled,
        },
      };

      // Force the region to avoid accidental mismatches.
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable(
        callableName,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 180)),
      );

      // Retry once for transient network/service errors (Firebase code: unavailable).
      late HttpsCallableResult<dynamic> resp;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          resp = await callable.call(payload);
          break;
        } on FirebaseFunctionsException catch (e) {
          final code = e.code.trim().toLowerCase();
          if (code != 'unavailable' || attempt == 1) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 900));
        }
      }

      final data = resp.data;
      final outB64 = (data is Map && data['imageBase64'] != null)
          ? data['imageBase64'].toString()
          : '';
      if (outB64.isEmpty) {
        throw StateError('AI render returned empty result');
      }

      final outBytes = base64Decode(outB64);
      final outCodec = await ui.instantiateImageCodec(outBytes);
      final outFrame = await outCodec.getNextFrame();

      if (!mounted) return;
      setState(() {
        _aiImage?.dispose();
        _aiImage = outFrame.image;
        _mode = _RenderMode.ai;
        _showOriginal = false;

        _aiHistory.insert(
          0,
          _AiHistoryItem(
            imageBytes: outBytes,
            wallColor: _wallColor,
            cabinetColor: _cabinetColor,
            wallsEnabled: _wallsEnabled,
            cabinetsEnabled: _cabinetsEnabled,
            prompt: prompt.isEmpty ? null : prompt,
            createdAt: DateTime.now(),
          ),
        );
        if (_aiHistory.length > 8) {
          _aiHistory.removeRange(8, _aiHistory.length);
        }
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final details = e.details;
      final detailsText = details == null
          ? ''
          : (details is String ? details : details.toString());

      final msg = (e.message ?? '').trim();
      final code = e.code.trim();

      final hints = <String>[];
      if (useEmulators) {
        hints.add(
          'Emulators enabled (USE_FIREBASE_EMULATORS=true). Start `firebase emulators:start` or run without that dart-define to use deployed functions.',
        );
      }
      if (callableName.isNotEmpty) {
        hints.add('Callable: $callableName');
      }

      final summary = <String>[
        msg.isNotEmpty ? msg : 'AI render failed',
        if (code.isNotEmpty) '($code)',
        if (detailsText.trim().isNotEmpty) detailsText.trim(),
        if (hints.isNotEmpty) hints.join(' '),
      ].join(' ');

      debugPrint(
        'aiRender FirebaseFunctionsException callable=$callableName useEmulators=$useEmulators code=${e.code} message=${e.message} details=${e.details}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(summary), duration: const Duration(seconds: 6)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI render failed: $e')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _exportAndShare() async {
    if (_exporting) return;

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export is not supported on web yet.')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final renderObject = _boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Render boundary not ready');
      }

      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Failed to encode image');

      final pngBytes = byteData.buffer.asUint8List();
      final file = await _writeTempPng(pngBytes);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'ProServe Render Tool preview');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _inferImageExt(Uint8List bytes) {
    if (bytes.length >= 12) {
      // PNG
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
      // JPEG
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'jpg';
      }
      // WEBP: RIFF....WEBP
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
    }
    if (bytes.length >= 6) {
      // GIF
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38 &&
          (bytes[4] == 0x37 || bytes[4] == 0x39) &&
          bytes[5] == 0x61) {
        return 'gif';
      }
    }
    return 'png';
  }

  Future<void> _saveRenderToPhone() async {
    if (_saving) return;

    if (_aiHistory.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No edited render to save yet.')),
      );
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save is not supported on web yet.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final bytes = _aiHistory.first.imageBytes;
      final ext = _inferImageExt(bytes);
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final name = 'proserve_render_$ts.$ext';

      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: name,
        quality: 100,
      );

      final ok = (result is Map)
          ? ((result['isSuccess'] == true) || (result['success'] == true))
          : true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Saved to Photos.' : 'Saved (check your gallery).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<File> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}${Platform.pathSeparator}render_$ts.png');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<Color?> _pickColorSheet({
    required String title,
    required Color current,
  }) {
    return showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = <Color>[
          const Color(0xFF2E7DFF),
          const Color(0xFF00BFA5),
          const Color(0xFFFFC107),
          const Color(0xFFFF7043),
          const Color(0xFFE53935),
          const Color(0xFF8E24AA),
          const Color(0xFF3949AB),
          const Color(0xFF00897B),
          const Color(0xFF6D4C41),
          const Color(0xFF546E7A),
          const Color(0xFF212121),
          const Color(0xFFF5F5F5),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in colors)
                      InkWell(
                        onTap: () => Navigator.pop(context, c),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              width: 2,
                            ),
                          ),
                          child: c == current
                              ? Icon(
                                  Icons.check,
                                  color: c.computeLuminance() > 0.6
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Manual stroke helpers
  void _startStroke(_CanvasMapping mapping, Offset localPos) {
    final p = mapping.toNormalized(localPos);
    if (p == null) return;

    final stroke = _Stroke(
      color: _paintColor,
      opacity: _paintOpacity,
      width: _brushSize,
      eraser: _eraserMode,
      points: <Offset>[p],
    );

    setState(() {
      _activeStroke = stroke;
      _strokes.add(stroke);
    });
  }

  void _extendStroke(_CanvasMapping mapping, Offset localPos) {
    final p = mapping.toNormalized(localPos);
    if (p == null) return;
    final s = _activeStroke;
    if (s == null) return;
    setState(() => s.points.add(p));
  }

  void _endStroke() => setState(() => _activeStroke = null);

  @override
  Widget build(BuildContext context) {
    final original = _originalImage;
    final ai = _aiImage;

    const headerColor = Color(0xFF0B163B);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        centerTitle: true,
        title: const Text('Describe Project'),
        actions: [
          IconButton(
            tooltip: 'Next',
            onPressed: _aiBusy
                ? null
                : () async {
                    if (original == null) {
                      await _openPhotoPickerSheet();
                      return;
                    }
                    await _runAiRender();
                  },
            icon: _aiBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_forward),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A7B5),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice input coming soon.')),
          );
        },
        child: const Icon(Icons.mic, color: Colors.white),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Camera',
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: 'Attach',
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                tooltip: 'Advanced',
                onPressed: _openAdvancedSheet,
                icon: const Icon(Icons.text_fields),
              ),
              IconButton(
                tooltip: 'Keyboard',
                onPressed: () {
                  FocusScope.of(context).requestFocus(_promptFocusNode);
                },
                icon: const Icon(Icons.keyboard),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _promptController,
                  builder: (context, value, _) {
                    final score = _descriptionScoreFor(value.text);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            value: score,
                            strokeWidth: 4,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Description Score',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  focusNode: _promptFocusNode,
                  controller: _promptController,
                  maxLines: 6,
                  minLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Describe the render you want (colors, surfaces, style)...',
                  ),
                ),
              ),
            ),
            // ── Render History Gallery ──
            if (_aiHistory.isNotEmpty)
              SizedBox(
                height: 72,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _aiHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final item = _aiHistory[i];
                      return GestureDetector(
                        onTap: () async {
                          final codec = await ui.instantiateImageCodec(
                            item.imageBytes,
                          );
                          final frame = await codec.getNextFrame();
                          if (!mounted) return;
                          setState(() {
                            _aiImage?.dispose();
                            _aiImage = frame.image;
                            _showOriginal = false;
                            _compareMode = false;
                            _wallColor = item.wallColor;
                            _cabinetColor = item.cabinetColor;
                            _wallsEnabled = item.wallsEnabled;
                            _cabinetsEnabled = item.cabinetsEnabled;
                            if (item.prompt != null) {
                              _promptController.text = item.prompt!;
                            }
                          });
                        },
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(item.imageBytes, fit: BoxFit.cover),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: const Color(0x99000000),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '#${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Expanded(
              child: original == null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _openPhotoPickerSheet,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Add a photo to render',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to choose Camera or Gallery.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          final hasAlt = _mode == _RenderMode.ai
                                              ? ai != null
                                              : _strokes.isNotEmpty;
                                          if (!hasAlt) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _mode == _RenderMode.ai
                                                      ? 'No edited render yet. Tap Next (→) to generate one.'
                                                      : 'No manual edits yet. Paint on the image first.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          setState(() {
                                            _compareMode = !_compareMode;
                                            if (_compareMode) {
                                              _showOriginal = false;
                                              _sliderX = 0.5;
                                            }
                                          });
                                        },
                                        icon: Icon(
                                          _compareMode
                                              ? Icons.compare
                                              : Icons.compare_arrows,
                                        ),
                                        label: Text(
                                          _compareMode
                                              ? 'Exit compare'
                                              : 'Compare',
                                        ),
                                      ),
                                    ),
                                    if (!_compareMode) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: _showOriginal
                                            ? 'Show edited'
                                            : 'Show original',
                                        onPressed: () {
                                          final hasAlt = _mode == _RenderMode.ai
                                              ? ai != null
                                              : _strokes.isNotEmpty;
                                          if (!hasAlt) return;
                                          setState(
                                            () =>
                                                _showOriginal = !_showOriginal,
                                          );
                                        },
                                        icon: Icon(
                                          _showOriginal
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                tooltip: 'Save to Photos',
                                onPressed: _saving ? null : _saveRenderToPhone,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Icon(Icons.download_rounded),
                              ),
                              IconButton(
                                tooltip: 'Export & share',
                                onPressed: _exporting ? null : _exportAndShare,
                                icon: _exporting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Icon(Icons.ios_share),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final mapping = _CanvasMapping.forImage(
                                imageWidth: original.width.toDouble(),
                                imageHeight: original.height.toDouble(),
                                boxWidth: constraints.maxWidth,
                                boxHeight: constraints.maxHeight,
                              );

                              // ── Compare mode: before / after slider ──
                              if (_compareMode &&
                                  _mode == _RenderMode.ai &&
                                  ai != null) {
                                return _BeforeAfterSlider(
                                  boundaryKey: _boundaryKey,
                                  original: original,
                                  edited: ai,
                                  mapping: mapping,
                                  sliderX: _sliderX,
                                  onSliderChanged: (v) =>
                                      setState(() => _sliderX = v),
                                );
                              }

                              final display =
                                  (_mode == _RenderMode.ai &&
                                      !_showOriginal &&
                                      ai != null)
                                  ? ai
                                  : original;

                              final painter = _mode == _RenderMode.manual
                                  ? _RenderPainter(
                                      image: original,
                                      mapping: mapping,
                                      strokes: List<_Stroke>.unmodifiable(
                                        _strokes,
                                      ),
                                      showOriginal: _showOriginal,
                                    )
                                  : _DisplayPainter(
                                      image: display,
                                      mapping: mapping,
                                    );

                              final preview = RepaintBoundary(
                                key: _boundaryKey,
                                child: CustomPaint(
                                  size: Size(
                                    mapping.boxWidth,
                                    mapping.boxHeight,
                                  ),
                                  painter: painter,
                                ),
                              );

                              final hasEdited = _mode == _RenderMode.ai
                                  ? ai != null
                                  : _strokes.isNotEmpty;
                              final badgeLabel = (!hasEdited || _showOriginal)
                                  ? 'ORIGINAL'
                                  : 'EDITED';
                              final badgeColor = (!hasEdited || _showOriginal)
                                  ? const Color(0xCC000000)
                                  : const Color(0xCC0B163B);

                              final previewWithBadge = Stack(
                                children: [
                                  Positioned.fill(
                                    child: Center(child: preview),
                                  ),
                                  Positioned(
                                    left: 12,
                                    top: 12,
                                    child: IgnorePointer(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              if (_mode != _RenderMode.manual) {
                                return previewWithBadge;
                              }

                              return Center(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (d) =>
                                      _startStroke(mapping, d.localPosition),
                                  onPanUpdate: (d) =>
                                      _extendStroke(mapping, d.localPosition),
                                  onPanEnd: (_) => _endStroke(),
                                  child: previewWithBadge,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiOptionsBar extends StatelessWidget {
  final Color wallColor;
  final Color cabinetColor;
  final bool wallsEnabled;
  final bool cabinetsEnabled;
  final bool busy;
  final VoidCallback onPickWallColor;
  final VoidCallback onPickCabinetColor;
  final ValueChanged<bool> onToggleWalls;
  final ValueChanged<bool> onToggleCabinets;

  const _AiOptionsBar({
    required this.wallColor,
    required this.cabinetColor,
    required this.wallsEnabled,
    required this.cabinetsEnabled,
    required this.busy,
    required this.onPickWallColor,
    required this.onPickCabinetColor,
    required this.onToggleWalls,
    required this.onToggleCabinets,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ColorPill(
                    label: 'Walls',
                    color: wallColor,
                    enabled: wallsEnabled && !busy,
                    onTap: wallsEnabled && !busy ? onPickWallColor : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ColorPill(
                    label: 'Cabinets',
                    color: cabinetColor,
                    enabled: cabinetsEnabled && !busy,
                    onTap: cabinetsEnabled && !busy ? onPickCabinetColor : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    value: wallsEnabled,
                    onChanged: busy ? null : onToggleWalls,
                    title: const Text('Walls'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    value: cabinetsEnabled,
                    onChanged: busy ? null : onToggleCabinets,
                    title: const Text('Cabinets'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _ColorPill({
    required this.label,
    required this.color,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = enabled ? onTap : null;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      ),
    );
  }
}

class _ManualControlsBar extends StatelessWidget {
  final Color paintColor;
  final double opacity;
  final double brushSize;
  final bool eraserMode;
  final bool canUndo;
  final VoidCallback onPickColor;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onBrushSizeChanged;
  final VoidCallback onToggleEraser;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const _ManualControlsBar({
    required this.paintColor,
    required this.opacity,
    required this.brushSize,
    required this.eraserMode,
    required this.canUndo,
    required this.onPickColor,
    required this.onOpacityChanged,
    required this.onBrushSizeChanged,
    required this.onToggleEraser,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onPickColor,
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: paintColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Color',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: eraserMode ? 'Paint mode' : 'Eraser mode',
                  onPressed: onToggleEraser,
                  icon: Icon(
                    eraserMode ? Icons.cleaning_services : Icons.brush,
                  ),
                ),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: canUndo ? onClear : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 90, child: Text('Opacity')),
                Expanded(
                  child: Slider(
                    value: opacity,
                    min: 0.15,
                    max: 0.85,
                    onChanged: onOpacityChanged,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 90, child: Text('Brush')),
                Expanded(
                  child: Slider(
                    value: brushSize,
                    min: 8,
                    max: 60,
                    onChanged: onBrushSizeChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stroke {
  final Color color;
  final double opacity;
  final double width;
  final bool eraser;
  final List<Offset> points; // normalized [0..1]

  _Stroke({
    required this.color,
    required this.opacity,
    required this.width,
    required this.eraser,
    required this.points,
  });
}

class _CanvasMapping {
  final double boxWidth;
  final double boxHeight;
  final Rect imageRect;

  _CanvasMapping._({
    required this.boxWidth,
    required this.boxHeight,
    required this.imageRect,
  });

  static _CanvasMapping forImage({
    required double imageWidth,
    required double imageHeight,
    required double boxWidth,
    required double boxHeight,
  }) {
    final imageAspect = imageWidth / imageHeight;
    final boxAspect = boxWidth / boxHeight;

    late double drawW;
    late double drawH;
    if (boxAspect > imageAspect) {
      drawH = boxHeight;
      drawW = drawH * imageAspect;
    } else {
      drawW = boxWidth;
      drawH = drawW / imageAspect;
    }

    final left = (boxWidth - drawW) / 2;
    final top = (boxHeight - drawH) / 2;

    return _CanvasMapping._(
      boxWidth: boxWidth,
      boxHeight: boxHeight,
      imageRect: Rect.fromLTWH(left, top, drawW, drawH),
    );
  }

  Offset? toNormalized(Offset local) {
    if (!imageRect.contains(local)) return null;
    final dx = (local.dx - imageRect.left) / imageRect.width;
    final dy = (local.dy - imageRect.top) / imageRect.height;
    return Offset(dx.clamp(0.0, 1.0), dy.clamp(0.0, 1.0));
  }

  Offset toCanvas(Offset normalized) {
    return Offset(
      imageRect.left + normalized.dx * imageRect.width,
      imageRect.top + normalized.dy * imageRect.height,
    );
  }
}

class _RenderPainter extends CustomPainter {
  final ui.Image image;
  final _CanvasMapping mapping;
  final List<_Stroke> strokes;
  final bool showOriginal;

  _RenderPainter({
    required this.image,
    required this.mapping,
    required this.strokes,
    required this.showOriginal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = mapping.imageRect;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.drawImageRect(image, src, dst, Paint());
    if (showOriginal) return;

    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width;

      if (stroke.eraser) {
        paint.blendMode = BlendMode.clear;
        paint.color = Colors.transparent;
      } else {
        paint.blendMode = BlendMode.color;
        paint.color = stroke.color.withValues(alpha: stroke.opacity);
      }

      final path = Path();
      final first = mapping.toCanvas(stroke.points.first);
      path.moveTo(first.dx, first.dy);
      for (final p in stroke.points.skip(1)) {
        final c = mapping.toCanvas(p);
        path.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RenderPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.mapping.imageRect != mapping.imageRect ||
        oldDelegate.strokes.length != strokes.length ||
        oldDelegate.showOriginal != showOriginal;
  }
}

class _DisplayPainter extends CustomPainter {
  final ui.Image image;
  final _CanvasMapping mapping;

  _DisplayPainter({required this.image, required this.mapping});

  @override
  void paint(Canvas canvas, Size size) {
    final dst = mapping.imageRect;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _DisplayPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.mapping.imageRect != mapping.imageRect;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Before / After comparison slider
// ────────────────────────────────────────────────────────────────────────────

class _BeforeAfterSlider extends StatelessWidget {
  final GlobalKey boundaryKey;
  final ui.Image original;
  final ui.Image edited;
  final _CanvasMapping mapping;
  final double sliderX;
  final ValueChanged<double> onSliderChanged;

  const _BeforeAfterSlider({
    required this.boundaryKey,
    required this.original,
    required this.edited,
    required this.mapping,
    required this.sliderX,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dividerX = mapping.imageRect.left + sliderX * mapping.imageRect.width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        final w = mapping.imageRect.width;
        if (w <= 0) return;
        final local = d.localPosition.dx - mapping.imageRect.left;
        onSliderChanged((local / w).clamp(0.0, 1.0));
      },
      onTapDown: (d) {
        final w = mapping.imageRect.width;
        if (w <= 0) return;
        final local = d.localPosition.dx - mapping.imageRect.left;
        onSliderChanged((local / w).clamp(0.0, 1.0));
      },
      child: Stack(
        children: [
          // Canvas
          Positioned.fill(
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: CustomPaint(
                  size: Size(mapping.boxWidth, mapping.boxHeight),
                  painter: _BeforeAfterPainter(
                    original: original,
                    edited: edited,
                    mapping: mapping,
                    sliderX: sliderX,
                  ),
                ),
              ),
            ),
          ),

          // Divider line
          Positioned(
            left: dividerX - 1.5,
            top: mapping.imageRect.top,
            width: 3,
            height: mapping.imageRect.height,
            child: const ColoredBox(color: Colors.white),
          ),

          // Handle circle
          Positioned(
            left: dividerX - 18,
            top: mapping.imageRect.top + mapping.imageRect.height / 2 - 18,
            child: IgnorePointer(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.black26, width: 2),
                  boxShadow: const [
                    BoxShadow(blurRadius: 6, color: Colors.black26),
                  ],
                ),
                child: const Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: Colors.black54,
                ),
              ),
            ),
          ),

          // BEFORE label
          Positioned(
            left: mapping.imageRect.left + 8,
            top: mapping.imageRect.top + 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'BEFORE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),

          // AFTER label
          Positioned(
            right: (mapping.boxWidth - mapping.imageRect.right) + 8,
            top: mapping.imageRect.top + 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC0B163B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AFTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterPainter extends CustomPainter {
  final ui.Image original;
  final ui.Image edited;
  final _CanvasMapping mapping;
  final double sliderX;

  _BeforeAfterPainter({
    required this.original,
    required this.edited,
    required this.mapping,
    required this.sliderX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dst = mapping.imageRect;
    final srcOrig = Rect.fromLTWH(
      0,
      0,
      original.width.toDouble(),
      original.height.toDouble(),
    );
    final srcEdit = Rect.fromLTWH(
      0,
      0,
      edited.width.toDouble(),
      edited.height.toDouble(),
    );

    final splitX = dst.left + sliderX * dst.width;

    // Draw original (left side)
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(dst.left, dst.top, splitX, dst.bottom));
    canvas.drawImageRect(original, srcOrig, dst, Paint());
    canvas.restore();

    // Draw edited (right side)
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(splitX, dst.top, dst.right, dst.bottom));
    canvas.drawImageRect(edited, srcEdit, dst, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeforeAfterPainter old) {
    return old.original != original ||
        old.edited != edited ||
        old.sliderX != sliderX ||
        old.mapping.imageRect != mapping.imageRect;
  }
}
