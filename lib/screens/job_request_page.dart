import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:proserve_hub/firebase_options.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';

import '../services/location_service.dart';
import '../utils/pricing_engine.dart';
import '../utils/platform_file_bytes.dart';
import '../utils/zip_locations.dart';
import '../widgets/price_suggestion_card.dart';

class JobRequestPage extends StatefulWidget {
  final String serviceName;
  final String? initialZip;
  final String? initialQuantity;
  final String? initialPrice;
  final String? initialDescription;
  final bool? initialUrgent;

  const JobRequestPage({
    super.key,
    required this.serviceName,
    this.initialZip,
    this.initialQuantity,
    this.initialPrice,
    this.initialDescription,
    this.initialUrgent,
  });

  @override
  State<JobRequestPage> createState() => _JobRequestPageState();
}

class _JobRequestPageState extends State<JobRequestPage> {
  final TextEditingController locationController = TextEditingController();
  final TextEditingController zipController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController contactEmailController = TextEditingController();
  final TextEditingController contactPhoneController = TextEditingController();

  String propertyType = 'House';
  bool isUrgent = false;
  String? pricingUnit;

  String? _jobId;
  bool _submitting = false;
  bool _uploading = false;
  bool _estimating = false;
  List<String> _uploadedPaths = <String>[];
  Map<String, dynamic>? _aiResult;
  bool _locating = false;

  double? _parseQuantity(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // Accept inputs like: "1800", "1800 sqft", "4 rooms".
    // If multiple numbers are present, we use the first one.
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  @override
  void initState() {
    super.initState();

    // Pre-fill from AI estimator if provided
    if (widget.initialZip != null && widget.initialZip!.isNotEmpty) {
      zipController.text = widget.initialZip!;
    }
    if (widget.initialQuantity != null && widget.initialQuantity!.isNotEmpty) {
      quantityController.text = widget.initialQuantity!;
    }
    if (widget.initialPrice != null && widget.initialPrice!.isNotEmpty) {
      priceController.text = widget.initialPrice!;
    }
    if (widget.initialDescription != null &&
        widget.initialDescription!.isNotEmpty) {
      descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialUrgent == true) {
      isUrgent = true;
    }

    PricingEngine.getUnit(service: widget.serviceName).then((unit) {
      if (!mounted) return;
      setState(() => pricingUnit = unit);
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      contactEmailController.text = user!.email!;
    }

    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((
        snap,
      ) {
        if (!mounted) return;
        final data = snap.data();
        final phone = data?['phone'];
        if (phone is String && phone.trim().isNotEmpty) {
          contactPhoneController.text = phone.trim();
        }
      });
    }
  }

  @override
  void dispose() {
    locationController.dispose();
    zipController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
    contactEmailController.dispose();
    contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fillFromLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final result = await LocationService().getCurrentZipAndCity();
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read your location.')),
        );
        return;
      }

      if (result.zip.isNotEmpty) {
        zipController.text = result.zip;
      }
      final cityState = result.formatCityState();
      if (cityState.isNotEmpty) {
        locationController.text = cityState;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location failed: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _showPriceSuggestions() async {
    final messenger = ScaffoldMessenger.of(context);

    final zip = zipController.text.trim();
    if (zip.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a ZIP code first.')),
      );
      return;
    }

    final qtyText = quantityController.text;
    final qty = _parseQuantity(qtyText);
    if (qty == null || qty <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid job size number (e.g., 1800).'),
        ),
      );
      return;
    }

    try {
      final prices = await PricingEngine.calculate(
        service: widget.serviceName,
        quantity: qty,
        zip: zip,
        urgent: isUrgent,
      );

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: false,
        isScrollControlled: false,
        builder: (_) => PriceSuggestionCard(
          prices: prices,
          onSelect: (price) {
            setState(() {
              priceController.text = price.toStringAsFixed(0);
            });
            Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _jobSizeLabel() {
    final unit = pricingUnit;
    if (unit == null || unit.trim().isEmpty) return 'Job Size';
    return 'Job Size ($unit)';
  }

  String _jobSizeHelper() {
    final unit = (pricingUnit ?? '').toLowerCase();
    if (unit.contains('sqft')) {
      return 'Example: 1800 (square feet).';
    }
    if (unit.contains('room')) {
      return 'Example: 4 (rooms).';
    }
    if (unit.contains('wall')) {
      return 'Example: 10 (walls).';
    }
    return 'Enter one number (example: 1800, 4, or 3.5).';
  }

  Future<String?> _ensureSignedInCustomerUid() async {
    final messenger = ScaffoldMessenger.of(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please create an account or sign in first.'),
        ),
      );
      return null;
    }

    final profileSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final profile = profileSnap.data();
    final role = (profile?['role'] as String?)?.trim().toLowerCase();
    if (role != 'customer') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Only customer accounts can submit job requests.'),
        ),
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

  Future<void> _pickAndUploadPhotos() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_jobId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Submit the request first, then upload photos for an AI estimate.',
          ),
        ),
      );
      return;
    }

    final uid = await _ensureSignedInCustomerUid();
    if (uid == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final files = result.files.take(10).toList();
    setState(() {
      _uploading = true;
      _aiResult = null;
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
        final path = 'job_images/${_jobId!}/$uid/${now}_${i}_$safeName';

        final ref = storage.ref(path);
        await ref.putData(
          uploadBytes,
          SettableMetadata(contentType: contentTypeForName(safeName)),
        );
        uploaded.add(path);
      }

      if (!mounted) return;
      setState(() {
        _uploadedPaths = uploaded;
      });

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

  Future<void> _generateAiEstimate() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_jobId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Submit the request first, then generate an AI estimate.',
          ),
        ),
      );
      return;
    }

    final hasEnoughPhotosForPhotoAi =
        _uploadedPaths.length >= 3 && _uploadedPaths.length <= 10;

    setState(() {
      _estimating = true;
      _aiResult = null;
    });

    try {
      final useCallable =
          kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      if (useCallable) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            hasEnoughPhotosForPhotoAi ? 'estimateJobFromImages' : 'estimateJob',
          );
          final payload = {
            'jobId': _jobId,
            if (hasEnoughPhotosForPhotoAi) 'imagePaths': _uploadedPaths,
          };
          final resp = await callable.call(payload);

          if (!mounted) return;
          setState(() {
            _aiResult = (resp.data as Map).cast<String, dynamic>();
          });
          return;
        } on FirebaseFunctionsException catch (e) {
          final message = (e.message ?? '').toLowerCase();
          final canFallback =
              hasEnoughPhotosForPhotoAi &&
              message.contains('openai key') &&
              _jobId != null;
          if (!canFallback) rethrow;

          // Fallback: rough estimate (no photos).
          final fallback = FirebaseFunctions.instance.httpsCallable(
            'estimateJob',
          );
          final resp = await fallback.call({'jobId': _jobId});
          if (!mounted) return;
          setState(() {
            _aiResult = (resp.data as Map).cast<String, dynamic>();
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Photo AI is unavailable right now; used a rough estimate instead.',
              ),
            ),
          );
          return;
        }
      }

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
              hasEnoughPhotosForPhotoAi
                  ? 'http://localhost:5001/$projectId/us-central1/estimateJobFromImagesHttp'
                  : 'http://localhost:5001/$projectId/us-central1/estimateJobHttp',
            )
          : Uri.parse(
              hasEnoughPhotosForPhotoAi
                  ? 'https://us-central1-$projectId.cloudfunctions.net/estimateJobFromImagesHttp'
                  : 'https://us-central1-$projectId.cloudfunctions.net/estimateJobHttp',
            );

      Future<Map<String, dynamic>> postEstimate(Uri target, Map body) async {
        final r = await http.post(
          target,
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

      final respDecoded =
          await postEstimate(uri, {
            'jobId': _jobId,
            if (hasEnoughPhotosForPhotoAi) 'imagePaths': _uploadedPaths,
          }).catchError((e) async {
            final msg = e.toString().toLowerCase();
            final canFallback =
                hasEnoughPhotosForPhotoAi && msg.contains('openai key');
            if (!canFallback) throw e;

            final fallbackUri = useEmulators
                ? Uri.parse(
                    'http://localhost:5001/$projectId/us-central1/estimateJobHttp',
                  )
                : Uri.parse(
                    'https://us-central1-$projectId.cloudfunctions.net/estimateJobHttp',
                  );

            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Photo AI is unavailable; using rough estimate instead.',
                ),
              ),
            );

            return await postEstimate(fallbackUri, {'jobId': _jobId});
          });

      if (!mounted) return;
      setState(() {
        _aiResult = respDecoded;
      });
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

  Widget _aiEstimateResult(BuildContext context, Map<String, dynamic> data) {
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

    // Simple, deterministic line-items breakdown for display.
    // Keeps UX consistent even if the backend doesn't return a breakdown.
    final labor = (rec * 0.7).clamp(0, double.infinity);
    final materials = (rec * 0.3).clamp(0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimated Range: \$${low.toStringAsFixed(0)} – \$${prem.toStringAsFixed(0)}',
        ),
        Text('Midpoint: \$${rec.toStringAsFixed(0)}'),
        const SizedBox(height: 6),
        Text(
          'Assumed: ${qty.toStringAsFixed(0)} ${unit.isEmpty ? "units" : unit}',
        ),
        Text('Confidence: ${(conf * 100).toStringAsFixed(0)}%'),
        const SizedBox(height: 8),
        Text('Line items', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('Labor: \$${labor.toStringAsFixed(0)}'),
        Text('Materials: \$${materials.toStringAsFixed(0)}'),
        if (notes.isNotEmpty) Text('Notes: $notes'),
        const SizedBox(height: 6),
        Text(
          'Contractor may adjust after inspection.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: rec > 0
                ? () {
                    setState(() {
                      priceController.text = rec.toStringAsFixed(0);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Applied AI recommended price.'),
                      ),
                    );
                  }
                : null,
            child: const Text('Use AI Recommended Price'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.serviceName} Request')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            if (_jobId != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Request created. Add photos for an AI estimate (optional).',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'City (optional)'),
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
            const SizedBox(height: 16),
            TextField(
              controller: zipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ZIP Code'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: propertyType,
              decoration: const InputDecoration(labelText: 'Property Type'),
              items: const [
                DropdownMenuItem(value: 'House', child: Text('House')),
                DropdownMenuItem(value: 'Apartment', child: Text('Apartment')),
                DropdownMenuItem(
                  value: 'Commercial',
                  child: Text('Commercial'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  propertyType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Describe the job'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _jobSizeLabel(),
                helperText: _jobSizeHelper(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Urgent (same-day)'),
              value: isUrgent,
              onChanged: (v) => setState(() => isUrgent = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Budget / Price (USD)',
                helperText:
                    'Use “Suggest Prices” so you don’t have to guess. You can update this after an AI estimate too.',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showPriceSuggestions,
                child: const Text('Suggest Prices'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimate',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _jobId == null
                          ? 'Submit the request first, then generate an estimate.'
                          : (_uploadedPaths.isEmpty
                                ? 'Generate a rough estimate now, or upload 3–10 photos to improve it.'
                                : 'Uploaded ${_uploadedPaths.length} photo(s).'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_jobId == null || _uploading)
                                ? null
                                : _pickAndUploadPhotos,
                            child: Text(
                              _uploading ? 'Uploading…' : 'Upload Photos',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                (_jobId == null || _estimating || _uploading)
                                ? null
                                : _generateAiEstimate,
                            child: Text(
                              _estimating ? 'Estimating…' : 'Generate Estimate',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_aiResult != null) ...[
                      const SizedBox(height: 12),
                      _aiEstimateResult(context, _aiResult!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contactEmailController,
              decoration: const InputDecoration(labelText: 'Contact Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contactPhoneController,
              decoration: const InputDecoration(labelText: 'Contact Phone'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);

                        final location = locationController.text.trim();
                        final zip = zipController.text.trim();
                        final description = descriptionController.text.trim();
                        final quantityText = quantityController.text.trim();
                        final priceText = priceController.text.trim();
                        final contactEmail = contactEmailController.text.trim();
                        final contactPhone = contactPhoneController.text.trim();

                        final uid = await _ensureSignedInCustomerUid();
                        if (uid == null) return;

                        if (zip.isEmpty || description.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter ZIP and job description.',
                              ),
                            ),
                          );
                          return;
                        }

                        final quantity = _parseQuantity(quantityText);
                        if (quantity == null || quantity <= 0) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid job size number (e.g., 1800).',
                              ),
                            ),
                          );
                          return;
                        }

                        final zipKey = zip.trim();
                        final loc = zipLocations[zipKey];
                        if (loc == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ZIP not supported yet for smart matching. Add it to zip_locations.dart.',
                              ),
                            ),
                          );
                          return;
                        }

                        final price = double.tryParse(priceText);
                        if (price == null || price <= 0) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please choose a price (tap “Suggest Prices”).',
                              ),
                            ),
                          );
                          return;
                        }

                        if (contactEmail.isEmpty && contactPhone.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please provide an email or phone so contractors can contact you.',
                              ),
                            ),
                          );
                          return;
                        }

                        try {
                          setState(() => _submitting = true);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Submitting...')),
                          );

                          debugPrint('Submitting Firestore write...');

                          final db = FirebaseFirestore.instance;
                          final jobRef = _jobId == null
                              ? db.collection('job_requests').doc()
                              : db.collection('job_requests').doc(_jobId);
                          final contactRef = jobRef
                              .collection('private')
                              .doc('contact');

                          final batch = db.batch();

                          batch.set(jobRef, {
                            'service': widget.serviceName,
                            'location': location,
                            'zip': zip,
                            'quantity': quantity,
                            // Smart matching foundation fields.
                            'lat': loc['lat'],
                            'lng': loc['lng'],
                            'urgency': isUrgent ? 'asap' : 'standard',
                            'budget': price,
                            'propertyType': propertyType,
                            'description': description,
                            'requesterUid': uid,
                            'clientId': uid,
                            'status': 'open',
                            'claimed': false,
                            'leadUnlockedBy': null,
                            'price': price,

                            // Phase 1 lead unlock legacy fields (kept for backward compatibility).
                            'paidBy': <String>[],
                            'claimCost': 15,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          batch.set(contactRef, {
                            'email': contactEmail,
                            'phone': contactPhone,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          await batch.commit();

                          debugPrint('Firestore write success: ${jobRef.id}');

                          if (!mounted) return;

                          setState(() {
                            _jobId = jobRef.id;
                          });

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Request submitted. Upload photos for an AI estimate (optional).',
                              ),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Firestore submit error: $e');
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                child: const Text('Submit Request'),
              ),
            ),
            if (_jobId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    context.push('/recommended/$_jobId');
                  },
                  child: const Text('See Recommended Pros'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
