import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';

import '../services/location_service.dart';
import '../utils/pricing_engine.dart';
import '../services/zip_lookup_service.dart';
import '../utils/platform_file_bytes.dart';

class CabinetRequestFlowPage extends StatefulWidget {
  const CabinetRequestFlowPage({super.key});

  @override
  State<CabinetRequestFlowPage> createState() => _CabinetRequestFlowPageState();
}

class _CabinetRequestFlowPageState extends State<CabinetRequestFlowPage> {
  final TextEditingController _zipController = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _uploadingPhotos = false;
  bool _locating = false;

  // Step answers
  String? _propertyType; // 'home' | 'business'
  String? _area; // 'kitchen' | 'bath' | 'laundry' | 'other'
  String? _workType; // 'paint' | 'refinish' | 'not_sure'
  String? _colorChange; // 'same' | 'change' | 'not_sure'
  String? _timeline; // 'standard' | 'asap' | 'flexible'

  // Door, drawer & cabinet counters
  int _cabinetDoors = 0;
  int _cabinetDrawers = 0;
  int _cabinetCount = 0;

  // Add-on toggles
  bool _paintInteriors = false;
  bool _crownMolding = false;
  bool _hardwareReinstall = false;
  bool _hasIsland = false;

  // New questions
  String?
  _cabinetMaterial; // 'wood' | 'mdf' | 'laminate' | 'thermofoil' | 'other'
  String? _cabinetCondition; // 'good' | 'fair' | 'poor' | 'not_sure'
  bool _glassInserts = false;
  bool _pullOutShelves = false;
  bool _lazySusan = false;
  bool _openShelving = false;

  List<PlatformFile> _selectedPhotos = [];

  // Steps: 0=ZIP, 1=Property type, 2=Area, 3=Work type,
  //        4=Doors & drawers, 5=Cabinets, 6=Add-ons,
  //        7=Cabinet material, 8=Cabinet condition, 9=Special features,
  //        10=Color change, 11=Timeline, 12=Photos
  static const int _totalSteps = 13;

  @override
  void dispose() {
    _zipController.dispose();
    super.dispose();
  }

  bool get _canGoNext {
    switch (_step) {
      case 0: // ZIP
        return _zipController.text.trim().isNotEmpty;
      case 1: // Property type
        return _propertyType != null;
      case 2: // Area
        return _area != null;
      case 3: // Work type
        return _workType != null;
      case 4: // Doors & drawers
        return _cabinetDoors > 0;
      case 5: // Cabinets
        return _cabinetCount > 0;
      case 6: // Add-ons
        return true;
      case 7: // Cabinet material
        return _cabinetMaterial != null;
      case 8: // Cabinet condition
        return _cabinetCondition != null;
      case 9: // Special features (checkboxes — always valid)
        return true;
      case 10: // Color change
        return _colorChange != null;
      case 11: // Timeline
        return _timeline != null;
      case 12: // Photos (optional)
        return true;
      default:
        return false;
    }
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

  double get _progressValue {
    final denom = (_totalSteps - 1).clamp(1, 9999);
    return (_step / denom).clamp(0.0, 1.0);
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
    setState(() => _selectedPhotos.removeAt(index));
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

  String _labelArea(String v) {
    switch (v) {
      case 'kitchen':
        return 'Kitchen';
      case 'bath':
        return 'Bathroom';
      case 'laundry':
        return 'Laundry / Utility';
      case 'other':
        return 'Other';
      default:
        return v;
    }
  }

  String _labelWorkType(String v) {
    switch (v) {
      case 'paint':
        return 'Paint cabinets';
      case 'refinish':
        return 'Refinish / stain';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _labelColorChange(String v) {
    switch (v) {
      case 'same':
        return 'Same color';
      case 'change':
        return 'Change color';
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

  String _labelMaterial(String v) {
    switch (v) {
      case 'wood':
        return 'Solid wood';
      case 'mdf':
        return 'MDF';
      case 'laminate':
        return 'Laminate';
      case 'thermofoil':
        return 'Thermofoil / vinyl wrap';
      case 'other':
        return 'Other / not sure';
      default:
        return v;
    }
  }

  String _labelCondition(String v) {
    switch (v) {
      case 'good':
        return 'Good — solid, no damage';
      case 'fair':
        return 'Fair — minor wear';
      case 'poor':
        return 'Poor — peeling, damage, water marks';
      case 'not_sure':
        return 'Not sure';
      default:
        return v;
    }
  }

  String _buildDescription({
    required String zip,
    required String propertyTypeLabel,
  }) {
    final addons = <String>[];
    if (_paintInteriors) addons.add('Paint interiors');
    if (_crownMolding) addons.add('Crown molding');
    if (_hardwareReinstall) addons.add('Hardware reinstall');
    if (_hasIsland) addons.add('Island');

    final specials = <String>[];
    if (_glassInserts) specials.add('Glass inserts');
    if (_pullOutShelves) specials.add('Pull-out shelves');
    if (_lazySusan) specials.add('Lazy Susan');
    if (_openShelving) specials.add('Open shelving');

    return 'Cabinet project\n'
        'Property: $propertyTypeLabel\n'
        'Area: ${_labelArea(_area ?? '')}\n'
        'Work type: ${_labelWorkType(_workType ?? '')}\n'
        'Cabinet doors: $_cabinetDoors\n'
        'Drawers: $_cabinetDrawers\n'
        'Cabinets: $_cabinetCount\n'
        'Material: ${_labelMaterial(_cabinetMaterial ?? '')}\n'
        'Condition: ${_labelCondition(_cabinetCondition ?? '')}\n'
        'Color: ${_labelColorChange(_colorChange ?? '')}\n'
        '${addons.isNotEmpty ? 'Add-ons: ${addons.join(', ')}\n' : ''}'
        '${specials.isNotEmpty ? 'Special features: ${specials.join(', ')}\n' : ''}'
        'Timeline: ${_labelTimeline(_timeline ?? 'standard')}';
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    final uid = await _ensureSignedInCustomerUid();
    if (uid == null) return;

    final zip = _zipController.text.trim();
    if (zip.isEmpty || _cabinetDoors <= 0) return;

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

    final cabinetQuestions = <String, dynamic>{
      'property_type': _propertyType,
      'area': _area,
      'work_type': _workType,
      'color_change': _colorChange,
      'cabinet_doors': _cabinetDoors,
      'cabinet_drawers': _cabinetDrawers,
      'cabinet_count': _cabinetCount,
      'paint_interiors': _paintInteriors,
      'crown_molding': _crownMolding,
      'hardware_reinstall': _hardwareReinstall,
      'has_island': _hasIsland,
      'cabinet_material': _cabinetMaterial,
      'cabinet_condition': _cabinetCondition,
      'special_features': {
        'glass_inserts': _glassInserts,
        'pull_out_shelves': _pullOutShelves,
        'lazy_susan': _lazySusan,
        'open_shelving': _openShelving,
      },
      'timeline': _timeline,
    };

    // Calculate price using the dedicated cabinet calculator.
    final prices = await PricingEngine.calculateCabinetFromQuestions(
      cabinetQuestions: cabinetQuestions,
      zip: zip,
      urgent: _timeline == 'asap',
    );
    final budget = (prices['recommended'] ?? 0).toDouble();

    final propertyTypeLabel = (_propertyType == 'business')
        ? 'Business'
        : 'Home';
    final description = _buildDescription(
      zip: zip,
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

            final safeName = (f.name.isNotEmpty ? f.name : 'photo_$i')
                .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
            final path = 'job_images/${jobRef.id}/$uid/${now}_${i}_$safeName';

            final ref = storage.ref(path);
            await ref.putData(
              uploadBytes,
              SettableMetadata(contentType: 'image/jpeg'),
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
        'service': 'Cabinets',
        'location': 'ZIP $zip',
        'zip': zip,
        'quantity': _cabinetDoors.toDouble(),
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
        'cabinetQuestions': cabinetQuestions,
        if (uploadedPaths.isNotEmpty) 'cabinetPhotoPaths': uploadedPaths,
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
          'service': 'Cabinets',
          'zip': zip,
          'quantity': _cabinetDoors.toDouble(),
          'urgent': _timeline == 'asap',
          'jobDetails': {
            'propertyType': propertyTypeLabel,
            'description': description,
            'cabinetQuestions': cabinetQuestions,
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

  // ──────────── Step Builders ────────────
  Widget _buildStepBody(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    switch (_step) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Cabinet estimate',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Answer a few quick questions to get an instant price and match with cabinet pros near you.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _zipController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
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
                  _locating ? 'Finding your location…' : 'Use my location',
                ),
              ),
            ),
          ],
        );

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

      case 2:
        return _radioList(
          title: 'Where are the cabinets?',
          groupValue: _area,
          items: const [
            _RadioItem(value: 'kitchen', label: 'Kitchen'),
            _RadioItem(value: 'bath', label: 'Bathroom'),
            _RadioItem(value: 'laundry', label: 'Laundry / utility'),
            _RadioItem(value: 'other', label: 'Other'),
          ],
          onChanged: (v) => setState(() => _area = v),
        );

      case 3:
        return _radioList(
          title: 'What type of work?',
          groupValue: _workType,
          items: const [
            _RadioItem(value: 'paint', label: 'Paint cabinets'),
            _RadioItem(value: 'refinish', label: 'Refinish / stain'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _workType = v),
        );

      case 4: // Doors & drawers
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'How many cabinet doors & drawers?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Count every individual door and drawer front. '
              'A typical kitchen has 20–30 doors and 5–10 drawers.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _counter(
              label: 'Cabinet doors',
              value: _cabinetDoors,
              onChanged: (v) => setState(() => _cabinetDoors = v),
              helper: 'Count upper + lower doors',
            ),
            const SizedBox(height: 20),
            _counter(
              label: 'Drawer fronts',
              value: _cabinetDrawers,
              onChanged: (v) => setState(() => _cabinetDrawers = v),
              helper: 'Count each individual drawer',
            ),
          ],
        );

      case 5: // Cabinet count
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'How many cabinets are there?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Count each separate cabinet box/unit (upper and lower). '
              'A typical kitchen has 15–25 cabinets.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _counter(
              label: 'Number of cabinets',
              value: _cabinetCount,
              onChanged: (v) => setState(() => _cabinetCount = v),
              helper: 'Count each individual cabinet box',
            ),
          ],
        );

      case 6: // Add-ons
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'Any extras?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text('Select any add-ons that apply.', style: textTheme.bodyMedium),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Paint cabinet interiors'),
              subtitle: Text(
                _workType == 'refinish' ? '+\$180/cabinet' : '+\$150/cabinet',
              ),
              value: _paintInteriors,
              onChanged: (v) => setState(() => _paintInteriors = v),
            ),
            SwitchListTile(
              title: const Text('Crown molding'),
              subtitle: const Text('+\$200'),
              value: _crownMolding,
              onChanged: (v) => setState(() => _crownMolding = v),
            ),
            SwitchListTile(
              title: const Text('Hardware removal & reinstall'),
              subtitle: const Text('+\$5/door'),
              value: _hardwareReinstall,
              onChanged: (v) => setState(() => _hardwareReinstall = v),
            ),
            SwitchListTile(
              title: const Text('Kitchen island'),
              subtitle: const Text('+\$250'),
              value: _hasIsland,
              onChanged: (v) => setState(() => _hasIsland = v),
            ),
          ],
        );

      case 7: // Cabinet material
        return _radioList(
          title: 'What material are your cabinets?',
          groupValue: _cabinetMaterial,
          items: const [
            _RadioItem(value: 'wood', label: 'Solid wood'),
            _RadioItem(value: 'mdf', label: 'MDF'),
            _RadioItem(value: 'laminate', label: 'Laminate'),
            _RadioItem(value: 'thermofoil', label: 'Thermofoil / vinyl wrap'),
            _RadioItem(value: 'other', label: 'Other / not sure'),
          ],
          onChanged: (v) => setState(() => _cabinetMaterial = v),
        );

      case 8: // Cabinet condition
        return _radioList(
          title: 'Current cabinet condition?',
          groupValue: _cabinetCondition,
          items: const [
            _RadioItem(value: 'good', label: 'Good — solid, no damage'),
            _RadioItem(value: 'fair', label: 'Fair — minor wear'),
            _RadioItem(
              value: 'poor',
              label: 'Poor — peeling, damage, water marks',
            ),
            _RadioItem(value: 'not_sure', label: 'Not sure'),
          ],
          onChanged: (v) => setState(() => _cabinetCondition = v),
        );

      case 9: // Special features (checkboxes)
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'Any special cabinet features?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These may require extra care during painting or refinishing.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Glass inserts'),
              subtitle: const Text('Doors with glass panels'),
              value: _glassInserts,
              onChanged: (v) => setState(() => _glassInserts = v),
            ),
            SwitchListTile(
              title: const Text('Pull-out shelves'),
              subtitle: const Text('Sliding / roll-out trays'),
              value: _pullOutShelves,
              onChanged: (v) => setState(() => _pullOutShelves = v),
            ),
            SwitchListTile(
              title: const Text('Lazy Susan'),
              subtitle: const Text('Corner rotating shelves'),
              value: _lazySusan,
              onChanged: (v) => setState(() => _lazySusan = v),
            ),
            SwitchListTile(
              title: const Text('Open shelving'),
              subtitle: const Text('Shelves without doors'),
              value: _openShelving,
              onChanged: (v) => setState(() => _openShelving = v),
            ),
          ],
        );

      case 10:
        return _radioList(
          title: 'Are you changing cabinet color?',
          groupValue: _colorChange,
          items: const [
            _RadioItem(value: 'same', label: 'Same color'),
            _RadioItem(value: 'change', label: 'Change color (+15%)'),
            _RadioItem(value: 'not_sure', label: "I'm not sure"),
          ],
          onChanged: (v) => setState(() => _colorChange = v),
        );

      case 11:
        return _radioList(
          title: 'How soon do you want to start?',
          groupValue: _timeline,
          items: const [
            _RadioItem(value: 'standard', label: 'Standard'),
            _RadioItem(value: 'asap', label: 'ASAP (+25%)'),
            _RadioItem(value: 'flexible', label: "I'm flexible"),
          ],
          onChanged: (v) => setState(() => _timeline = v),
        );

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
          'Upload photos of your cabinets to help contractors provide accurate quotes.',
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cabinets')),
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
                    onPressed: _submitting ? null : _back,
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
                          ? 'Uploading…'
                          : (_submitting
                                ? 'Submitting…'
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
