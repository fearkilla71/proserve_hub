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

class DrywallRepairRequestFlowPage extends StatefulWidget {
  const DrywallRepairRequestFlowPage({super.key});

  @override
  State<DrywallRepairRequestFlowPage> createState() =>
      _DrywallRepairRequestFlowPageState();
}

class _DrywallRepairRequestFlowPageState
    extends State<DrywallRepairRequestFlowPage> {
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _uploadingPhotos = false;
  bool _locating = false;

  String? _unit;

  // Step answers
  String? _propertyType; // 'home' | 'business'
  String? _repairAreas; // '1' | '2_3' | '4_5' | '6_plus'
  String? _damageType; // 'holes' | 'cracks' | 'water' | 'replace' | 'texture'
  String? _damageSize; // 'small' | 'medium' | 'large' | 'not_sure'
  String? _location; // 'wall' | 'ceiling' | 'both'
  // Which rooms (checkboxes)
  bool _roomKitchen = false;
  bool _roomBathroom = false;
  bool _roomBedroom = false;
  bool _roomLiving = false;
  bool _roomHallway = false;
  bool _roomGarage = false;
  bool _roomOther = false;
  String? _wallHeight; // 'standard' | 'high' | 'stairwell' | 'hard_reach'
  String? _paintAfter; // 'yes' | 'no' | 'not_sure'
  String? _homeAge; // 'new' | '5_20' | '20_plus' | 'not_sure'
  String? _previousRepair; // 'yes' | 'no' | 'not_sure'
  String? _timeline; // 'standard' | 'asap' | 'flexible'

  List<PlatformFile> _selectedPhotos = [];

  static const int _totalSteps = 13;

  @override
  void initState() {
    super.initState();
    PricingEngine.getUnit(service: 'Drywall Repair').then((u) {
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
      case 2: // Number of repair areas
        return _repairAreas != null;
      case 3: // Damage type
        return _damageType != null;
      case 4: // Damage size
        return _damageSize != null;
      case 5: // Location
        return _location != null;
      case 6: // Which rooms
        return _roomKitchen ||
            _roomBathroom ||
            _roomBedroom ||
            _roomLiving ||
            _roomHallway ||
            _roomGarage ||
            _roomOther;
      case 7: // Wall height
        return _wallHeight != null;
      case 8: // Paint after
        return _paintAfter != null;
      case 9: // Home age
        return _homeAge != null;
      case 10: // Previous repair
        return _previousRepair != null;
      case 11: // Timeline
        return _timeline != null;
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

  String _repairAreasLabel(String v) {
    switch (v) {
      case '1':
        return '1 area';
      case '2_3':
        return '2-3 areas';
      case '4_5':
        return '4-5 areas';
      case '6_plus':
        return '6+ areas';
      default:
        return v;
    }
  }

  String _damageLabel(String v) {
    switch (v) {
      case 'holes':
        return 'Holes / dents';
      case 'cracks':
        return 'Cracks / nail pops';
      case 'water':
        return 'Water damage';
      case 'replace':
        return 'Replace drywall sections';
      case 'texture':
        return 'Texture match / skim coat';
      default:
        return v;
    }
  }

  String _damageSizeLabel(String v) {
    switch (v) {
      case 'small':
        return 'Small (under 6 inches)';
      case 'medium':
        return 'Medium (6 inches - 2 feet)';
      case 'large':
        return 'Large (over 2 feet)';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _locationLabel(String v) {
    switch (v) {
      case 'wall':
        return 'Wall';
      case 'ceiling':
        return 'Ceiling';
      case 'both':
        return 'Both';
      default:
        return v;
    }
  }

  String _wallHeightLabel(String v) {
    switch (v) {
      case 'standard':
        return 'Standard (8-10 ft)';
      case 'high':
        return 'High ceilings (10-14 ft)';
      case 'stairwell':
        return 'Stairwell / vaulted';
      case 'hard_reach':
        return 'Hard to reach';
      default:
        return v;
    }
  }

  String _paintAfterLabel(String v) {
    switch (v) {
      case 'yes':
        return 'Yes (include paint)';
      case 'no':
        return 'No (repair only)';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _homeAgeLabel(String v) {
    switch (v) {
      case 'new':
        return 'Less than 5 years';
      case '5_20':
        return '5-20 years';
      case '20_plus':
        return '20+ years';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _previousRepairLabel(String v) {
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
    final rooms = <String>[];
    if (_roomKitchen) rooms.add('Kitchen');
    if (_roomBathroom) rooms.add('Bathroom');
    if (_roomBedroom) rooms.add('Bedroom');
    if (_roomLiving) rooms.add('Living room');
    if (_roomHallway) rooms.add('Hallway');
    if (_roomGarage) rooms.add('Garage');
    if (_roomOther) rooms.add('Other');

    return 'Drywall repair\n'
        'Property: $propertyTypeLabel\n'
        'ZIP: $zip\n'
        'Approx repair size: ${size.toStringAsFixed(0)} $unit\n'
        'Repair areas: ${_repairAreasLabel(_repairAreas ?? '1')}\n'
        'Issue: ${_damageLabel(_damageType ?? '')}\n'
        'Damage size: ${_damageSizeLabel(_damageSize ?? '')}\n'
        'Location: ${_locationLabel(_location ?? '')}\n'
        'Rooms: ${rooms.isEmpty ? 'Not specified' : rooms.join(', ')}\n'
        'Wall height: ${_wallHeightLabel(_wallHeight ?? 'standard')}\n'
        'Paint after: ${_paintAfterLabel(_paintAfter ?? '')}\n'
        'Home age: ${_homeAgeLabel(_homeAge ?? '')}\n'
        'Previous repairs: ${_previousRepairLabel(_previousRepair ?? '')}\n'
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
        service: 'Drywall Repair',
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

      final rooms = <String, bool>{
        'kitchen': _roomKitchen,
        'bathroom': _roomBathroom,
        'bedroom': _roomBedroom,
        'living': _roomLiving,
        'hallway': _roomHallway,
        'garage': _roomGarage,
        'other': _roomOther,
      };

      final batch = db.batch();

      batch.set(jobRef, {
        'service': 'Drywall Repair',
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
        'drywallQuestions': {
          'unit': unit,
          'size': size,
          'property_type': _propertyType,
          'repair_areas': _repairAreas,
          'damage_type': _damageType,
          'damage_size': _damageSize,
          'location': _location,
          'rooms': rooms,
          'wall_height': _wallHeight,
          'paint_after': _paintAfter,
          'home_age': _homeAge,
          'previous_repair': _previousRepair,
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
          'service': 'Drywall Repair',
          'zip': zip,
          'quantity': size,
          'urgent': _timeline == 'asap',
          'jobDetails': {
            'propertyType': propertyTypeLabel,
            'description': description,
            'drywallQuestions': {
              'damage_type': _damageType,
              'damage_size': _damageSize,
              'repair_areas': _repairAreas,
              'location': _location,
              'wall_height': _wallHeight,
              'paint_after': _paintAfter,
              'home_age': _homeAge,
              'timeline': _timeline,
            },
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
              'Drywall repair estimate',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A few quick questions helps us match you with the right drywall pro.',
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
              'Approx repair size',
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
                    ? 'Example: 25'
                    : 'Enter a number (example: 3)',
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

      // 2 -- Number of repair areas
      case 2:
        return _radioList(
          title: 'How many areas need repair?',
          groupValue: _repairAreas,
          items: const [
            _RadioItem(value: '1', label: '1 area'),
            _RadioItem(value: '2_3', label: '2-3 areas'),
            _RadioItem(value: '4_5', label: '4-5 areas'),
            _RadioItem(value: '6_plus', label: '6+ areas'),
          ],
          onChanged: (v) => setState(() => _repairAreas = v),
        );

      // 3 -- Damage type
      case 3:
        return _radioList(
          title: 'What type of drywall issue?',
          groupValue: _damageType,
          items: const [
            _RadioItem(value: 'holes', label: 'Holes / dents'),
            _RadioItem(value: 'cracks', label: 'Cracks / nail pops'),
            _RadioItem(value: 'water', label: 'Water damage'),
            _RadioItem(value: 'replace', label: 'Replace drywall sections'),
            _RadioItem(value: 'texture', label: 'Texture match / skim coat'),
          ],
          onChanged: (v) => setState(() => _damageType = v),
        );

      // 4 -- Damage size
      case 4:
        return _radioList(
          title: 'How big is the damaged area?',
          groupValue: _damageSize,
          items: const [
            _RadioItem(value: 'small', label: 'Small (under 6 inches)'),
            _RadioItem(value: 'medium', label: 'Medium (6 inches - 2 feet)'),
            _RadioItem(value: 'large', label: 'Large (over 2 feet)'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _damageSize = v),
        );

      // 5 -- Location
      case 5:
        return _radioList(
          title: 'Where is the repair?',
          groupValue: _location,
          items: const [
            _RadioItem(value: 'wall', label: 'Wall'),
            _RadioItem(value: 'ceiling', label: 'Ceiling'),
            _RadioItem(value: 'both', label: 'Both'),
          ],
          onChanged: (v) => setState(() => _location = v),
        );

      // 6 -- Which rooms
      case 6:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'Which rooms need repair?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select all that apply.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _roomKitchen,
              title: const Text('Kitchen'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomKitchen = v ?? false),
            ),
            CheckboxListTile(
              value: _roomBathroom,
              title: const Text('Bathroom'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomBathroom = v ?? false),
            ),
            CheckboxListTile(
              value: _roomBedroom,
              title: const Text('Bedroom'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomBedroom = v ?? false),
            ),
            CheckboxListTile(
              value: _roomLiving,
              title: const Text('Living room'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomLiving = v ?? false),
            ),
            CheckboxListTile(
              value: _roomHallway,
              title: const Text('Hallway / stairway'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomHallway = v ?? false),
            ),
            CheckboxListTile(
              value: _roomGarage,
              title: const Text('Garage'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomGarage = v ?? false),
            ),
            CheckboxListTile(
              value: _roomOther,
              title: const Text('Other'),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _roomOther = v ?? false),
            ),
          ],
        );

      // 7 -- Wall height / accessibility
      case 7:
        return _radioList(
          title: 'What is the wall / ceiling height?',
          groupValue: _wallHeight,
          items: const [
            _RadioItem(value: 'standard', label: 'Standard (8-10 ft)'),
            _RadioItem(value: 'high', label: 'High ceilings (10-14 ft)'),
            _RadioItem(value: 'stairwell', label: 'Stairwell / vaulted'),
            _RadioItem(value: 'hard_reach', label: 'Hard to reach'),
          ],
          onChanged: (v) => setState(() => _wallHeight = v),
        );

      // 8 -- Paint after repair
      case 8:
        return _radioList(
          title: 'Do you want it painted after repair?',
          groupValue: _paintAfter,
          items: const [
            _RadioItem(value: 'yes', label: 'Yes (include paint)'),
            _RadioItem(value: 'no', label: 'No (repair only)'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _paintAfter = v),
        );

      // 9 -- Home age
      case 9:
        return _radioList(
          title: 'How old is the home / building?',
          groupValue: _homeAge,
          items: const [
            _RadioItem(value: 'new', label: 'Less than 5 years'),
            _RadioItem(value: '5_20', label: '5-20 years'),
            _RadioItem(value: '20_plus', label: '20+ years'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _homeAge = v),
        );

      // 10 -- Previous repair attempts
      case 10:
        return _radioList(
          title: 'Have there been previous repair attempts?',
          groupValue: _previousRepair,
          items: const [
            _RadioItem(value: 'yes', label: 'Yes'),
            _RadioItem(value: 'no', label: 'No'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _previousRepair = v),
        );

      // 11 -- Timeline
      case 11:
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
          'Upload photos of the damage to help contractors provide accurate quotes.',
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
      appBar: AppBar(title: const Text('Drywall Repair')),
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
