import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:proserve_hub/firebase_options.dart';

import '../services/location_service.dart';
import '../utils/platform_file_bytes.dart';

class CustomerAiEstimatorWizardPage extends StatefulWidget {
  final String initialService;

  const CustomerAiEstimatorWizardPage({
    super.key,
    this.initialService = 'painting',
  });

  @override
  State<CustomerAiEstimatorWizardPage> createState() =>
      _CustomerAiEstimatorWizardPageState();
}

class _CustomerAiEstimatorWizardPageState
    extends State<CustomerAiEstimatorWizardPage> {
  final ImagePicker _imagePicker = ImagePicker();
  int _step = 0;
  bool _creatingDraft = false;
  bool _uploading = false;
  bool _estimating = false;
  bool _locating = false;

  String? _estimateId;

  late String _service;
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String _urgency = 'normal';

  // Painting add-ons (matches backend keys in estimateInteriorPaintingRange).
  final TextEditingController _accentWallsController = TextEditingController();
  final TextEditingController _twoToneWallsController = TextEditingController();
  final TextEditingController _trimLinearFeetController =
      TextEditingController();
  final TextEditingController _doorsOneSideController = TextEditingController();
  final TextEditingController _doorsBothSidesController =
      TextEditingController();
  final TextEditingController _doorsFrenchPairController =
      TextEditingController();
  final TextEditingController _doorsClosetSlabController =
      TextEditingController();
  bool _paintCeilings = false;
  String _colorChangeType = 'same_color';

  List<String> _uploadedPaths = <String>[];
  Map<String, dynamic>? _aiResult;
  String? _lastEstimateMode; // 'rough' | 'photo'

  @override
  void initState() {
    super.initState();
    _service = widget.initialService;
    _createDraftEstimate();
  }

  bool _shouldFallbackToHttp(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').toLowerCase();
    if (msg.contains('openai key')) return false;

    // Callable functions for the estimator enforce App Check; if Play Integrity
    // isn't configured/available on-device, we can still use the HTTP endpoints
    // with an ID token.
    if (msg.contains('app check') || msg.contains('appcheck')) return true;
    if (msg.contains('attest') || msg.contains('integrity')) return true;

    // Also fall back if the callable isn't deployed/available.
    if (e.code == 'not-found') return true;

    // Firebase typically uses failed-precondition for App Check enforcement.
    if (e.code == 'failed-precondition') return true;

    // Some platforms surface App Check failures as INTERNAL.
    if (e.code == 'internal') return true;

    return false;
  }

  @override
  void dispose() {
    _zipController.dispose();
    _quantityController.dispose();
    _accentWallsController.dispose();
    _twoToneWallsController.dispose();
    _trimLinearFeetController.dispose();
    _doorsOneSideController.dispose();
    _doorsBothSidesController.dispose();
    _doorsFrenchPairController.dispose();
    _doorsClosetSlabController.dispose();
    super.dispose();
  }

  Future<void> _fillFromLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final result = await LocationService().getCurrentZipAndCity();
      if (!mounted) return;
      if (result == null || result.zip.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read your location.')),
        );
        return;
      }

      _zipController.text = result.zip.trim();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location failed: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<String?> _ensureSignedInUid() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in required.')),
      );
      return null;
    }

    final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
    final looksUnconfigured =
        firebaseOptions.projectId.startsWith('YOUR_') ||
        firebaseOptions.apiKey.startsWith('YOUR_');
    if (looksUnconfigured) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase not configured yet. Run flutterfire configure to generate real firebase_options.dart values.',
          ),
        ),
      );
      return null;
    }

    return user.uid;
  }

  Future<void> _createDraftEstimate() async {
    if (_estimateId != null) return;

    final uid = await _ensureSignedInUid();
    if (uid == null) return;

    setState(() {
      _creatingDraft = true;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection('customer_estimates')
          .doc();
      await ref.set({
        'requesterUid': uid,
        'status': 'draft',
        'service': _service,
        'zip': '',
        'urgency': _urgency,
        'quantity': null,
        'paintingQuestions': {},
        'uploadedImagePaths': <String>[],
        'aiEstimate': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _estimateId = ref.id;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('permission') || msg.contains('denied')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This feature is available for customer accounts. Please sign in as a customer.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start estimate: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _creatingDraft = false;
        });
      }
    }
  }

  int _asInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? 0;
  }

  double? _parseQuantity(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  String _unitForServiceKey(String serviceKey) {
    if (serviceKey == 'painting') return 'sqft';
    if (serviceKey == 'cabinet_painting') return 'sqft';
    if (serviceKey == 'drywall') return 'sqft';
    if (serviceKey == 'pressure_washing') return 'sqft';
    return 'unit';
  }

  Map<String, dynamic> _paintingQuestions() {
    return {
      'scope': _service == 'cabinet_painting' ? 'cabinets' : 'interior',
      'accent_walls': _asInt(_accentWallsController.text),
      'two_tone_walls': _asInt(_twoToneWallsController.text),
      'trim_linear_feet': _asInt(_trimLinearFeetController.text),
      'doors': {
        'standard_one_side': _asInt(_doorsOneSideController.text),
        'standard_both_sides': _asInt(_doorsBothSidesController.text),
        'french_pair': _asInt(_doorsFrenchPairController.text),
        'closet_slab': _asInt(_doorsClosetSlabController.text),
      },
      'paint_ceilings': _paintCeilings,
      'color_change_type': _colorChangeType,
    };
  }

  Future<void> _saveDraftFields() async {
    final id = _estimateId;
    if (id == null) return;

    final quantity = _parseQuantity(_quantityController.text);

    await FirebaseFirestore.instance
        .collection('customer_estimates')
        .doc(id)
        .set({
          'service': _service,
          'zip': _zipController.text.trim(),
          'urgency': _urgency,
          'quantity': quantity,
          'paintingQuestions':
              (_service == 'painting' || _service == 'cabinet_painting')
              ? _paintingQuestions()
              : {},
          'uploadedImagePaths': _uploadedPaths,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> _callEstimateHttp({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }

    final idTokenRaw = await user.getIdToken();
    final idToken = (idTokenRaw ?? '').trim();
    if (idToken.isEmpty) {
      throw Exception('Auth token unavailable');
    }

    final projectId = Firebase.app().options.projectId.trim();
    if (projectId.isEmpty) {
      throw Exception('Firebase projectId missing');
    }

    const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    final uri = useEmulators
        ? Uri.parse(
            'http://localhost:5001/$projectId/us-central1/$functionName',
          )
        : Uri.parse(
            'https://us-central1-$projectId.cloudfunctions.net/$functionName',
          );

    final r = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );

    if (r.statusCode < 200 || r.statusCode >= 300) {
      String message = 'Estimate failed';
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {
        // ignore
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(r.body);
    if (decoded is! Map) {
      throw Exception('Estimate failed');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _generateRoughEstimate() async {
    final messenger = ScaffoldMessenger.of(context);

    final uid = await _ensureSignedInUid();
    if (uid == null) return;

    final quantity = _parseQuantity(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid project size first.')),
      );
      return;
    }

    setState(() {
      _estimating = true;
      _aiResult = null;
      _lastEstimateMode = null;
    });

    try {
      await _saveDraftFields();

      final payload = {
        'service': _service,
        'zip': _zipController.text.trim(),
        'urgency': _urgency,
        'quantity': quantity,
        if (_service == 'painting' || _service == 'cabinet_painting')
          'paintingQuestions': _paintingQuestions(),
      };

      final useCallable =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      Map<String, dynamic> result;
      if (useCallable) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'estimateFromInputs',
          );
          final resp = await callable.call(payload);
          result = (resp.data as Map).cast<String, dynamic>();
        } catch (e) {
          final msg = e.toString().toLowerCase();
          final shouldFallback =
              (e is FirebaseFunctionsException && _shouldFallbackToHttp(e)) ||
              msg.contains('firebase_functions/internal') ||
              msg.contains('[firebase_functions/internal]') ||
              msg.contains('app check') ||
              msg.contains('appcheck') ||
              msg.contains('integrity') ||
              msg.contains('attest');

          if (shouldFallback) {
            result = await _callEstimateHttp(
              functionName: 'estimateFromInputsHttp',
              body: payload,
            );
          } else {
            rethrow;
          }
        }
      } else {
        result = await _callEstimateHttp(
          functionName: 'estimateFromInputsHttp',
          body: payload,
        );
      }

      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _lastEstimateMode = 'rough';
        _step = 3;
      });

      final id = _estimateId;
      if (id != null) {
        await FirebaseFirestore.instance
            .collection('customer_estimates')
            .doc(id)
            .set({
              'aiEstimate': result,
              'aiEstimateMode': 'rough',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Estimate failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _estimating = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhotos() async {
    final messenger = ScaffoldMessenger.of(context);

    final id = _estimateId;
    if (id == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Starting estimate… try again.')),
      );
      return;
    }

    final uid = await _ensureSignedInUid();
    if (uid == null) return;

    final remaining = (10 - _uploadedPaths.length).clamp(0, 10);
    if (remaining == 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can upload up to 10 photos.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final files = result.files.take(remaining).toList();
    setState(() {
      _uploading = true;
      _aiResult = null;
      _lastEstimateMode = null;
    });

    try {
      final storage = FirebaseStorage.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      final uploaded = <String>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final bytes = await readPlatformFileBytes(f);
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Unable to read selected file.');
        }

        Uint8List uploadBytes = Uint8List.fromList(bytes);

        if (uploadBytes.length > 1024 * 1024) {
          try {
            final compressed = await FlutterImageCompress.compressWithList(
              uploadBytes,
              minWidth: 1920,
              minHeight: 1920,
              quality: 85,
              format: CompressFormat.jpeg,
            );
            if (compressed.isNotEmpty &&
                compressed.length < uploadBytes.length) {
              uploadBytes = Uint8List.fromList(compressed);
            }
          } catch (_) {
            // ignore compression failures
          }
        }

        String contentTypeForName(String name) {
          final lower = name.toLowerCase();
          if (lower.endsWith('.png')) return 'image/png';
          if (lower.endsWith('.webp')) return 'image/webp';
          if (lower.endsWith('.gif')) return 'image/gif';
          return 'image/jpeg';
        }

        final safeName = (f.name.isNotEmpty ? f.name : 'photo_$i').replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
        final path = 'estimate_images/$id/$uid/${now}_${i}_$safeName';

        final ref = storage.ref(path);
        await ref.putData(
          uploadBytes,
          SettableMetadata(contentType: contentTypeForName(safeName)),
        );
        uploaded.add(path);
      }

      if (!mounted) return;
      setState(() {
        final merged = <String>[..._uploadedPaths, ...uploaded];
        _uploadedPaths = merged.length <= 10
            ? merged
            : merged.take(10).toList();
      });

      await _saveDraftFields();

      messenger.showSnackBar(
        SnackBar(content: Text('Uploaded ${uploaded.length} photo(s).')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _takeAndUploadPhoto() async {
    final messenger = ScaffoldMessenger.of(context);

    final id = _estimateId;
    if (id == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Starting estimate… try again.')),
      );
      return;
    }

    final uid = await _ensureSignedInUid();
    if (uid == null) return;

    if (_uploadedPaths.length >= 10) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can upload up to 10 photos.')),
      );
      return;
    }

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _uploading = true;
      _aiResult = null;
      _lastEstimateMode = null;
    });

    try {
      final storage = FirebaseStorage.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      Uint8List uploadBytes = Uint8List.fromList(await image.readAsBytes());
      if (uploadBytes.isEmpty) {
        throw Exception('Unable to read captured photo.');
      }

      if (uploadBytes.length > 1024 * 1024) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            uploadBytes,
            minWidth: 1920,
            minHeight: 1920,
            quality: 85,
            format: CompressFormat.jpeg,
          );
          if (compressed.isNotEmpty && compressed.length < uploadBytes.length) {
            uploadBytes = Uint8List.fromList(compressed);
          }
        } catch (_) {
          // ignore compression failures
        }
      }

      String contentTypeForName(String name) {
        final lower = name.toLowerCase();
        if (lower.endsWith('.png')) return 'image/png';
        if (lower.endsWith('.webp')) return 'image/webp';
        if (lower.endsWith('.gif')) return 'image/gif';
        return 'image/jpeg';
      }

      final rawName = (image.name.isNotEmpty)
          ? image.name
          : (image.path.split('/').last.split('\\').last);
      final safeName = (rawName.isNotEmpty ? rawName : 'camera.jpg').replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );

      final index = _uploadedPaths.length;
      final path = 'estimate_images/$id/$uid/${now}_${index}_$safeName';
      final ref = storage.ref(path);
      await ref.putData(
        uploadBytes,
        SettableMetadata(contentType: contentTypeForName(safeName)),
      );

      if (!mounted) return;
      setState(() {
        final merged = <String>[..._uploadedPaths, path];
        _uploadedPaths = merged.length <= 10
            ? merged
            : merged.take(10).toList();
      });

      await _saveDraftFields();

      messenger.showSnackBar(const SnackBar(content: Text('Photo uploaded.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    if (_uploading) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload from gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    if (choice == 'camera') {
      await _takeAndUploadPhoto();
    } else if (choice == 'gallery') {
      await _pickAndUploadPhotos();
    }
  }

  Future<void> _generatePhotoEstimate() async {
    final messenger = ScaffoldMessenger.of(context);

    final id = _estimateId;
    if (id == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Starting estimate… try again.')),
      );
      return;
    }

    final quantity = _parseQuantity(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid project size first.')),
      );
      return;
    }

    if (_uploadedPaths.isEmpty || _uploadedPaths.length > 10) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Upload 1–10 photos first.')),
      );
      return;
    }

    setState(() {
      _estimating = true;
      _aiResult = null;
      _lastEstimateMode = null;
    });

    try {
      await _saveDraftFields();

      final payload = {
        'estimateId': id,
        'service': _service,
        'zip': _zipController.text.trim(),
        'urgency': _urgency,
        'quantity': quantity,
        'unit': _unitForServiceKey(_service),
        'imagePaths': _uploadedPaths,
      };

      final useCallable =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      Map<String, dynamic> result;
      if (useCallable) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'estimateFromImagesInputs',
          );
          final resp = await callable.call(payload);
          result = (resp.data as Map).cast<String, dynamic>();
        } catch (e) {
          final msg = e.toString().toLowerCase();
          final shouldFallback =
              (e is FirebaseFunctionsException && _shouldFallbackToHttp(e)) ||
              msg.contains('firebase_functions/internal') ||
              msg.contains('[firebase_functions/internal]') ||
              msg.contains('app check') ||
              msg.contains('appcheck') ||
              msg.contains('integrity') ||
              msg.contains('attest');

          if (shouldFallback) {
            result = await _callEstimateHttp(
              functionName: 'estimateFromImagesInputsHttp',
              body: payload,
            );
          } else {
            rethrow;
          }
        }
      } else {
        result = await _callEstimateHttp(
          functionName: 'estimateFromImagesInputsHttp',
          body: payload,
        );
      }

      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _lastEstimateMode = 'photo';
        _step = 3;
      });

      await FirebaseFirestore.instance
          .collection('customer_estimates')
          .doc(id)
          .set({
            'aiEstimate': result,
            'aiEstimateMode': 'photo',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } on FirebaseFunctionsException catch (e) {
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('openai key')) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Photo AI is unavailable right now; generating a rough estimate instead.',
            ),
          ),
        );
        await _generateRoughEstimate();
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('openai key')) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Photo AI is unavailable right now; generating a rough estimate instead.',
            ),
          ),
        );
        await _generateRoughEstimate();
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('Estimate failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _estimating = false;
        });
      }
    }
  }

  Widget _estimateResultCard(BuildContext context, Map<String, dynamic> data) {
    final prices = (data['prices'] as Map?)?.cast<String, dynamic>() ?? {};
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    final low = asDouble(prices['low']);
    final rec = asDouble(prices['recommended']);
    final prem = asDouble(prices['premium']);

    final unit = (data['unit'] ?? '').toString();
    final qty = asDouble(data['quantity']);
    final conf = asDouble(data['confidence']);
    final notes = (data['notes'] ?? '').toString();

    final labor = (rec * 0.7).clamp(0, double.infinity);
    final materials = (rec * 0.3).clamp(0, double.infinity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Range: \$${low.toStringAsFixed(0)} – \$${prem.toStringAsFixed(0)}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Recommended: \$${rec.toStringAsFixed(0)}',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Quantity: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1)} $unit',
            ),
            if (conf > 0)
              Text('Confidence: ${(conf * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 12),
            Text(
              'Estimated breakdown',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text('Labor:  \$${labor.toStringAsFixed(0)}'),
            Text('Materials: \$${materials.toStringAsFixed(0)}'),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _serviceStep(BuildContext context) {
    return RadioGroup<String>(
      groupValue: _service,
      onChanged: (v) {
        if (v == null) return;
        setState(() => _service = v);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you need estimated?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const RadioListTile<String>(
            value: 'painting',
            title: Text('Interior Painting'),
          ),
          const RadioListTile<String>(
            value: 'cabinet_painting',
            title: Text('Cabinet Painting'),
          ),
          const RadioListTile<String>(
            value: 'drywall',
            title: Text('Drywall Repair'),
          ),
          const RadioListTile<String>(
            value: 'pressure_washing',
            title: Text('Pressure Washing'),
          ),
        ],
      ),
    );
  }

  Widget _detailsStep(BuildContext context) {
    final unit = _unitForServiceKey(_service);

    Widget numberField(TextEditingController c, String label) {
      return TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _zipController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ZIP code (optional)'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _locating ? null : _fillFromLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _locating ? 'Finding your location…' : 'Use my location',
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _urgency,
          decoration: const InputDecoration(labelText: 'Urgency'),
          items: const [
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'asap', child: Text('ASAP')),
          ],
          onChanged: (v) => setState(() => _urgency = v ?? 'normal'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _service == 'cabinet_painting'
                ? 'Kitchen size ($unit)'
                : 'Project size ($unit)',
            hintText: _service == 'painting'
                ? 'e.g. 1800'
                : (_service == 'cabinet_painting' ? 'e.g. 150' : 'e.g. 250'),
          ),
        ),
        if (_service == 'painting') ...[
          const SizedBox(height: 18),
          Text(
            'Add-ons (optional)',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: numberField(_accentWallsController, 'Accent walls'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: numberField(_twoToneWallsController, 'Two-tone walls'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          numberField(
            _trimLinearFeetController,
            'Trim/baseboards (linear feet)',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _paintCeilings,
            onChanged: (v) => setState(() => _paintCeilings = v),
            title: const Text('Paint ceilings'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _colorChangeType,
            decoration: const InputDecoration(labelText: 'Color change'),
            items: const [
              DropdownMenuItem(value: 'same_color', child: Text('Same color')),
              DropdownMenuItem(
                value: 'light_to_light',
                child: Text('Light → Light'),
              ),
              DropdownMenuItem(
                value: 'dark_to_light',
                child: Text('Dark → Light'),
              ),
              DropdownMenuItem(
                value: 'high_pigment',
                child: Text('High pigment colors'),
              ),
            ],
            onChanged: (v) =>
                setState(() => _colorChangeType = v ?? 'same_color'),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Doors (optional)'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: numberField(
                      _doorsOneSideController,
                      'Standard (one side)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: numberField(
                      _doorsBothSidesController,
                      'Standard (both sides)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: numberField(
                      _doorsFrenchPairController,
                      'French pair',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: numberField(
                      _doorsClosetSlabController,
                      'Closet slab',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ],
    );
  }

  Widget _photosStep(BuildContext context) {
    final canPhotoAi = _uploadedPaths.isNotEmpty && _uploadedPaths.length <= 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (optional)',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload 1–10 photos for a more accurate AI estimate.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(
              _uploadedPaths.isEmpty
                  ? 'No photos uploaded'
                  : 'Uploaded ${_uploadedPaths.length} photo(s)',
            ),
            subtitle: Text(
              _uploadedPaths.isEmpty
                  ? 'Tap to take or upload photos'
                  : 'Tap to add more photos',
            ),
            trailing: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _uploading ? null : _showPhotoSourceSheet,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _estimating ? null : _generateRoughEstimate,
                child: _estimating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate rough estimate'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _estimating || !canPhotoAi
                ? null
                : _generatePhotoEstimate,
            label: const Text('Generate photo AI estimate'),
          ),
        ),
        if (!canPhotoAi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Upload 1–10 photos to enable photo AI.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _estimateStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimate',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (_aiResult == null)
          Text(
            'Generate an estimate to see the breakdown.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          _estimateResultCard(context, _aiResult!),
        const SizedBox(height: 12),
        if (_aiResult != null && _lastEstimateMode != null)
          Text(
            _lastEstimateMode == 'photo'
                ? 'Mode: Photo AI'
                : 'Mode: Rough estimate',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: 16),
        if (_aiResult != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.send),
              onPressed: () {
                final prices = _aiResult!['prices'] as Map<String, dynamic>?;
                final recommended = prices?['recommended']?.toString() ?? '';
                final labels = <String, String>{
                  'painting': 'Interior Painting',
                  'cabinet_painting': 'Cabinet Painting',
                  'drywall': 'Drywall Repair',
                  'pressure_washing': 'Pressure Washing',
                };
                final serviceName = labels[_service] ?? _service;
                final qty = _quantityController.text.trim();
                final zip = _zipController.text.trim();
                final urgent = _urgency == 'rush';

                context.push(
                  '/job-request/$serviceName',
                  extra: <String, dynamic>{
                    'initialZip': zip,
                    'initialQuantity': qty,
                    'initialPrice': recommended,
                    'initialDescription':
                        'AI-estimated $serviceName job — ${_aiResult!['quantity'] ?? qty} ${_aiResult!['unit'] ?? 'units'}',
                    'initialUrgent': urgent,
                  },
                );
              },
              label: const Text('Post as Job Request'),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              context.push('/select-service');
            },
            label: const Text('Start a New Request'),
          ),
        ),
      ],
    );
  }

  void _next() async {
    if (_step >= 3) return;
    if (_creatingDraft) return;
    if (_estimateId == null) {
      await _createDraftEstimate();
      if (_estimateId == null) return;
    }

    setState(() {
      _step += 1;
    });

    try {
      await _saveDraftFields();
    } catch (_) {
      // ignore save failures; user can proceed
    }
  }

  void _back() {
    if (_step <= 0) return;
    setState(() {
      _step -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / 4;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Estimator')),
      body: SafeArea(
        child: _creatingDraft
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: switch (_step) {
                            0 => _serviceStep(context),
                            1 => _detailsStep(context),
                            2 => _photosStep(context),
                            _ => _estimateStep(context),
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _step == 0 ? null : _back,
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _step == 3 ? null : _next,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
