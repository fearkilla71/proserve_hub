import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';

import '../services/location_service.dart';
import '../utils/pricing_engine.dart';
import '../services/zip_lookup_service.dart';
import '../utils/platform_file_bytes.dart';

class PressureWashingRequestFlowPage extends StatefulWidget {
  const PressureWashingRequestFlowPage({super.key});

  @override
  State<PressureWashingRequestFlowPage> createState() =>
      _PressureWashingRequestFlowPageState();
}

class _PressureWashingRequestFlowPageState
    extends State<PressureWashingRequestFlowPage> {
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _uploadingPhotos = false;
  bool _locating = false;

  String? _unit;

  // Step answers
  String? _propertyType; // 'home' | 'business'
  // Areas to wash (checkboxes)
  bool _driveway = false;
  bool _siding = false;
  bool _deckPatio = false;
  bool _fence = false;
  bool _walkways = false;
  bool _poolArea = false;
  bool _garageFloor = false;
  // Surface material (checkboxes)
  bool _surfConcrete = false;
  bool _surfPavers = false;
  bool _surfWood = false;
  bool _surfComposite = false;
  bool _surfVinyl = false;
  bool _surfBrick = false;
  String? _stories; // '1' | '2' | '3_plus' | 'not_sure'
  String? _stains; // 'light' | 'mildew' | 'oil' | 'rust' | 'mixed'
  String?
  _lastCleaned; // 'never' | '1_year' | '2_3_years' | '5_plus' | 'not_sure'
  String? _waterAccess; // 'yes_close' | 'yes_far' | 'not_sure'
  String? _sealAfter; // 'yes' | 'no' | 'not_sure'
  // Additional services (checkboxes)
  bool _gutterCleaning = false;
  bool _windowWashing = false;
  bool _roofCleaning = false;
  String? _timeline; // 'standard' | 'asap' | 'flexible'

  List<PlatformFile> _selectedPhotos = [];

  static const int _totalSteps = 13;

  @override
  void initState() {
    super.initState();
    PricingEngine.getUnit(service: 'Pressure Washing').then((u) {
      if (!mounted) return;
      setState(() => _unit = (u == null || u.trim().isEmpty) ? 'sqft' : u);
    });
  }

  @override
  void dispose() {
    _zipController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  double? _parseNumber(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  double get _progressValue {
    final denom = (_totalSteps - 1).clamp(1, 9999);
    return (_step / denom).clamp(0.0, 1.0);
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

  bool get _canGoNext {
    switch (_step) {
      case 0: // ZIP + size
        return _zipController.text.trim().isNotEmpty &&
            (_parseNumber(_sizeController.text) ?? 0) > 0;
      case 1: // Property type
        return _propertyType != null;
      case 2: // Areas to wash
        return _driveway ||
            _siding ||
            _deckPatio ||
            _fence ||
            _walkways ||
            _poolArea ||
            _garageFloor;
      case 3: // Surface material
        return _surfConcrete ||
            _surfPavers ||
            _surfWood ||
            _surfComposite ||
            _surfVinyl ||
            _surfBrick;
      case 4: // Stories
        return _stories != null;
      case 5: // Stains
        return _stains != null;
      case 6: // Last cleaned
        return _lastCleaned != null;
      case 7: // Water access
        return _waterAccess != null;
      case 8: // Seal after
        return _sealAfter != null;
      case 9: // Additional services
        return true; // optional
      case 10: // Timeline
        return _timeline != null;
      case 11: // Additional notes - skip, use photos
        return true;
      case 12: // Photos (optional)
        return true;
      default:
        return false;
    }
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedPhotos = result.files.take(10).toList();
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
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

  // -- Label helpers --

  String _storiesLabel(String v) {
    switch (v) {
      case '1':
        return '1 story';
      case '2':
        return '2 stories';
      case '3_plus':
        return '3+ stories';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _stainsLabel(String v) {
    switch (v) {
      case 'light':
        return 'Light dirt';
      case 'mildew':
        return 'Mildew / algae';
      case 'oil':
        return 'Oil / heavy stains';
      case 'rust':
        return 'Rust stains';
      case 'mixed':
        return 'Mixed / not sure';
      default:
        return v;
    }
  }

  String _lastCleanedLabel(String v) {
    switch (v) {
      case 'never':
        return 'Never';
      case '1_year':
        return 'Within the last year';
      case '2_3_years':
        return '2-3 years ago';
      case '5_plus':
        return '5+ years ago';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _waterAccessLabel(String v) {
    switch (v) {
      case 'yes_close':
        return 'Yes, within 100 ft';
      case 'yes_far':
        return 'Yes, but farther away';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _sealAfterLabel(String v) {
    switch (v) {
      case 'yes':
        return 'Yes';
      case 'no':
        return 'No';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _labelTimeline(String v) {
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

  // -- Description builder --

  String _buildDescription({
    required String zip,
    required double size,
    required String unit,
    required String propertyTypeLabel,
  }) {
    final surfaces = <String>[];
    if (_driveway) surfaces.add('Driveway');
    if (_walkways) surfaces.add('Walkways');
    if (_siding) surfaces.add('House siding');
    if (_deckPatio) surfaces.add('Deck/Patio');
    if (_fence) surfaces.add('Fence');
    if (_poolArea) surfaces.add('Pool area');
    if (_garageFloor) surfaces.add('Garage floor');

    final materials = <String>[];
    if (_surfConcrete) materials.add('Concrete');
    if (_surfPavers) materials.add('Pavers');
    if (_surfWood) materials.add('Wood');
    if (_surfComposite) materials.add('Composite');
    if (_surfVinyl) materials.add('Vinyl');
    if (_surfBrick) materials.add('Brick');

    final extras = <String>[];
    if (_gutterCleaning) extras.add('Gutter cleaning');
    if (_windowWashing) extras.add('Window washing');
    if (_roofCleaning) extras.add('Roof cleaning');

    return 'Pressure washing\n'
        'Property: $propertyTypeLabel\n'
        'ZIP: $zip\n'
        'Approx size: ${size.toStringAsFixed(0)} $unit\n'
        'Surfaces: ${surfaces.isEmpty ? 'Not specified' : surfaces.join(', ')}\n'
        'Materials: ${materials.isEmpty ? 'Not specified' : materials.join(', ')}\n'
        'Stories: ${_storiesLabel(_stories ?? 'not_sure')}\n'
        'Condition: ${_stainsLabel(_stains ?? '')}\n'
        'Last cleaned: ${_lastCleanedLabel(_lastCleaned ?? '')}\n'
        'Water access: ${_waterAccessLabel(_waterAccess ?? '')}\n'
        'Seal after: ${_sealAfterLabel(_sealAfter ?? '')}\n'
        '${extras.isNotEmpty ? 'Add-ons: ${extras.join(', ')}\n' : ''}'
        'Timeline: ${_labelTimeline(_timeline ?? 'standard')}';
  }

  // -- Submit --

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    final uid = await _ensureSignedInCustomerUid();
    if (uid == null) return;

    final zip = _zipController.text.trim();
    final size = _parseNumber(_sizeController.text);
    final unit = (_unit ?? 'sqft').trim();

    if (zip.isEmpty || size == null || size <= 0) return;

    final List<String> uploadedPaths = [];

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

    double budget = 0;
    try {
      final prices = await PricingEngine.calculate(
        service: 'Pressure Washing',
        quantity: size,
        zip: zip,
        urgent: _timeline == 'asap',
      );
      budget = (prices['recommended'] ?? 0).toDouble();
    } catch (_) {
      budget = 0;
    }

    final propertyTypeLabel = (_propertyType == 'business')
        ? 'Business'
        : 'Home';

    final description = _buildDescription(
      zip: zip,
      size: size,
      unit: unit,
      propertyTypeLabel: propertyTypeLabel,
    );

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

      // Upload photos (optional)
      if (_selectedPhotos.isNotEmpty) {
        setState(() => _uploadingPhotos = true);
        try {
          final storage = FirebaseStorage.instance;
          final now = DateTime.now().millisecondsSinceEpoch;

          for (var i = 0; i < _selectedPhotos.length; i++) {
            final f = _selectedPhotos[i];
            final bytes = await readPlatformFileBytes(f);
            if (bytes == null || bytes.isEmpty) continue;

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
              } catch (_) {}
            }

            String contentTypeForName(String name) {
              final lower = name.toLowerCase();
              if (lower.endsWith('.png')) return 'image/png';
              if (lower.endsWith('.webp')) return 'image/webp';
              if (lower.endsWith('.gif')) return 'image/gif';
              return 'image/jpeg';
            }

            final safeName = (f.name.isNotEmpty ? f.name : 'photo_$i')
                .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
            final path = 'job_images/${jobRef.id}/$uid/${now}_${i}_$safeName';

            final ref = storage.ref(path);
            await ref.putData(
              uploadBytes,
              SettableMetadata(contentType: contentTypeForName(safeName)),
            );
            uploadedPaths.add(path);
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Photo upload failed: $e')),
            );
          }
          return;
        } finally {
          if (mounted) setState(() => _uploadingPhotos = false);
        }
      }

      final batch = db.batch();

      batch.set(jobRef, {
        'service': 'Pressure Washing',
        'location': 'ZIP $zip',
        'zip': zip,
        'quantity': size,
        'lat': loc['lat'],
        'lng': loc['lng'],
        'urgency': _timeline == 'asap' ? 'asap' : 'standard',
        'budget': budget,
        'propertyType': propertyTypeLabel,
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
        if (uploadedPaths.isNotEmpty) 'imagePaths': uploadedPaths,
        'pressureWashingQuestions': {
          'unit': unit,
          'size': size,
          'property_type': _propertyType,
          'surfaces': {
            'driveway': _driveway,
            'walkways': _walkways,
            'siding': _siding,
            'deck_patio': _deckPatio,
            'fence': _fence,
            'pool_area': _poolArea,
            'garage_floor': _garageFloor,
          },
          'surface_materials': {
            'concrete': _surfConcrete,
            'pavers': _surfPavers,
            'wood': _surfWood,
            'composite': _surfComposite,
            'vinyl': _surfVinyl,
            'brick': _surfBrick,
          },
          'stories': _stories,
          'stains': _stains,
          'last_cleaned': _lastCleaned,
          'water_access': _waterAccess,
          'seal_after': _sealAfter,
          'additional_services': {
            'gutter_cleaning': _gutterCleaning,
            'window_washing': _windowWashing,
            'roof_cleaning': _roofCleaning,
          },
          'timeline': _timeline,
        },
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
          'service': 'Pressure Washing',
          'zip': zip,
          'quantity': size,
          'urgent': _timeline == 'asap',
          'jobDetails': {
            'propertyType': propertyTypeLabel,
            'description': description,
          },
        },
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // -- Step bodies --

  Widget _buildStepBody(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unit = (_unit ?? 'sqft').trim();

    switch (_step) {
      // 0 -- ZIP + size
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Pressure washing estimate',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tell us what you want washed so we can match you with local pros.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _zipController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'ZIP code'),
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
            const SizedBox(height: 16),
            Text(
              'Approximate size to be washed',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sizeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Size ($unit)',
                helperText: unit.toLowerCase().contains('sqft')
                    ? 'Example: 1200'
                    : 'Enter a number (example: 8)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );

      // 1 -- Property type
      case 1:
        return _radioList(
          title: 'Is this for a home or a business?',
          groupValue: _propertyType,
          items: const [
            _RadioItem(value: 'home', label: 'Home'),
            _RadioItem(value: 'business', label: 'Business'),
          ],
          onChanged: (v) => setState(() => _propertyType = v),
        );

      // 2 -- Areas to wash
      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'What do you want washed?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select all that apply.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _driveway,
              title: const Text('Driveway'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _driveway = v ?? false),
            ),
            CheckboxListTile(
              value: _walkways,
              title: const Text('Walkways / patio'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _walkways = v ?? false),
            ),
            CheckboxListTile(
              value: _siding,
              title: const Text('House siding'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _siding = v ?? false),
            ),
            CheckboxListTile(
              value: _deckPatio,
              title: const Text('Deck / patio'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _deckPatio = v ?? false),
            ),
            CheckboxListTile(
              value: _fence,
              title: const Text('Fence'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _fence = v ?? false),
            ),
            CheckboxListTile(
              value: _poolArea,
              title: const Text('Pool area'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _poolArea = v ?? false),
            ),
            CheckboxListTile(
              value: _garageFloor,
              title: const Text('Garage floor'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _garageFloor = v ?? false),
            ),
          ],
        );

      // 3 -- Surface material
      case 3:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'What type of surface material?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select all that apply.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _surfConcrete,
              title: const Text('Concrete'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _surfConcrete = v ?? false),
            ),
            CheckboxListTile(
              value: _surfPavers,
              title: const Text('Pavers / stone'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _surfPavers = v ?? false),
            ),
            CheckboxListTile(
              value: _surfWood,
              title: const Text('Wood'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _surfWood = v ?? false),
            ),
            CheckboxListTile(
              value: _surfComposite,
              title: const Text('Composite / Trex'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _surfComposite = v ?? false),
            ),
            CheckboxListTile(
              value: _surfVinyl,
              title: const Text('Vinyl siding'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _surfVinyl = v ?? false),
            ),
            CheckboxListTile(
              value: _surfBrick,
              title: const Text('Brick'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _surfBrick = v ?? false),
            ),
          ],
        );

      // 4 -- Stories
      case 4:
        return _radioList(
          title: 'How many stories is the building?',
          groupValue: _stories,
          items: const [
            _RadioItem(value: '1', label: '1 story'),
            _RadioItem(value: '2', label: '2 stories'),
            _RadioItem(value: '3_plus', label: '3+ stories'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _stories = v),
        );

      // 5 -- Stains
      case 5:
        return _radioList(
          title: 'What kind of staining / condition?',
          groupValue: _stains,
          items: const [
            _RadioItem(value: 'light', label: 'Light dirt'),
            _RadioItem(value: 'mildew', label: 'Mildew / algae'),
            _RadioItem(value: 'oil', label: 'Oil / heavy stains'),
            _RadioItem(value: 'rust', label: 'Rust stains'),
            _RadioItem(value: 'mixed', label: 'Mixed / not sure'),
          ],
          onChanged: (v) => setState(() => _stains = v),
        );

      // 6 -- Last cleaned
      case 6:
        return _radioList(
          title: 'When was this last pressure washed?',
          groupValue: _lastCleaned,
          items: const [
            _RadioItem(value: 'never', label: 'Never'),
            _RadioItem(value: '1_year', label: 'Within the last year'),
            _RadioItem(value: '2_3_years', label: '2-3 years ago'),
            _RadioItem(value: '5_plus', label: '5+ years ago'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _lastCleaned = v),
        );

      // 7 -- Water access
      case 7:
        return _radioList(
          title: 'Is there a water spigot / hose nearby?',
          groupValue: _waterAccess,
          items: const [
            _RadioItem(value: 'yes_close', label: 'Yes, within 100 ft'),
            _RadioItem(value: 'yes_far', label: 'Yes, but farther away'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _waterAccess = v),
        );

      // 8 -- Seal / stain after
      case 8:
        return _radioList(
          title: 'Would you like sealing or staining after washing?',
          groupValue: _sealAfter,
          items: const [
            _RadioItem(value: 'yes', label: 'Yes'),
            _RadioItem(value: 'no', label: 'No'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _sealAfter = v),
        );

      // 9 -- Additional services
      case 9:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'Any additional services?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Optional - select any extras you want.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _gutterCleaning,
              title: const Text('Gutter cleaning'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _gutterCleaning = v ?? false),
            ),
            CheckboxListTile(
              value: _windowWashing,
              title: const Text('Window washing'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _windowWashing = v ?? false),
            ),
            CheckboxListTile(
              value: _roofCleaning,
              title: const Text('Roof cleaning'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roofCleaning = v ?? false),
            ),
          ],
        );

      // 10 -- Timeline
      case 10:
        return _radioList(
          title: 'How soon do you want to start?',
          groupValue: _timeline,
          items: const [
            _RadioItem(value: 'standard', label: 'Standard'),
            _RadioItem(value: 'asap', label: 'ASAP'),
            _RadioItem(value: 'flexible', label: "I'm flexible"),
          ],
          onChanged: (v) => setState(() => _timeline = v),
        );

      // 11 -- Obstacles / access
      case 11:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'Anything we should know about access?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'This helps pros come prepared. Tap Next if none apply.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...[
              'Tight spaces or narrow paths',
              'Landscaping near surfaces',
              'Vehicles or equipment in the way',
              'Steep slope or grading',
              'Gated or restricted access',
            ].map(
              (hint) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(hint, style: const TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      // 12 -- Photos (optional)
      case 12:
        return _buildPhotosStep();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhotosStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Text(
          'Add Photos (Optional)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload photos of the areas to be washed to help contractors provide accurate quotes.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _uploadingPhotos ? null : _pickPhotos,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(
            _selectedPhotos.isEmpty
                ? 'Select Photos'
                : 'Add More Photos (${_selectedPhotos.length}/10)',
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedPhotos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedPhotos.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: file.bytes != null
                          ? Image.memory(file.bytes!, fit: BoxFit.cover)
                          : const Icon(Icons.image, size: 40),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                        onPressed: () => _removePhoto(index),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pressure Washing')),
      body: Stack(
        children: [
          Column(
            children: [
              LinearProgressIndicator(
                value: _progressValue,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              Expanded(child: _buildStepBody(context)),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_submitting || _uploadingPhotos) ? null : _back,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_submitting || _uploadingPhotos)
                        ? null
                        : (_step == _totalSteps - 1
                              ? (_canGoNext ? _submit : null)
                              : (_canGoNext ? _next : null)),
                    child: Text(
                      _uploadingPhotos
                          ? 'Uploading...'
                          : (_submitting
                                ? 'Submitting...'
                                : (_step == _totalSteps - 1
                                      ? 'Submit'
                                      : 'Next')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Shared helpers --

class _RadioItem {
  final String value;
  final String label;

  const _RadioItem({required this.value, required this.label});
}

Widget _radioList({
  required String title,
  required String? groupValue,
  required List<_RadioItem> items,
  required ValueChanged<String?> onChanged,
}) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      RadioGroup<String>(
        groupValue: groupValue,
        onChanged: onChanged,
        child: Column(
          children: [
            ...items.map(
              (it) =>
                  RadioListTile<String>(value: it.value, title: Text(it.label)),
            ),
          ],
        ),
      ),
    ],
  );
}
