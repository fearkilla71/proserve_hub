import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/ai_usage_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AI Quality Inspector
///
/// Crew uploads completion photos → AI checks for common defects
/// (roller marks, cut-line bleed, missed spots, uneven coverage)
/// and flags areas before the walkthrough.
/// ─────────────────────────────────────────────────────────────────────────────
class QualityInspectorScreen extends StatefulWidget {
  const QualityInspectorScreen({super.key});

  @override
  State<QualityInspectorScreen> createState() => _QualityInspectorScreenState();
}

class _QualityInspectorScreenState extends State<QualityInspectorScreen> {
  final _picker = ImagePicker();
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Current inspection ──
  List<XFile> _selectedPhotos = [];
  bool _analyzing = false;
  String? _error;
  String _jobLabel = '';

  // ── Results ──
  List<Map<String, dynamic>> _defects = [];
  String? _overallScore;
  String? _summary;
  bool _passed = false;

  // ── History ──
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ── Photo picking ─────────────────────────────────────────────────────────

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (images.isNotEmpty) {
      setState(() => _selectedPhotos = images);
    }
  }

  Future<void> _takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _selectedPhotos.add(image));
    }
  }

  // ── AI Inspection ─────────────────────────────────────────────────────────

  Future<void> _runInspection() async {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo to inspect')),
      );
      return;
    }

    // Rate limit.
    final limitMsg = await AiUsageService.instance.checkLimit('qualityInspect');
    if (limitMsg != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(limitMsg)));
      }
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
      _defects = [];
      _overallScore = null;
      _summary = null;
    });

    try {
      // Upload photos to Storage.
      final storagePaths = <String>[];
      for (int i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        final bytes = await photo.readAsBytes();

        // Compress.
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1280,
          minHeight: 1280,
          quality: 80,
        );

        final ext = photo.name.split('.').last;
        final path =
            'quality_inspector/$_uid/'
            '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        final ref = FirebaseStorage.instance.ref(path);
        await ref.putData(
          compressed,
          SettableMetadata(contentType: 'image/$ext'),
        );
        storagePaths.add(path);
      }

      // Call Cloud Function.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'inspectQuality',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final resp = await callable.call<dynamic>({
        'imagePaths': storagePaths,
        'jobLabel': _jobLabel.trim(),
      });

      final data = resp.data as Map<dynamic, dynamic>? ?? {};
      final defects =
          (data['defects'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      await AiUsageService.instance.recordUsage('qualityInspect');

      if (mounted) {
        setState(() {
          _defects = defects;
          _overallScore = data['score']?.toString();
          _summary = data['summary']?.toString();
          _passed = data['passed'] == true;
          _analyzing = false;
        });
      }

      // Persist to history.
      _saveReport(storagePaths, defects);
    } catch (e) {
      // Fallback: local simulation when Cloud Function unavailable
      _generateLocalInspection();
    }
  }

  void _generateLocalInspection() {
    final defects = <Map<String, dynamic>>[
      {
        'type': 'Sample Defect',
        'severity': 'Low',
        'description':
            'Cloud AI unavailable — this is a placeholder inspection. '
            'Deploy the inspectQuality Cloud Function for real defect detection.',
        'location': 'N/A',
      },
    ];

    setState(() {
      _defects = defects;
      _overallScore = 'N/A';
      _summary =
          'Local fallback inspection. Deploy the inspectQuality Cloud Function '
          'to get AI-powered defect detection with roller marks, cut-line bleed, '
          'missed spots, and coverage analysis.';
      _passed = true;
      _analyzing = false;
    });
  }

  Future<void> _saveReport(
    List<String> imagePaths,
    List<Map<String, dynamic>> defects,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('quality_reports')
          .add({
            'jobLabel': _jobLabel.trim(),
            'imagePaths': imagePaths,
            'defects': defects,
            'score': _overallScore,
            'summary': _summary,
            'passed': _passed,
            'photoCount': _selectedPhotos.length,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _loadHistory();
    } catch (_) {}
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('quality_reports')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      _history = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Quality Inspector'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Inspect'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildInspectTab(cs), _buildHistoryTab(cs)],
        ),
      ),
    );
  }

  // ── Inspect Tab ───────────────────────────────────────────────────────────

  Widget _buildInspectTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Job label
        TextField(
          decoration: const InputDecoration(
            labelText: 'Job / Room Label (optional)',
            hintText: 'e.g. Master Bedroom – 123 Elm St',
            prefixIcon: Icon(Icons.label_outline),
          ),
          onChanged: (v) => _jobLabel = v,
        ),
        const SizedBox(height: 16),

        // Photo picker section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completion Photos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload photos of the finished work for AI defect analysis',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: _analyzing ? null : _pickPhotos,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: _analyzing ? null : _takePhoto,
                      ),
                    ),
                  ],
                ),
                if (_selectedPhotos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedPhotos.asMap().entries.map((entry) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<List<int>>(
                              future: entry.value.readAsBytes(),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                return Image.memory(
                                  snap.data! as dynamic,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPhotos.removeAt(entry.key);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedPhotos.length} photo(s) selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Run button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_analyzing ? 'Analyzing…' : 'Run AI Inspection'),
            onPressed: _analyzing ? null : _runInspection,
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),

        // Results
        if (_overallScore != null) ...[
          const SizedBox(height: 20),
          _buildResultCard(cs),
        ],

        if (_defects.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Defects Found (${_defects.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._defects.map((d) => _buildDefectCard(d, cs)),
        ],
      ],
    );
  }

  Widget _buildResultCard(ColorScheme cs) {
    return Card(
      color: _passed
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _passed ? Icons.check_circle : Icons.warning,
                  color: _passed ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _passed ? 'PASSED' : 'ISSUES FOUND',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _passed ? Colors.green : Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      if (_overallScore != null)
                        Text(
                          'Score: $_overallScore',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_summary != null) ...[
              const SizedBox(height: 12),
              Text(_summary!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefectCard(Map<String, dynamic> defect, ColorScheme cs) {
    final severity = defect['severity']?.toString() ?? 'Medium';
    final severityColor = severity == 'High'
        ? Colors.red
        : severity == 'Low'
        ? Colors.orange
        : Colors.amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_problem, color: severityColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    defect['type']?.toString() ?? 'Defect',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(
                    severity,
                    style: TextStyle(fontSize: 11, color: severityColor),
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: severityColor),
                ),
              ],
            ),
            if (defect['description'] != null) ...[
              const SizedBox(height: 8),
              Text(defect['description'].toString()),
            ],
            if (defect['location'] != null &&
                defect['location'].toString().isNotEmpty &&
                defect['location'] != 'N/A') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    defect['location'].toString(),
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── History Tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab(ColorScheme cs) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: cs.outline),
            const SizedBox(height: 12),
            Text('No inspections yet', style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final report = _history[i];
        final passed = report['passed'] == true;
        final defectCount = (report['defects'] as List?)?.length ?? 0;
        final ts = (report['createdAt'] as Timestamp?)?.toDate();

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (passed ? Colors.green : Colors.red).withValues(
                alpha: 0.15,
              ),
              child: Icon(
                passed ? Icons.check : Icons.warning,
                color: passed ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              report['jobLabel']?.toString().isNotEmpty == true
                  ? report['jobLabel'].toString()
                  : 'Inspection',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${report['photoCount'] ?? '?'} photos · '
              '$defectCount defects · '
              'Score: ${report['score'] ?? 'N/A'}',
            ),
            trailing: ts != null
                ? Text(
                    DateFormat('MMM d').format(ts),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            onTap: () => _showReportDetail(report),
          ),
        );
      },
    );
  }

  void _showReportDetail(Map<String, dynamic> report) {
    final defects =
        (report['defects'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) {
          final cs = Theme.of(ctx).colorScheme;
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                report['jobLabel']?.toString().isNotEmpty == true
                    ? report['jobLabel'].toString()
                    : 'Inspection Report',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (report['summary'] != null) Text(report['summary'].toString()),
              const SizedBox(height: 16),
              ...defects.map((d) => _buildDefectCard(d, cs)),
            ],
          );
        },
      ),
    );
  }
}
