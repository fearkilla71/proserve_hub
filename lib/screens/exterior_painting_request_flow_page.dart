import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../services/location_service.dart';
import '../utils/pricing_engine.dart';
import '../services/zip_lookup_service.dart';

class ExteriorPaintingRequestFlowPage extends StatefulWidget {
  const ExteriorPaintingRequestFlowPage({super.key});

  @override
  State<ExteriorPaintingRequestFlowPage> createState() =>
      _ExteriorPaintingRequestFlowPageState();
}

class _ExteriorPaintingRequestFlowPageState
    extends State<ExteriorPaintingRequestFlowPage> {
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _homeSqftController = TextEditingController();
  final TextEditingController _deckFenceSqftController =
      TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  int _step = 0;
  bool _submitting = false;
  bool _locating = false;
  bool _uploadingPhoto = false;

  // Step answers
  String? _propertyType; // 'home' | 'business'
  String? _stories; // '1' | '2' | '3_plus'
  String?
  _siding; // 'vinyl' | 'wood' | 'stucco' | 'brick' | 'fiber_cement' | 'other'
  bool _includesPaint = true; // labor + paint by default

  // What to paint (surfaces)
  bool _paintSiding = true;
  bool _paintFascia = false;
  bool _paintSoffit = false;
  bool _paintTrim = false;
  bool _paintGutters = false;

  // Exterior item counters
  int _exteriorDoors = 0;
  int _windows = 0;
  int _shutterPairs = 0;
  int _garageDoors = 0;

  String? _colorFinish; // 'same_color' | 'color_change' | 'flexible'
  String? _timeline; // 'standard' | 'asap' | 'flexible'
  String? _surfaceCondition; // 'good' | 'peeling' | 'cracking' | 'chalking'
  String? _prepWork; // 'minimal' | 'moderate' | 'heavy' | 'not_sure'
  String? _accessibility; // 'easy' | 'tight_spots' | 'steep' | 'landscaping'

  // Photo data — 4 sides
  static const _photoLabels = ['Front', 'Back', 'Left side', 'Right side'];
  final List<String?> _uploadedPaths = [null, null, null, null];
  final List<Uint8List?> _photoThumbnails = [null, null, null, null];

  // Steps: 0=ZIP+sqft, 1=Property type, 2=Stories, 3=Siding,
  //        4=What to paint, 5=Exterior items, 6=Paint supply,
  //        7=Surface condition, 8=Prep work, 9=Color finish,
  //        10=Accessibility, 11=Timeline, 12=Photos
  static const int _totalSteps = 13;

  @override
  void dispose() {
    _zipController.dispose();
    _homeSqftController.dispose();
    _deckFenceSqftController.dispose();
    super.dispose();
  }

  double get _progressValue {
    final denom = (_totalSteps - 1).clamp(1, 9999);
    return (_step / denom).clamp(0.0, 1.0);
  }

  double? _parseNum(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
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

  // ---- Photo capture ----
  Future<void> _takePhoto(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      Uint8List uploadBytes = Uint8List.fromList(await image.readAsBytes());
      if (uploadBytes.isEmpty) throw Exception('Unable to read photo.');

      // Compress if > 1 MB
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
        } catch (_) {}
      }

      final uid = user.uid;
      final now = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'exterior_photos/$uid/${now}_side_$index.jpg';

      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(
        uploadBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (!mounted) return;
      setState(() {
        _uploadedPaths[index] = storagePath;
        _photoThumbnails[index] = uploadBytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  int get _photosUploaded => _uploadedPaths.where((p) => p != null).length;

  bool get _canGoNext {
    switch (_step) {
      case 0: // ZIP + home sqft
        return _zipController.text.trim().isNotEmpty &&
            (_parseNum(_homeSqftController.text) ?? 0) > 0;
      case 1: // Property type
        return _propertyType != null;
      case 2: // Stories
        return _stories != null;
      case 3: // Siding material
        return _siding != null;
      case 4: // What to paint
        return _paintSiding ||
            _paintFascia ||
            _paintSoffit ||
            _paintTrim ||
            _paintGutters;
      case 5: // Exterior items (all optional)
        return true;
      case 6: // Paint supply
        return true;
      case 7: // Surface condition
        return _surfaceCondition != null;
      case 8: // Prep work
        return _prepWork != null;
      case 9: // Color finish
        return _colorFinish != null;
      case 10: // Accessibility
        return _accessibility != null;
      case 11: // Timeline
        return _timeline != null;
      case 12: // Photos
        return _photosUploaded >= 4;
      default:
        return false;
    }
  }

  void _next() {
    if (!_canGoNext) return;
    if (_step >= _totalSteps - 1) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step <= 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
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
    return user.uid;
  }

  String _storiesLabel(String v) {
    switch (v) {
      case '1':
        return '1 story';
      case '2':
        return '2 stories';
      case '3_plus':
        return '3+ stories';
      default:
        return v;
    }
  }

  String _sidingLabel(String v) {
    switch (v) {
      case 'vinyl':
        return 'Vinyl';
      case 'wood':
        return 'Wood';
      case 'stucco':
        return 'Stucco';
      case 'brick':
        return 'Brick';
      case 'fiber_cement':
        return 'Fiber cement (Hardie)';
      case 'other':
        return 'Other';
      default:
        return v;
    }
  }

  String _colorFinishLabel(String v) {
    switch (v) {
      case 'same_color':
        return 'Same color';
      case 'color_change':
        return 'Color change';
      case 'flexible':
        return "I'm flexible";
      default:
        return v;
    }
  }

  String _timelineLabel(String v) {
    switch (v) {
      case 'asap':
        return 'ASAP';
      case 'flexible':
        return "I'm flexible";
      case 'standard':
      default:
        return 'Standard';
    }
  }

  String _surfaceConditionLabel(String v) {
    switch (v) {
      case 'good':
        return 'Good - no peeling/cracking';
      case 'peeling':
        return 'Peeling paint';
      case 'cracking':
        return 'Cracking / flaking';
      case 'chalking':
        return 'Chalking / fading';
      default:
        return v;
    }
  }

  String _prepWorkLabel(String v) {
    switch (v) {
      case 'minimal':
        return 'Minimal (light cleaning)';
      case 'moderate':
        return 'Moderate (scraping, sanding)';
      case 'heavy':
        return 'Heavy (major scraping, caulking, priming)';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _accessibilityLabel(String v) {
    switch (v) {
      case 'easy':
        return 'Easy access all around';
      case 'tight_spots':
        return 'Some tight spots / narrow sides';
      case 'steep':
        return 'Steep slope / hillside';
      case 'landscaping':
        return 'Landscaping / obstacles in the way';
      default:
        return v;
    }
  }

  /// Estimate exterior wall area from home sqft + stories.
  double _estimateExteriorSqft() {
    final homeSqft = _parseNum(_homeSqftController.text) ?? 0;
    if (homeSqft <= 0) return 0;

    final numFloors = _stories == '3_plus'
        ? 3
        : int.tryParse(_stories ?? '1') ?? 1;
    // Perimeter ≈ 4 × √(footprint)
    final footprint = homeSqft / numFloors;
    final perimeter = 4 * _sqrt(footprint);
    // Wall height ~9 ft per floor
    return perimeter * 9.0 * numFloors;
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = await _ensureSignedInCustomerUid();
    if (uid == null) return;

    final zip = _zipController.text.trim();
    final homeSqft = _parseNum(_homeSqftController.text);
    if (zip.isEmpty || homeSqft == null || homeSqft <= 0) return;

    final exteriorSqft = _estimateExteriorSqft();

    final loc = await ZipLookupService.instance.lookup(zip);
    if (loc == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not verify that ZIP code. Please check and try again.',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    String phone = '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data();
      final p = data?['phone'];
      if (p is String) phone = p.trim();
    } catch (_) {}

    if (email.isEmpty && phone.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Please add an email or phone to your account so pros can contact you.',
          ),
        ),
      );
      return;
    }

    final deckFenceSqft = _parseNum(_deckFenceSqftController.text) ?? 0;
    final urgent = _timeline == 'asap';

    final paintingQuestions = <String, dynamic>{
      'scope': 'exterior',
      'exterior_sqft': exteriorSqft,
      'sqft': homeSqft,
      'property_type': _propertyType,
      'stories': _stories,
      'siding': _siding,
      'includes_paint': _includesPaint,
      'what_to_paint': {
        'siding': _paintSiding,
        'fascia': _paintFascia,
        'soffit': _paintSoffit,
        'trim': _paintTrim,
        'gutters': _paintGutters,
      },
      'doors': _exteriorDoors,
      'windows': _windows,
      'shutter_pairs': _shutterPairs,
      'garage_doors': _garageDoors,
      'deck_fence_sqft': deckFenceSqft,
      'color_finish': _colorFinish,
      'timeline': _timeline,
      'surface_condition': _surfaceCondition,
      'prep_work': _prepWork,
      'accessibility': _accessibility,
    };

    // Calculate price client-side.
    final prices = await PricingEngine.calculateExteriorPaintingFromQuestions(
      paintingQuestions: paintingQuestions,
      zip: zip,
      urgent: urgent,
    );
    final budget = (prices['recommended'] ?? 0).toDouble();

    // Build description.
    final surfaces = <String>[];
    if (_paintSiding) surfaces.add('Siding');
    if (_paintFascia) surfaces.add('Fascia');
    if (_paintSoffit) surfaces.add('Soffit');
    if (_paintTrim) surfaces.add('Trim/molding');
    if (_paintGutters) surfaces.add('Gutters');
    final items = <String>[];
    if (_exteriorDoors > 0) items.add('$_exteriorDoors door(s)');
    if (_windows > 0) items.add('$_windows window(s)');
    if (_shutterPairs > 0) items.add('$_shutterPairs shutter pair(s)');
    if (_garageDoors > 0) items.add('$_garageDoors garage door(s)');
    if (deckFenceSqft > 0) {
      items.add('Deck/fence ${deckFenceSqft.round()} sqft');
    }

    final description =
        'Exterior painting\n'
        'Property: ${_propertyType == 'business' ? 'Business' : 'Home'}\n'
        'Home: ${homeSqft.round()} sqft · '
        '${_storiesLabel(_stories ?? '1')}\n'
        'Exterior wall area: ~${exteriorSqft.round()} sqft\n'
        'Siding: ${_sidingLabel(_siding ?? 'other')}\n'
        '${_includesPaint ? 'Labor + paint' : 'Labor only'}\n'
        'Surfaces: ${surfaces.isEmpty ? 'None' : surfaces.join(', ')}\n'
        '${items.isNotEmpty ? 'Extras: ${items.join(', ')}\n' : ''}'
        'Finish: ${_colorFinishLabel(_colorFinish ?? '')}\n'
        'Surface condition: ${_surfaceConditionLabel(_surfaceCondition ?? '')}\n'
        'Prep work: ${_prepWorkLabel(_prepWork ?? '')}\n'
        'Accessibility: ${_accessibilityLabel(_accessibility ?? '')}\n'
        'Timeline: ${_timelineLabel(_timeline ?? 'standard')}';

    try {
      setState(() => _submitting = true);

      final db = FirebaseFirestore.instance;
      String customerName = '';
      String customerAddress = '';
      try {
        final userSnap = await db.collection('users').doc(uid).get();
        final userData = userSnap.data() ?? <String, dynamic>{};
        final profileName = (userData['name'] ?? userData['fullName'] ?? '')
            .toString()
            .trim();
        final authName = (FirebaseAuth.instance.currentUser?.displayName ?? '')
            .toString()
            .trim();
        customerName = profileName.isNotEmpty ? profileName : authName;
        customerAddress = (userData['address'] ?? '').toString().trim();
      } catch (_) {}

      final jobRef = db.collection('job_requests').doc();
      final contactRef = jobRef.collection('private').doc('contact');
      final batch = db.batch();

      batch.set(jobRef, {
        'service': 'Painting',
        'paintingScope': 'exterior',
        'location': 'ZIP $zip',
        'zip': zip,
        'quantity': exteriorSqft,
        'lat': loc['lat'],
        'lng': loc['lng'],
        'urgency': urgent ? 'asap' : 'standard',
        'budget': budget,
        'propertyType': _propertyType == 'business' ? 'Business' : 'Home',
        'description': description,
        'requesterUid': uid,
        'clientId': uid,
        'status': 'open',
        'claimed': false,
        'leadUnlockedBy': null,
        'price': budget,
        'paidBy': <String>[],
        'claimCost': 15,
        'createdAt': FieldValue.serverTimestamp(),
        'paintingQuestions': paintingQuestions,
        'exteriorPhotoPaths': _uploadedPaths.whereType<String>().toList(),
      });

      batch.set(contactRef, {
        if (customerName.isNotEmpty) 'name': customerName,
        'email': email,
        'phone': phone,
        if (customerAddress.isNotEmpty) 'address': customerAddress,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      context.push(
        '/ai-price-offer/${jobRef.id}',
        extra: {
          'service': 'Exterior Painting',
          'zip': zip,
          'quantity': exteriorSqft,
          'urgent': urgent,
          'jobDetails': {
            'propertyType': _propertyType == 'business' ? 'Business' : 'Home',
            'description': description,
            'paintingQuestions': paintingQuestions,
          },
        },
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ──────────── Counter helper ────────────
  Widget _counter({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int max = 100,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Step UI builders ----

  Widget _buildStep0ZipSqft(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Text(
          'Exterior painting estimate',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Answer a few quick questions to get an instant price and match with exterior painting pros near you.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _zipController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'ZIP code',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
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
              _locating ? 'Finding your location...' : 'Use my location',
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'What is the home square footage?',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'We use this together with the number of stories to estimate the exterior wall area.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _homeSqftController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Square footage (sq ft)',
            helperText: 'Example: 2000',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStep1PropertyType(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Is this a home or a business?',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _propertyType,
          onChanged: (v) => setState(() => _propertyType = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Home'),
                value: 'home',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Business'),
                value: 'business',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Stories(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'How many stories?',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Higher homes require taller ladders or scaffolding, which affects pricing.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _stories,
          onChanged: (v) => setState(() => _stories = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('1 story'),
                value: '1',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('2 stories (+25%)'),
                value: '2',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('3+ stories (+50%)'),
                value: '3_plus',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Siding(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'What type of exterior surface?',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Different surfaces require different prep and paint types.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _siding,
          onChanged: (v) => setState(() => _siding = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Vinyl'),
                value: 'vinyl',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Wood'),
                value: 'wood',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Stucco'),
                value: 'stucco',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Brick'),
                value: 'brick',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Fiber cement (Hardie)'),
                value: 'fiber_cement',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Other'),
                value: 'other',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4WhatToPaint(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'What surfaces do you want painted?',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Select all the exterior surfaces you want included.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Siding / walls'),
          subtitle: Text(
            _includesPaint ? '\$2.25/sqft' : '\$1.75/sqft (labor only)',
          ),
          value: _paintSiding,
          onChanged: (v) => setState(() => _paintSiding = v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fascia boards'),
          subtitle: Text(
            'Boards along the roofline — ${_includesPaint ? '\$3.50/sqft' : '\$2.50/sqft'}',
          ),
          value: _paintFascia,
          onChanged: (v) => setState(() => _paintFascia = v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Soffit'),
          subtitle: Text(
            'Underside of roof overhang — ${_includesPaint ? '\$3.50/sqft' : '\$2.50/sqft'}',
          ),
          value: _paintSoffit,
          onChanged: (v) => setState(() => _paintSoffit = v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Trim / molding'),
          subtitle: Text(
            'Window & door trim, corner boards — ${_includesPaint ? '\$4.00/sqft' : '\$2.75/sqft'}',
          ),
          value: _paintTrim,
          onChanged: (v) => setState(() => _paintTrim = v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Gutters & downspouts'),
          subtitle: Text(_includesPaint ? '\$3.50/sqft' : '\$2.50/sqft'),
          value: _paintGutters,
          onChanged: (v) => setState(() => _paintGutters = v ?? false),
        ),
      ],
    );
  }

  Widget _buildStep5ExteriorItems(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Exterior items to paint',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Count each item you want painted. Leave at 0 to skip.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _counter(
          label: 'Exterior doors',
          value: _exteriorDoors,
          onChanged: (v) => setState(() => _exteriorDoors = v),
          helper: _includesPaint ? '\$300 each' : '\$200 each (labor only)',
        ),
        const SizedBox(height: 20),
        _counter(
          label: 'Windows (paint frames & trim)',
          value: _windows,
          onChanged: (v) => setState(() => _windows = v),
          helper: _includesPaint ? '\$50 each' : '\$35 each (labor only)',
        ),
        const SizedBox(height: 20),
        _counter(
          label: 'Shutter pairs',
          value: _shutterPairs,
          onChanged: (v) => setState(() => _shutterPairs = v),
          helper: _includesPaint ? '\$80/pair' : '\$55/pair (labor only)',
        ),
        const SizedBox(height: 20),
        _counter(
          label: 'Garage doors',
          value: _garageDoors,
          onChanged: (v) => setState(() => _garageDoors = v),
          helper: _includesPaint ? '\$300 each' : '\$200 each (labor only)',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _deckFenceSqftController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Deck / fence area (sq ft)',
            helperText:
                '${_includesPaint ? '\$3.00' : '\$2.00'}/sqft • Leave blank to skip',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStep6PaintSupply(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Paint supply',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Do you already have the paint, or would you like the contractor to supply it?',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        RadioGroup<bool>(
          groupValue: _includesPaint,
          onChanged: (v) => setState(() => _includesPaint = v ?? true),
          child: Column(
            children: const [
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: Text('Labor + paint (contractor supplies paint)'),
                value: true,
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: Text('Labor only (I have the paint)'),
                value: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep7SurfaceCondition(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Current surface condition',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us estimate prep work and materials needed.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _surfaceCondition,
          onChanged: (v) => setState(() => _surfaceCondition = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Good — no peeling or cracking'),
                value: 'good',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Peeling paint'),
                value: 'peeling',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Cracking / flaking'),
                value: 'cracking',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Chalking / fading'),
                value: 'chalking',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep8PrepWork(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Expected prep work',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'How much preparation do you think is needed?',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _prepWork,
          onChanged: (v) => setState(() => _prepWork = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Minimal — light cleaning'),
                value: 'minimal',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Moderate — scraping & sanding'),
                value: 'moderate',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Heavy — major scraping, caulking, priming'),
                value: 'heavy',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Not sure'),
                value: 'not_sure',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep9ColorFinish(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Color or finish',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'A color change adds 15% to account for extra coats and prep.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _colorFinish,
          onChanged: (v) => setState(() => _colorFinish = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Same color'),
                value: 'same_color',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Color change (+15%)'),
                value: 'color_change',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text("I'm flexible"),
                value: 'flexible',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep10Accessibility(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Property accessibility',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'How easy is it to access the exterior walls?',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _accessibility,
          onChanged: (v) => setState(() => _accessibility = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Easy access all around'),
                value: 'easy',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Some tight spots / narrow sides'),
                value: 'tight_spots',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Steep slope / hillside'),
                value: 'steep',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Landscaping / obstacles in the way'),
                value: 'landscaping',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep11Timeline(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'How soon do you want to start?',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _timeline,
          onChanged: (v) => setState(() => _timeline = v),
          child: Column(
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('Standard'),
                value: 'standard',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text('ASAP (+25%)'),
                value: 'asap',
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text("I'm flexible"),
                value: 'flexible',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep12Photos(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text(
          'Take photos of each side',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload a photo of each side of the building so contractors can see the job. All 4 sides are required.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ...List.generate(4, (i) {
          final hasPhoto = _uploadedPaths[i] != null;
          final thumbnail = _photoThumbnails[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _uploadingPhoto ? null : () => _takePhoto(i),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhoto
                        ? Colors.green.shade400
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: hasPhoto ? 2 : 1,
                  ),
                  color: hasPhoto
                      ? Colors.green.withValues(alpha: 0.05)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    if (thumbnail != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          thumbnail,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _photoLabels[i],
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasPhoto ? 'Tap to retake' : 'Tap to add photo',
                            style: textTheme.bodySmall?.copyWith(
                              color: hasPhoto
                                  ? Colors.green.shade700
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPhoto)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_uploadingPhoto)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 8),
        Text(
          '$_photosUploaded of 4 photos uploaded',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepBody() {
    final textTheme = Theme.of(context).textTheme;

    switch (_step) {
      case 0:
        return _buildStep0ZipSqft(textTheme);
      case 1:
        return _buildStep1PropertyType(textTheme);
      case 2:
        return _buildStep2Stories(textTheme);
      case 3:
        return _buildStep3Siding(textTheme);
      case 4:
        return _buildStep4WhatToPaint(textTheme);
      case 5:
        return _buildStep5ExteriorItems(textTheme);
      case 6:
        return _buildStep6PaintSupply(textTheme);
      case 7:
        return _buildStep7SurfaceCondition(textTheme);
      case 8:
        return _buildStep8PrepWork(textTheme);
      case 9:
        return _buildStep9ColorFinish(textTheme);
      case 10:
        return _buildStep10Accessibility(textTheme);
      case 11:
        return _buildStep11Timeline(textTheme);
      case 12:
        return _buildStep12Photos(textTheme);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _submitting ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _progressValue),
          Expanded(child: _buildStepBody()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: (_submitting || _uploadingPhoto)
                  ? null
                  : isLast
                  ? (_canGoNext ? _submit : null)
                  : (_canGoNext ? _next : null),
              child: Text(
                _submitting
                    ? 'Submitting...'
                    : _uploadingPhoto
                    ? 'Uploading photo...'
                    : (isLast ? 'See your price' : 'Next'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
