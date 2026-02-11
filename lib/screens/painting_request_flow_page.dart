import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/location_service.dart';
import '../utils/pricing_engine.dart';
import '../utils/zip_locations.dart';

class PaintingRequestFlowPage extends StatefulWidget {
  const PaintingRequestFlowPage({super.key, this.initialPaintingScope});

  /// When provided as 'interior' or 'exterior', the flow will skip the
  /// interior/exterior selection screen and start on the next step.
  final String? initialPaintingScope;

  @override
  State<PaintingRequestFlowPage> createState() =>
      _PaintingRequestFlowPageState();
}

class _PaintingRequestFlowPageState extends State<PaintingRequestFlowPage> {
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _sqftController = TextEditingController();

  final TextEditingController _accentWallsController = TextEditingController();
  final TextEditingController _twoToneWallsController = TextEditingController();
  final TextEditingController _trimLinearFeetController =
      TextEditingController();

  final TextEditingController _doorsStandardOneSideController =
      TextEditingController();
  final TextEditingController _doorsStandardBothSidesController =
      TextEditingController();
  final TextEditingController _doorsFrenchPairController =
      TextEditingController();
  final TextEditingController _doorsClosetSlabController =
      TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _locating = false;

  // Step answers.
  String? _paintingScope; // 'interior' | 'exterior'
  String? _propertyType; // 'home' | 'business'
  bool? _isNewConstruction;
  String? _roomsPainting; // 'touchups' | '1' | '2' | ... | '8_plus'
  String? _paintBuyer; // 'homeowner' | 'painter' | 'not_sure'
  String? _wallCondition; // 'excellent' | 'fair' | 'poor'
  String?
  _ceilingHeight; // 'under_8' | '8_10' | '10_14' | 'over_14' | 'not_sure'
  String? _moveHelp; // 'yes' | 'no' | 'flexible'

  bool _paintWalls = true;
  bool _paintTrim = false;
  bool _paintDoors = false;
  bool _paintWindowFrames = false;

  String?
  _colorFinish; // 'same_color' | 'color_change' | 'faux_finish' | 'texture_coating' | 'flexible'

  bool _paintCeilings = false;
  String _colorChangeType = 'same_color';

  static const int _totalSteps = 11;

  bool get _showsScopeStep {
    final initial = widget.initialPaintingScope?.trim().toLowerCase();
    return !(initial == 'interior' || initial == 'exterior');
  }

  @override
  void initState() {
    super.initState();

    final initial = widget.initialPaintingScope?.trim().toLowerCase();
    if (initial == 'interior' || initial == 'exterior') {
      _paintingScope = initial;
      _step = 1;
    }
  }

  @override
  void dispose() {
    _zipController.dispose();
    _sqftController.dispose();
    _accentWallsController.dispose();
    _twoToneWallsController.dispose();
    _trimLinearFeetController.dispose();
    _doorsStandardOneSideController.dispose();
    _doorsStandardBothSidesController.dispose();
    _doorsFrenchPairController.dispose();
    _doorsClosetSlabController.dispose();
    super.dispose();
  }

  double get _progressValue {
    final visibleTotalSteps = _showsScopeStep ? _totalSteps : _totalSteps - 1;
    final visibleStep = _showsScopeStep ? _step : (_step - 1);
    final denom = (visibleTotalSteps - 1).clamp(1, 9999);
    return (visibleStep / denom).clamp(0.0, 1.0);
  }

  double? _parseSqft(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  int _parseInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final match = RegExp(r'(\d+)').firstMatch(t);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  double _parseDouble(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(t);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
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
      case 0:
        return _paintingScope != null;
      case 1:
        return _zipController.text.trim().isNotEmpty &&
            (_parseSqft(_sqftController.text) ?? 0) > 0;
      case 2:
        return _propertyType != null;
      case 3:
        return _isNewConstruction != null;
      case 4:
        return _roomsPainting != null;
      case 5:
        return _paintBuyer != null;
      case 6:
        return _wallCondition != null;
      case 7:
        return _ceilingHeight != null;
      case 8:
        return _moveHelp != null;
      case 9:
        return _paintWalls ||
            _paintTrim ||
            _paintCeilings ||
            _paintDoors ||
            _paintWindowFrames;
      case 10:
        return _colorFinish != null;
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
    if (!_showsScopeStep && _step <= 1) {
      Navigator.of(context).pop();
      return;
    }

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

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    final uid = await _ensureSignedInCustomerUid();
    if (uid == null) return;

    final zip = _zipController.text.trim();
    final sqft = _parseSqft(_sqftController.text);
    if (zip.isEmpty) return;

    final loc = zipLocations[zip];
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

    // Prefer at least an email, otherwise allow phone.
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
    } catch (_) {
      // ignore
    }

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

    if (sqft == null || sqft <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid square footage.')),
      );
      return;
    }

    double budget = 0;
    try {
      final prices = await PricingEngine.calculate(
        service: 'Painting',
        quantity: sqft,
        zip: zip,
        urgent: false,
      );
      budget = (prices['recommended'] ?? 0).toDouble();
    } catch (_) {
      budget = 0;
    }

    final accentWalls = _parseInt(_accentWallsController.text);
    final twoToneWalls = _parseInt(_twoToneWallsController.text);
    final trimLinearFeet = _parseDouble(_trimLinearFeetController.text);

    final doors = <String, int>{
      'standard_one_side': _parseInt(_doorsStandardOneSideController.text),
      'standard_both_sides': _parseInt(_doorsStandardBothSidesController.text),
      'french_pair': _parseInt(_doorsFrenchPairController.text),
      'closet_slab': _parseInt(_doorsClosetSlabController.text),
    };

    final propertyTypeLabel = (_propertyType == 'business')
        ? 'Business'
        : 'Home';

    final scopeLabel = (_paintingScope == 'exterior') ? 'Exterior' : 'Interior';

    final description =
        'Painting type: $scopeLabel\n\n'
        '${_buildDescription(sqft: sqft, propertyType: propertyTypeLabel, isNewConstruction: _isNewConstruction, roomsPainting: _roomsPainting, paintBuyer: _paintBuyer, wallCondition: _wallCondition, ceilingHeight: _ceilingHeight, moveHelp: _moveHelp, whatToPaint: {'walls': _paintWalls, 'trim': _paintTrim, 'ceiling': _paintCeilings, 'doors': _paintDoors, 'window_frames': _paintWindowFrames}, colorFinish: _colorFinish, accentWalls: accentWalls, twoToneWalls: twoToneWalls, doors: doors, trimLinearFeet: trimLinearFeet, paintCeilings: _paintCeilings, colorChangeType: _colorChangeType)}';

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
      } catch (_) {
        // Best-effort only; contact info can be created without a name.
      }

      final jobRef = db.collection('job_requests').doc();
      final contactRef = jobRef.collection('private').doc('contact');

      final batch = db.batch();

      batch.set(jobRef, {
        'service': 'Painting',
        'paintingScope': _paintingScope,
        'location': 'ZIP $zip',
        'zip': zip,
        'quantity': sqft,
        'lat': loc['lat'],
        'lng': loc['lng'],
        'urgency': 'standard',
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
        'paintingQuestions': {
          'scope': _paintingScope,
          'sqft': sqft,
          'property_type': _propertyType,
          'new_construction': _isNewConstruction,
          'rooms_painting': _roomsPainting,
          'paint_buyer': _paintBuyer,
          'wall_condition': _wallCondition,
          'ceiling_height': _ceilingHeight,
          'move_help': _moveHelp,
          'what_to_paint': {
            'walls': _paintWalls,
            'trim': _paintTrim,
            'ceiling': _paintCeilings,
            'doors': _paintDoors,
            'window_frames': _paintWindowFrames,
          },
          'color_finish': _colorFinish,
          'accent_walls': accentWalls,
          'two_tone_walls': twoToneWalls,
          'doors': doors,
          'trim_linear_feet': trimLinearFeet,
          'paint_ceilings': _paintCeilings,
          'color_change_type': _colorChangeType,
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
          'service': 'Painting',
          'zip': zip,
          'quantity': sqft,
          'urgent': false,
          'jobDetails': {
            'paintingScope': _paintingScope,
            'propertyType': propertyTypeLabel,
            'description': description,
            'paintingQuestions': {
              'scope': _paintingScope,
              'sqft': sqft,
              'property_type': _propertyType,
              'new_construction': _isNewConstruction,
              'rooms_painting': _roomsPainting,
              'wall_condition': _wallCondition,
              'ceiling_height': _ceilingHeight,
              'what_to_paint': {
                'walls': _paintWalls,
                'trim': _paintTrim,
                'ceiling': _paintCeilings,
                'doors': _paintDoors,
                'window_frames': _paintWindowFrames,
              },
              'color_finish': _colorFinish,
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

  String _buildDescription({
    required double sqft,
    required String propertyType,
    required bool? isNewConstruction,
    required String? roomsPainting,
    required String? paintBuyer,
    required String? wallCondition,
    required String? ceilingHeight,
    required String? moveHelp,
    required Map<String, bool> whatToPaint,
    required String? colorFinish,
    required int accentWalls,
    required int twoToneWalls,
    required Map<String, int> doors,
    required double trimLinearFeet,
    required bool paintCeilings,
    required String colorChangeType,
  }) {
    final pieces = <String>[];

    pieces.add('Interior painting');

    pieces.add('$propertyType size: ${sqft.toStringAsFixed(0)} sqft');

    if (roomsPainting != null) {
      pieces.add('Rooms: ${_roomsLabel(roomsPainting)}');
    }
    if (isNewConstruction != null) {
      pieces.add(
        isNewConstruction ? 'New construction: Yes' : 'New construction: No',
      );
    }
    if (paintBuyer != null) {
      pieces.add('Paint buyer: ${_paintBuyerLabel(paintBuyer)}');
    }
    if (wallCondition != null) {
      pieces.add('Walls: ${_wallConditionLabel(wallCondition)}');
    }
    if (ceilingHeight != null) {
      pieces.add('Ceiling height: ${_ceilingHeightLabel(ceilingHeight)}');
    }
    if (moveHelp != null) {
      pieces.add('Moving help: ${_moveHelpLabel(moveHelp)}');
    }

    final paintParts = <String>[];
    if (whatToPaint['walls'] == true) paintParts.add('Walls');
    if (whatToPaint['trim'] == true) paintParts.add('Trim');
    if (whatToPaint['ceiling'] == true) paintParts.add('Ceiling');
    if (whatToPaint['doors'] == true) paintParts.add('Doors');
    if (whatToPaint['window_frames'] == true) paintParts.add('Window frames');
    if (paintParts.isNotEmpty) {
      pieces.add('Paint: ${paintParts.join(', ')}');
    }

    if (colorFinish != null) {
      pieces.add('Finish: ${_colorFinishLabel(colorFinish)}');
    }

    if (accentWalls > 0) {
      pieces.add('Accent walls: $accentWalls');
    }
    if (twoToneWalls > 0) {
      pieces.add('Two-tone walls: $twoToneWalls');
    }

    final doorParts = <String>[];
    final oneSide = doors['standard_one_side'] ?? 0;
    final bothSides = doors['standard_both_sides'] ?? 0;
    final french = doors['french_pair'] ?? 0;
    final closet = doors['closet_slab'] ?? 0;
    if (oneSide > 0) doorParts.add('$oneSide standard (one side)');
    if (bothSides > 0) doorParts.add('$bothSides standard (both sides)');
    if (french > 0) doorParts.add('$french french (pair)');
    if (closet > 0) doorParts.add('$closet closet/slab');
    if (doorParts.isNotEmpty) {
      pieces.add('Doors: ${doorParts.join(', ')}');
    }

    if (trimLinearFeet > 0) {
      pieces.add('Trim & baseboards: ${trimLinearFeet.toStringAsFixed(0)} lf');
    }

    pieces.add(paintCeilings ? 'Ceilings: Yes' : 'Ceilings: No');
    pieces.add('Color change: ${_colorChangeLabel(colorChangeType)}');

    return pieces.join(' • ');
  }

  String _roomsLabel(String v) {
    switch (v) {
      case 'touchups':
        return 'Just touch ups';
      case '1':
        return '1 room';
      case '2':
        return '2 rooms';
      case '3':
        return '3 rooms';
      case '4':
        return '4 rooms';
      case '5':
        return '5 rooms';
      case '6':
        return '6 rooms';
      case '7':
        return '7 rooms';
      case '8_plus':
        return '8+ rooms';
      default:
        return v;
    }
  }

  String _paintBuyerLabel(String v) {
    switch (v) {
      case 'homeowner':
        return 'Homeowner/property manager';
      case 'painter':
        return 'The painter';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _wallConditionLabel(String v) {
    switch (v) {
      case 'excellent':
        return 'Excellent - clean and smooth';
      case 'fair':
        return 'Fair - minor holes and scratches';
      case 'poor':
        return 'Poor - major repairs needed';
      default:
        return v;
    }
  }

  String _ceilingHeightLabel(String v) {
    switch (v) {
      case 'under_8':
        return 'Under 8 feet (low ceiling)';
      case '8_10':
        return '8 - 10 feet (standard ceiling)';
      case '10_14':
        return '10 - 14 feet (high ceiling)';
      case 'over_14':
        return 'Over 14 feet (lofty ceiling)';
      case 'not_sure':
        return "I'm not sure";
      default:
        return v;
    }
  }

  String _moveHelpLabel(String v) {
    switch (v) {
      case 'yes':
        return 'Yes, need help';
      case 'no':
        return 'No, I will move things';
      case 'flexible':
        return "I'm flexible";
      default:
        return v;
    }
  }

  String _colorFinishLabel(String v) {
    switch (v) {
      case 'same_color':
        return 'Repainting (same color)';
      case 'color_change':
        return 'Repainting (color change)';
      case 'faux_finish':
        return 'Decorative painting (faux finish)';
      case 'texture_coating':
        return 'Decorative painting (texture coating)';
      case 'flexible':
        return "I'm flexible";
      default:
        return v;
    }
  }

  String _colorChangeLabel(String v) {
    switch (v) {
      case 'same_color':
        return 'Same color';
      case 'light_to_light':
        return 'Light → light';
      case 'dark_to_light':
        return 'Dark → light';
      case 'high_pigment':
        return 'Red/orange/high-pigment';
      default:
        return v;
    }
  }

  Widget _buildStepBody() {
    final textTheme = Theme.of(context).textTheme;

    switch (_step) {
      case 0:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Painting estimate',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'First, tell us whether this is an interior or exterior painting project.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: _paintingScope,
              onChanged: (v) => setState(() => _paintingScope = v),
              child: Column(
                children: const [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Interior painting'),
                    value: 'interior',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Exterior painting'),
                    value: 'exterior',
                  ),
                ],
              ),
            ),
          ],
        );

      case 1:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Get a price estimate',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tell us about your ${(_paintingScope == 'exterior') ? 'exterior' : 'interior'} painting project to see the average price in your area, and a list of pros who can do the job.',
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
                  _locating ? 'Finding your location…' : 'Use my location',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'What is your home square footage?',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sqftController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Square footage (sq ft)',
                helperText: 'Example: 2000',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );

      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'Is this a home or a business?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

      case 3:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'Is this new construction?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: _isNewConstruction,
              onChanged: (v) => setState(() => _isNewConstruction = v),
              child: Column(
                children: const [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Yes, this is new construction'),
                    value: true,
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No, this is not new construction'),
                    value: false,
                  ),
                ],
              ),
            ),
          ],
        );

      case 4:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'How many rooms are you painting?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _roomsPainting,
              onChanged: (v) => setState(() => _roomsPainting = v),
              child: Column(
                children: [
                  const RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Just touch ups'),
                    value: 'touchups',
                  ),
                  for (final item in const [
                    ['1', '1 room'],
                    ['2', '2 rooms'],
                    ['3', '3 rooms'],
                    ['4', '4 rooms'],
                    ['5', '5 rooms'],
                    ['6', '6 rooms'],
                    ['7', '7 rooms'],
                    ['8_plus', '8+ rooms'],
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item[1]),
                      value: item[0],
                    ),
                ],
              ),
            ),
          ],
        );

      case 5:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              "Who's buying the paint?",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _paintBuyer,
              onChanged: (v) => setState(() => _paintBuyer = v),
              child: Column(
                children: const [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Homeowner or property manager'),
                    value: 'homeowner',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('The painter'),
                    value: 'painter',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text("I'm not sure"),
                    value: 'not_sure',
                  ),
                ],
              ),
            ),
          ],
        );

      case 6:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'What are the walls like?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _wallCondition,
              onChanged: (v) => setState(() => _wallCondition = v),
              child: Column(
                children: const [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Excellent - clean and smooth'),
                    value: 'excellent',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Fair - minor holes and scratches'),
                    value: 'fair',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Poor - major repairs needed'),
                    value: 'poor',
                  ),
                ],
              ),
            ),
          ],
        );

      case 7:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'How high is the ceiling?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _ceilingHeight,
              onChanged: (v) => setState(() => _ceilingHeight = v),
              child: Column(
                children: [
                  for (final item in const [
                    ['under_8', 'Under 8 feet (low ceiling)'],
                    ['8_10', '8 - 10 feet (standard ceiling)'],
                    ['10_14', '10 - 14 feet (high ceiling)'],
                    ['over_14', 'Over 14 feet (lofty ceiling)'],
                    ['not_sure', "I'm not sure"],
                  ])
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item[1]),
                      value: item[0],
                    ),
                ],
              ),
            ),
          ],
        );

      case 8:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'Do you need help moving things out of the way?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _moveHelp,
              onChanged: (v) => setState(() => _moveHelp = v),
              child: Column(
                children: const [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Yes, I would like the painter to help move things',
                    ),
                    value: 'yes',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No, I will move things out of the way myself'),
                    value: 'no',
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

      case 9:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'What do you want painted?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Walls'),
              value: _paintWalls,
              onChanged: (v) => setState(() => _paintWalls = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trim'),
              value: _paintTrim,
              onChanged: (v) => setState(() => _paintTrim = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ceiling'),
              value: _paintCeilings,
              onChanged: (v) => setState(() => _paintCeilings = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Doors'),
              value: _paintDoors,
              onChanged: (v) => setState(() => _paintDoors = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Window frames'),
              value: _paintWindowFrames,
              onChanged: (v) => setState(() => _paintWindowFrames = v ?? false),
            ),
          ],
        );

      case 10:
        bool checked(String v) => _colorFinish == v;
        void setExclusive(String v, bool? value) {
          if (value != true) return;
          setState(() {
            _colorFinish = v;
            if (v == 'same_color') {
              _colorChangeType = 'same_color';
            } else if (v == 'color_change') {
              if (_colorChangeType == 'same_color') {
                _colorChangeType = 'light_to_light';
              }
            } else {
              _colorChangeType = 'same_color';
            }
          });
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'What color or finish do you want?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repainting, with same color'),
              value: checked('same_color'),
              onChanged: (v) => setExclusive('same_color', v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repainting, with a color change'),
              value: checked('color_change'),
              onChanged: (v) => setExclusive('color_change', v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Decorative painting, with faux finish'),
              value: checked('faux_finish'),
              onChanged: (v) => setExclusive('faux_finish', v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Decorative painting, with texture coating'),
              value: checked('texture_coating'),
              onChanged: (v) => setExclusive('texture_coating', v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("I'm flexible"),
              value: checked('flexible'),
              onChanged: (v) => setExclusive('flexible', v),
            ),
            if (_colorFinish == 'color_change') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_colorChangeType),
                initialValue: _colorChangeType,
                decoration: const InputDecoration(
                  labelText: 'Color change type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'light_to_light',
                    child: Text('Light → light (x1.05)'),
                  ),
                  DropdownMenuItem(
                    value: 'dark_to_light',
                    child: Text('Dark → light (x1.20)'),
                  ),
                  DropdownMenuItem(
                    value: 'high_pigment',
                    child: Text('Red/orange/high-pigment (x1.25)'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _colorChangeType = v);
                },
              ),
            ],
          ],
        );

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
              onPressed: _submitting
                  ? null
                  : isLast
                  ? (_canGoNext ? _submit : null)
                  : (_canGoNext ? _next : null),
              child: Text(
                _submitting
                    ? 'Submitting…'
                    : (isLast ? 'See your price' : 'Next'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
