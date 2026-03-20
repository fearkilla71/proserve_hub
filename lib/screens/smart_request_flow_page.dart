import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/pricing_engine.dart';

/// A streamlined 4-step request flow that uses AI photo analysis to pre-fill
/// job details, replacing the 13-step legacy flows.
///
/// Step 1 — Snap & Describe: Photo + ZIP + service type
/// Step 2 — AI Pre-Fill: AI-detected details with edit toggles
/// Step 3 — Timeline & Budget: When + budget preference
/// Step 4 — Review & Submit
class SmartRequestFlowPage extends StatefulWidget {
  final String? initialServiceType;
  final String? initialServiceName;

  const SmartRequestFlowPage({
    super.key,
    this.initialServiceType,
    this.initialServiceName,
  });

  @override
  State<SmartRequestFlowPage> createState() => _SmartRequestFlowPageState();
}

class _SmartRequestFlowPageState extends State<SmartRequestFlowPage> {
  final _pageController = PageController();
  int _currentStep = 0;
  static const _totalSteps = 4;

  // ── Step 1: Snap & Describe ──
  final List<XFile> _photos = [];
  final _zipController = TextEditingController();
  String? _selectedServiceType;
  String? _selectedServiceName;

  // ── Step 2: AI Pre-Fill ──
  bool _aiLoading = false;
  String? _aiError;
  Map<String, dynamic> _aiDetails = {};
  final _sqftController = TextEditingController();
  String _propertyType = 'home';
  String _condition = 'fair';

  // ── Step 3: Timeline & Budget ──
  String _timeline = 'standard'; // standard, asap, flexible
  String _budgetPref = 'recommended'; // low, recommended, premium

  // ── Step 4: Submit ──
  bool _submitting = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  static const _services = <Map<String, String>>[
    {'type': 'interior_painting', 'name': 'Interior Painting'},
    {'type': 'exterior_painting', 'name': 'Exterior Painting'},
    {'type': 'drywall_repair', 'name': 'Drywall Repair'},
    {'type': 'pressure_washing', 'name': 'Pressure Washing'},
    {'type': 'cabinets', 'name': 'Cabinet Painting'},
    {'type': 'roofing', 'name': 'Roofing'},
    {'type': 'plumbing', 'name': 'Plumbing'},
    {'type': 'electrical', 'name': 'Electrical'},
    {'type': 'flooring', 'name': 'Flooring'},
    {'type': 'landscaping', 'name': 'Landscaping'},
    {'type': 'fencing', 'name': 'Fencing'},
    {'type': 'general_handyman', 'name': 'General Handyman'},
    {'type': 'hvac', 'name': 'HVAC'},
    {'type': 'bathroom_remodel', 'name': 'Bathroom Remodel'},
    {'type': 'kitchen_remodel', 'name': 'Kitchen Remodel'},
    {'type': 'deck_patio', 'name': 'Deck & Patio'},
    {'type': 'concrete_masonry', 'name': 'Concrete & Masonry'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedServiceType = widget.initialServiceType;
    _selectedServiceName = widget.initialServiceName;

    // Pre-fill user info.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _loadUserProfile(user.uid);
    }
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null || !mounted) return;
      setState(() {
        _nameController.text = (data['name'] as String?) ?? '';
        _phoneController.text = (data['phone'] as String?) ?? '';
        _zipController.text = (data['zip'] as String?) ?? '';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zipController.dispose();
    _sqftController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  // Navigation
  // ════════════════════════════════════════════════════════════════

  void _next() {
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep == 0) {
      // Transitioning from step 1 to step 2 → trigger AI analysis.
      _runAiAnalysis();
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  bool _validateStep1() {
    if (_photos.isEmpty) {
      _showError('Please add at least one photo of the project area.');
      return false;
    }
    if (_zipController.text.trim().length < 5) {
      _showError('Please enter a valid ZIP code.');
      return false;
    }
    if (_selectedServiceType == null) {
      _showError('Please select a service type.');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ════════════════════════════════════════════════════════════════
  // AI Photo Analysis
  // ════════════════════════════════════════════════════════════════

  Future<void> _runAiAnalysis() async {
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final estimateId = FirebaseFirestore.instance
          .collection('estimates')
          .doc()
          .id;

      // Upload photos to Storage.
      final List<String> imagePaths = [];
      for (int i = 0; i < _photos.length && i < 5; i++) {
        final bytes = await _photos[i].readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
        );
        final path = 'estimate_images/$estimateId/$uid/${i}_${_photos[i].name}';
        await FirebaseStorage.instance
            .ref(path)
            .putData(Uint8List.fromList(compressed));
        imagePaths.add(path);
      }

      // Call estimateFromImagesInputs function.
      final callable = FirebaseFunctions.instance
          .httpsCallable('estimateFromImagesInputs');
      final result = await callable.call<dynamic>({
        'estimateId': estimateId,
        'service': _selectedServiceType,
        'zip': _zipController.text.trim(),
        'urgency': 'standard',
        'quantity': 0, // AI will estimate
        'unit': 'sqft',
        'imagePaths': imagePaths,
      });

      final data = result.data as Map<dynamic, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        _aiDetails = Map<String, dynamic>.from(data);
        final qty = (_aiDetails['quantity'] as num?)?.toDouble() ?? 0;
        if (qty > 0) _sqftController.text = qty.toStringAsFixed(0);
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = 'AI analysis unavailable. You can fill in details manually.';
        _aiLoading = false;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Photo Picker
  // ════════════════════════════════════════════════════════════════

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (images.isNotEmpty && mounted) {
      setState(() => _photos.addAll(images.take(10 - _photos.length)));
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (photo != null && mounted && _photos.length < 10) {
      setState(() => _photos.add(photo));
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Submit
  // ════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);

    try {
      final zip = _zipController.text.trim();
      final sqft = double.tryParse(_sqftController.text.trim()) ?? 1000;
      final urgent = _timeline == 'asap';

      // Upload photos.
      final List<String> uploadedPaths = [];
      final jobRef =
          FirebaseFirestore.instance.collection('job_requests').doc();
      for (int i = 0; i < _photos.length && i < 10; i++) {
        final bytes = await _photos[i].readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
        );
        final path = 'job_photos/${jobRef.id}/$uid/${i}_${_photos[i].name}';
        await FirebaseStorage.instance
            .ref(path)
            .putData(Uint8List.fromList(compressed));
        uploadedPaths.add(path);
      }

      // Calculate budget using PricingEngine.
      final serviceLabel = _selectedServiceName ?? 'Painting';
      double budget;
      try {
        final result = await PricingEngine.calculate(
          service: serviceLabel,
          zip: zip,
          quantity: sqft,
          urgent: urgent,
        );
        budget = result['recommended'] ?? (sqft * 2.5);
        if (_budgetPref == 'low') {
          budget = result['low'] ?? (budget * 0.88);
        } else if (_budgetPref == 'premium') {
          budget = result['premium'] ?? (budget * 1.15);
        }
      } catch (_) {
        budget = sqft * 2.5;
      }

      // Build description.
      final desc = StringBuffer()
        ..write('$serviceLabel job')
        ..write(' | ${sqft.toStringAsFixed(0)} sqft')
        ..write(' | $_propertyType')
        ..write(' | Condition: $_condition')
        ..write(' | Timeline: $_timeline');
      if (_notesController.text.trim().isNotEmpty) {
        desc.write(' | Notes: ${_notesController.text.trim()}');
      }

      // Write to Firestore (same schema as legacy flows).
      final batch = FirebaseFirestore.instance.batch();
      batch.set(jobRef, {
        'service': serviceLabel,
        'location': 'ZIP $zip',
        'zip': zip,
        'quantity': sqft,
        'urgency': urgent ? 'asap' : 'standard',
        'budget': budget,
        'propertyType': _propertyType == 'business' ? 'Business' : 'Home',
        'description': desc.toString(),
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
        'smartFlowDetails': {
          'sqft': sqft,
          'propertyType': _propertyType,
          'condition': _condition,
          'timeline': _timeline,
          'budgetPreference': _budgetPref,
          'aiAnalysis': _aiDetails.isNotEmpty ? _aiDetails : null,
          'notes': _notesController.text.trim(),
        },
      });

      final contactRef = jobRef.collection('private').doc('contact');
      batch.set(contactRef, {
        if (_nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      // Navigate to AI price offer.
      context.go('/ai-price-offer/${jobRef.id}', extra: {
        'service': serviceLabel,
        'zip': zip,
        'quantity': sqft,
        'urgent': urgent,
        'jobDetails': {
          'sqft': sqft,
          'propertyType': _propertyType,
          'condition': _condition,
        },
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to submit request: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1(scheme),
          _buildStep2(scheme),
          _buildStep3(scheme),
          _buildStep4(scheme),
        ],
      ),
    );
  }

  // ──────────── Step 1: Snap & Describe ────────────

  Widget _buildStep1(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Snap & Describe',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Take or upload photos and we\'ll handle the rest with AI.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // Photo area
        Text('Project Photos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_photos.isEmpty)
          _PhotoPlaceholder(onCamera: _takePhoto, onGallery: _pickPhotos)
        else
          Column(
            children: [
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _photos.length) {
                      if (_photos.length >= 10) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _AddPhotoButton(
                          onCamera: _takePhoto,
                          onGallery: _pickPhotos,
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<Uint8List>(
                              future: _photos[i].readAsBytes(),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey.shade200,
                                  );
                                }
                                return Image.memory(
                                  snap.data!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _photos.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

        const SizedBox(height: 24),

        // ZIP Code
        Text('ZIP Code', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _zipController,
          keyboardType: TextInputType.number,
          maxLength: 5,
          decoration: const InputDecoration(
            hintText: 'Enter your ZIP code',
            border: OutlineInputBorder(),
            counterText: '',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),

        const SizedBox(height: 24),

        // Service Type
        Text('Service Type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _services.map((s) {
            final selected = _selectedServiceType == s['type'];
            return ChoiceChip(
              label: Text(s['name']!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedServiceType = s['type'];
                  _selectedServiceName = s['name'];
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        FilledButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analyze with AI'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }

  // ──────────── Step 2: AI Pre-Fill ────────────

  Widget _buildStep2(ColorScheme scheme) {
    if (_aiLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'AI is analyzing your photos...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Estimating size, condition, and pricing',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'AI-Detected Details',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Review and adjust the details below.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),

        if (_aiError != null) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiError!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (_aiDetails.isNotEmpty && _aiDetails['confidence'] != null) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Confidence: ${((_aiDetails['confidence'] as num) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Estimated sqft
        Text(
          'Estimated Size (sqft)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sqftController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 1500',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.square_foot),
            suffixText: 'sqft',
            helperText: _aiDetails['notes'] as String?,
          ),
        ),

        const SizedBox(height: 20),

        // Property type
        Text('Property Type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'home', label: Text('Home'), icon: Icon(Icons.home)),
            ButtonSegment(value: 'business', label: Text('Business'), icon: Icon(Icons.business)),
          ],
          selected: {_propertyType},
          onSelectionChanged: (v) => setState(() => _propertyType = v.first),
        ),

        const SizedBox(height: 20),

        // Condition
        Text('Surface Condition', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'excellent', label: Text('Excellent')),
            ButtonSegment(value: 'fair', label: Text('Fair')),
            ButtonSegment(value: 'poor', label: Text('Poor')),
          ],
          selected: {_condition},
          onSelectionChanged: (v) => setState(() => _condition = v.first),
        ),

        if (_aiDetails.isNotEmpty) ...[
          const SizedBox(height: 20),
          // Show AI notes
          if (_aiDetails['notes'] != null &&
              _aiDetails['notes'].toString().isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'AI Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiDetails['notes'].toString(),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
        ],

        const SizedBox(height: 32),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  // ──────────── Step 3: Timeline & Budget ────────────

  Widget _buildStep3(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Timeline & Budget',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'When do you need the work done?',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // Timeline
        Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _TimelineOption(
          icon: Icons.schedule,
          title: 'Standard',
          subtitle: 'Within 1–2 weeks',
          selected: _timeline == 'standard',
          onTap: () => setState(() => _timeline = 'standard'),
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.flash_on,
          title: 'ASAP',
          subtitle: 'As soon as possible (+15% urgency premium)',
          selected: _timeline == 'asap',
          onTap: () => setState(() => _timeline = 'asap'),
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.event_available,
          title: 'Flexible',
          subtitle: 'No rush — I\'m flexible on timing',
          selected: _timeline == 'flexible',
          onTap: () => setState(() => _timeline = 'flexible'),
        ),

        const SizedBox(height: 28),

        // Budget preference
        Text(
          'Budget Preference',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _TimelineOption(
          icon: Icons.savings,
          title: 'Budget-Friendly',
          subtitle: 'Lower end of market pricing',
          selected: _budgetPref == 'low',
          onTap: () => setState(() => _budgetPref = 'low'),
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.thumb_up,
          title: 'Recommended',
          subtitle: 'Fair market price for quality work',
          selected: _budgetPref == 'recommended',
          onTap: () => setState(() => _budgetPref = 'recommended'),
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.star,
          title: 'Premium',
          subtitle: 'Top-tier materials & craftsmanship',
          selected: _budgetPref == 'premium',
          onTap: () => setState(() => _budgetPref = 'premium'),
        ),

        const SizedBox(height: 32),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: const Text('Review & Submit'),
        ),
      ],
    );
  }

  // ──────────── Step 4: Review & Submit ────────────

  Widget _buildStep4(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Review & Submit',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Confirm your details and submit.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Service', _selectedServiceName ?? '—'),
                _summaryRow('ZIP Code', _zipController.text),
                _summaryRow('Size', '${_sqftController.text} sqft'),
                _summaryRow('Property', _propertyType == 'business' ? 'Business' : 'Home'),
                _summaryRow('Condition', _condition),
                _summaryRow('Timeline', _timeline),
                _summaryRow('Budget', _budgetPref),
                _summaryRow('Photos', '${_photos.length}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Contact info
        Text(
          'Contact Information',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Additional Notes (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.notes),
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 32),

        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════

class _PhotoPlaceholder extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoPlaceholder({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerLow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Take a photo or upload from gallery',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _AddPhotoButton({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onGallery,
      onLongPress: onCamera,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
          color: scheme.surfaceContainerLow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: scheme.primary),
            const SizedBox(height: 4),
            Text(
              'Add More',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
