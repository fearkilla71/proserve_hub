import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/location_service.dart';
import '../utils/pricing_engine.dart';
import '../utils/zip_locations.dart';

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

  int _step = 0;
  bool _submitting = false;
  bool _locating = false;

  // Step answers.
  String? _propertyType; // 'home' | 'business'
  String? _stories; // '1' | '2' | '3_plus' | 'not_sure'
  String?
  _siding; // 'vinyl' | 'wood' | 'stucco' | 'brick' | 'fiber_cement' | 'other'

  bool _paintSiding = true;
  bool _paintTrim = true;
  bool _paintFascia = false;
  bool _paintSoffit = false;
  bool _paintDoors = false;
  bool _paintGarageDoor = false;
  bool _paintDeckFence = false;

  String? _colorFinish; // 'same_color' | 'color_change' | 'flexible'

  static const int _totalSteps = 6;

  @override
  void dispose() {
    _zipController.dispose();
    _homeSqftController.dispose();
    super.dispose();
  }

  double get _progressValue {
    final denom = (_totalSteps - 1).clamp(1, 9999);
    return (_step / denom).clamp(0.0, 1.0);
  }

  double? _parseSqft(String raw) {
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

  bool get _canGoNext {
    switch (_step) {
      case 0:
        return _zipController.text.trim().isNotEmpty &&
            (_parseSqft(_homeSqftController.text) ?? 0) > 0;
      case 1:
        return _propertyType != null;
      case 2:
        return _stories != null;
      case 3:
        return _siding != null;
      case 4:
        return _paintSiding ||
            _paintTrim ||
            _paintFascia ||
            _paintSoffit ||
            _paintDoors ||
            _paintGarageDoor ||
            _paintDeckFence;
      case 5:
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
      case 'not_sure':
        return "I'm not sure";
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

  String _buildDescription({
    required double homeSqft,
    required String propertyTypeLabel,
    required String storiesLabel,
    required String sidingLabel,
  }) {
    final items = <String>[];
    if (_paintSiding) items.add('Siding');
    if (_paintTrim) items.add('Trim');
    if (_paintFascia) items.add('Fascia');
    if (_paintSoffit) items.add('Soffit');
    if (_paintDoors) items.add('Doors');
    if (_paintGarageDoor) items.add('Garage door');
    if (_paintDeckFence) items.add('Deck/Fence');

    final what = items.isEmpty ? 'Not specified' : items.join(', ');

    return 'Exterior painting\n'
        'Property: $propertyTypeLabel\n'
        'Home size: ${homeSqft.toStringAsFixed(0)} sqft\n'
        'Stories: $storiesLabel\n'
        'Siding: $sidingLabel\n'
        'What to paint: $what\n'
        'Finish: ${_colorFinishLabel(_colorFinish ?? '')}';
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);

    final uid = await _ensureSignedInCustomerUid();
    if (uid == null) return;

    final zip = _zipController.text.trim();
    final homeSqft = _parseSqft(_homeSqftController.text);
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

    if (homeSqft == null || homeSqft <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid square footage.')),
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

    // Budget: reuse painting baseline and apply a small exterior uplift.
    double budget = 0;
    try {
      final prices = await PricingEngine.calculate(
        service: 'Painting',
        quantity: homeSqft,
        zip: zip,
        urgent: false,
      );
      budget = (prices['recommended'] ?? 0).toDouble();
      budget *= 1.15;
    } catch (_) {
      budget = 0;
    }

    final propertyTypeLabel = (_propertyType == 'business')
        ? 'Business'
        : 'Home';

    final storiesLabel = _storiesLabel(_stories ?? 'not_sure');
    final sidingLabel = _sidingLabel(_siding ?? 'other');

    final description = _buildDescription(
      homeSqft: homeSqft,
      propertyTypeLabel: propertyTypeLabel,
      storiesLabel: storiesLabel,
      sidingLabel: sidingLabel,
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
      } catch (_) {
        // Best-effort only.
      }

      final jobRef = db.collection('job_requests').doc();
      final contactRef = jobRef.collection('private').doc('contact');

      final batch = db.batch();

      batch.set(jobRef, {
        // Keep service = Painting so matching works with contractors who list 'Painting'.
        'service': 'Painting',
        'paintingScope': 'exterior',
        'location': 'ZIP $zip',
        'zip': zip,
        'quantity': homeSqft,
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
          'scope': 'exterior',
          'sqft': homeSqft,
          'property_type': _propertyType,
          'stories': _stories,
          'siding': _siding,
          'what_to_paint': {
            'siding': _paintSiding,
            'trim': _paintTrim,
            'fascia': _paintFascia,
            'soffit': _paintSoffit,
            'doors': _paintDoors,
            'garage_door': _paintGarageDoor,
            'deck_fence': _paintDeckFence,
          },
          'color_finish': _colorFinish,
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
      context.push('/recommended/${jobRef.id}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              'Exterior painting estimate',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tell us a bit about your exterior project to see a price range and pros near you.',
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
              controller: _homeSqftController,
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

      case 1:
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

      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'How many stories is the building?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
                    title: Text('2 stories'),
                    value: '2',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('3+ stories'),
                    value: '3_plus',
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

      case 3:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            Text(
              'What is the exterior surface?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

      case 4:
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
              title: const Text('Siding'),
              value: _paintSiding,
              onChanged: (v) => setState(() => _paintSiding = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trim'),
              value: _paintTrim,
              onChanged: (v) => setState(() => _paintTrim = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fascia'),
              value: _paintFascia,
              onChanged: (v) => setState(() => _paintFascia = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Soffit'),
              value: _paintSoffit,
              onChanged: (v) => setState(() => _paintSoffit = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Doors'),
              value: _paintDoors,
              onChanged: (v) => setState(() => _paintDoors = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Garage door'),
              value: _paintGarageDoor,
              onChanged: (v) => setState(() => _paintGarageDoor = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deck/Fence'),
              value: _paintDeckFence,
              onChanged: (v) => setState(() => _paintDeckFence = v ?? false),
            ),
          ],
        );

      case 5:
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
            RadioGroup<String>(
              groupValue: _colorFinish,
              onChanged: (v) => setState(() => _colorFinish = v),
              child: Column(
                children: const [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Repainting, with same color'),
                    value: 'same_color',
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Repainting, with a color change'),
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
