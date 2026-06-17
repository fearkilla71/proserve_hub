import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
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
  static const _draftKey = 'smart_request_flow_draft_v1';

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
  bool _suppressDraftSave = false;
  DateTime? _lastDraftSavedAt;
  Timer? _draftDebounce;
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
    for (final controller in [
      _zipController,
      _sqftController,
      _nameController,
      _emailController,
      _phoneController,
      _notesController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _offerDraftRestore();
    });
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null || !mounted) return;
      setState(() {
        _nameController.text = (data['name'] as String?) ?? '';
        _phoneController.text = (data['phone'] as String?) ?? '';
        _zipController.text = (data['zip'] as String?) ?? '';
      });
      _scheduleDraftSave();
    } catch (_) {}
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
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
  // Drafts
  // ════════════════════════════════════════════════════════════════

  bool get _hasProgress {
    return _photos.isNotEmpty ||
        _zipController.text.trim().isNotEmpty ||
        _selectedServiceType != null ||
        _sqftController.text.trim().isNotEmpty ||
        _currentStep > 0 ||
        _nameController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty;
  }

  void _scheduleDraftSave() {
    if (_suppressDraftSave || !_hasProgress) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 450), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_suppressDraftSave || !_hasProgress) return;
    final prefs = await SharedPreferences.getInstance();
    final savedAt = DateTime.now();
    final draft = <String, dynamic>{
      'currentStep': _currentStep,
      'photoPaths': _photos.map((p) => p.path).toList(),
      'zip': _zipController.text,
      'selectedServiceType': _selectedServiceType,
      'selectedServiceName': _selectedServiceName,
      'sqft': _sqftController.text,
      'propertyType': _propertyType,
      'condition': _condition,
      'timeline': _timeline,
      'budgetPref': _budgetPref,
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'notes': _notesController.text,
      'savedAt': savedAt.toIso8601String(),
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
    if (mounted) {
      setState(() => _lastDraftSavedAt = savedAt);
    }
  }

  Future<void> _offerDraftRestore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic> draft;
    try {
      draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      await prefs.remove(_draftKey);
      return;
    }

    final savedAt = DateTime.tryParse(draft['savedAt']?.toString() ?? '');
    // ignore: use_build_context_synchronously
    final l10n = AppLocalizations.of(context)!;
    // ignore: use_build_context_synchronously
    final resume = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.smartRequestResumeTitle),
        content: Text(
          savedAt == null
              ? l10n.smartRequestResumeBody
              : l10n.smartRequestResumeBodyWithDate(
                  TimeOfDay.fromDateTime(savedAt).format(ctx),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.smartRequestStartFresh),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.smartRequestResume),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (resume == true) {
      _restoreDraft(draft, savedAt);
    } else if (resume == false) {
      await _clearDraft();
    }
  }

  void _restoreDraft(Map<String, dynamic> draft, DateTime? savedAt) {
    _suppressDraftSave = true;
    final photoPaths =
        (draft['photoPaths'] as List?)
            ?.whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList() ??
        const <String>[];
    setState(() {
      final restoredStep =
          (draft['currentStep'] as num?)?.toInt().clamp(0, _totalSteps - 1) ??
          0;
      _currentStep = restoredStep.toInt();
      _photos
        ..clear()
        ..addAll(photoPaths.take(10).map(XFile.new));
      _zipController.text = draft['zip']?.toString() ?? '';
      _selectedServiceType = draft['selectedServiceType']?.toString();
      _selectedServiceName = draft['selectedServiceName']?.toString();
      _sqftController.text = draft['sqft']?.toString() ?? '';
      _propertyType = draft['propertyType']?.toString() ?? 'home';
      _condition = draft['condition']?.toString() ?? 'fair';
      _timeline = draft['timeline']?.toString() ?? 'standard';
      _budgetPref = draft['budgetPref']?.toString() ?? 'recommended';
      _nameController.text = draft['name']?.toString() ?? '';
      _emailController.text = draft['email']?.toString() ?? '';
      _phoneController.text = draft['phone']?.toString() ?? '';
      _notesController.text = draft['notes']?.toString() ?? '';
      _lastDraftSavedAt = savedAt;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentStep);
      }
      _suppressDraftSave = false;
    });
  }

  Future<void> _clearDraft() async {
    _draftDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    if (mounted) {
      setState(() => _lastDraftSavedAt = null);
    }
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
      _scheduleDraftSave();
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
      _scheduleDraftSave();
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
    final l10n = AppLocalizations.of(context)!;
    if (_photos.isEmpty) {
      _showError(l10n.smartRequestPhotoRequired);
      return false;
    }
    final zip = _zipController.text.trim();
    if (zip.length != 5 || !RegExp(r'^\d{5}$').hasMatch(zip)) {
      _showError(l10n.smartRequestZipInvalid);
      return false;
    }
    if (_selectedServiceType == null) {
      _showError(l10n.smartRequestServiceRequired);
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
      final callable = FirebaseFunctions.instance.httpsCallable(
        'estimateFromImagesInputs',
      );
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
        _aiError = AppLocalizations.of(context)!.smartRequestAiUnavailable;
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
      _scheduleDraftSave();
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
      _scheduleDraftSave();
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
      final jobRef = FirebaseFirestore.instance
          .collection('job_requests')
          .doc();
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
      await _clearDraft();
      if (!mounted) return;

      // Navigate to AI price offer.
      context.go(
        '/ai-price-offer/${jobRef.id}',
        extra: {
          'service': serviceLabel,
          'zip': zip,
          'quantity': sqft,
          'urgent': urgent,
          'jobDetails': {
            'sqft': sqft,
            'propertyType': _propertyType,
            'condition': _condition,
          },
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showError(AppLocalizations.of(context)!.smartRequestSubmitFailed('$e'));
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
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_hasProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.smartRequestDiscardTitle),
            content: Text(l10n.smartRequestDiscardBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.smartRequestStay),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.smartRequestDiscard),
              ),
            ],
          ),
        );
        if ((leave ?? false) && context.mounted) {
          await _saveDraft();
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(
            l10n.smartRequestStepTitle(_currentStep + 1, _totalSteps),
          ),
          actions: [
            if (_hasProgress)
              IconButton(
                tooltip: l10n.smartRequestClearDraft,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await _clearDraft();
                  if (context.mounted) {
                    _showError(l10n.smartRequestDraftCleared);
                  }
                },
              ),
          ],
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
      ),
    );
  }

  Widget _buildStep1(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          l10n.smartRequestSnapTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.smartRequestSnapSubtitle,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _DraftStatusCard(lastSavedAt: _lastDraftSavedAt),
        const SizedBox(height: 12),
        Card(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_camera_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.smartRequestPhotoTrustTitle,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.smartRequestPhotoTrustSubtitle,
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Photo area
        Text(
          l10n.smartRequestProjectPhotos,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
                              onTap: () {
                                setState(() => _photos.removeAt(i));
                                _scheduleDraftSave();
                              },
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
        Text(l10n.zipCode, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _zipController,
          keyboardType: TextInputType.number,
          maxLength: 5,
          decoration: InputDecoration(
            hintText: l10n.smartRequestZipHint,
            border: const OutlineInputBorder(),
            counterText: '',
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
        ),

        const SizedBox(height: 24),

        // Service Type
        Text(
          l10n.smartRequestServiceType,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
                _scheduleDraftSave();
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        FilledButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.auto_awesome),
          label: Text(l10n.smartRequestAnalyzeWithAi),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }

  // ──────────── Step 2: AI Pre-Fill ────────────

  Widget _buildStep2(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    if (_aiLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              l10n.smartRequestAiAnalyzing,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.smartRequestAiAnalyzingSubtitle,
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
          l10n.smartRequestAiDetectedDetails,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.smartRequestReviewAdjust,
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
                      l10n.smartRequestAiConfidence(
                        ((_aiDetails['confidence'] as num) * 100)
                            .toStringAsFixed(0),
                      ),
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
          l10n.smartRequestEstimatedSize,
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
        Text(
          l10n.smartRequestPropertyType,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'home',
              label: Text(l10n.smartRequestHome),
              icon: const Icon(Icons.home),
            ),
            ButtonSegment(
              value: 'business',
              label: Text(l10n.smartRequestBusiness),
              icon: const Icon(Icons.business),
            ),
          ],
          selected: {_propertyType},
          onSelectionChanged: (v) {
            setState(() => _propertyType = v.first);
            _scheduleDraftSave();
          },
        ),

        const SizedBox(height: 20),

        // Condition
        Text(
          l10n.smartRequestSurfaceCondition,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'excellent',
              label: Text(l10n.smartRequestExcellent),
            ),
            ButtonSegment(value: 'fair', label: Text(l10n.smartRequestFair)),
            ButtonSegment(value: 'poor', label: Text(l10n.smartRequestPoor)),
          ],
          selected: {_condition},
          onSelectionChanged: (v) {
            setState(() => _condition = v.first);
            _scheduleDraftSave();
          },
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
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.smartRequestAiNotes,
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
          child: Text(l10n.smartRequestContinue),
        ),
      ],
    );
  }

  // ──────────── Step 3: Timeline & Budget ────────────

  Widget _buildStep3(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          l10n.smartRequestTimelineBudget,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.smartRequestTimelineQuestion,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // Timeline
        Text(l10n.timeline, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _TimelineOption(
          icon: Icons.schedule,
          title: l10n.smartRequestTimelineStandard,
          subtitle: l10n.smartRequestTimelineStandardSubtitle,
          selected: _timeline == 'standard',
          onTap: () {
            setState(() => _timeline = 'standard');
            _scheduleDraftSave();
          },
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.flash_on,
          title: l10n.smartRequestTimelineAsap,
          subtitle: l10n.smartRequestTimelineAsapSubtitle,
          selected: _timeline == 'asap',
          onTap: () {
            setState(() => _timeline = 'asap');
            _scheduleDraftSave();
          },
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.event_available,
          title: l10n.smartRequestTimelineFlexible,
          subtitle: l10n.smartRequestTimelineFlexibleSubtitle,
          selected: _timeline == 'flexible',
          onTap: () {
            setState(() => _timeline = 'flexible');
            _scheduleDraftSave();
          },
        ),

        const SizedBox(height: 28),

        // Budget preference
        Text(
          l10n.smartRequestBudgetPreference,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _TimelineOption(
          icon: Icons.savings,
          title: l10n.smartRequestBudgetFriendly,
          subtitle: l10n.smartRequestBudgetFriendlySubtitle,
          selected: _budgetPref == 'low',
          onTap: () {
            setState(() => _budgetPref = 'low');
            _scheduleDraftSave();
          },
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.thumb_up,
          title: l10n.smartRequestBudgetRecommended,
          subtitle: l10n.smartRequestBudgetRecommendedSubtitle,
          selected: _budgetPref == 'recommended',
          onTap: () {
            setState(() => _budgetPref = 'recommended');
            _scheduleDraftSave();
          },
        ),
        const SizedBox(height: 8),
        _TimelineOption(
          icon: Icons.star,
          title: l10n.smartRequestBudgetPremium,
          subtitle: l10n.smartRequestBudgetPremiumSubtitle,
          selected: _budgetPref == 'premium',
          onTap: () {
            setState(() => _budgetPref = 'premium');
            _scheduleDraftSave();
          },
        ),

        const SizedBox(height: 32),
        FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: Text(l10n.smartRequestReviewSubmit),
        ),
      ],
    );
  }

  // ──────────── Step 4: Review & Submit ────────────

  Widget _buildStep4(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          l10n.smartRequestReviewSubmit,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.smartRequestConfirmDetails,
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
                _summaryRow(l10n.service, _selectedServiceName ?? '—'),
                _summaryRow(l10n.zipCode, _zipController.text),
                _summaryRow(
                  l10n.smartRequestSummarySize,
                  '${_sqftController.text} sqft',
                ),
                _summaryRow(
                  l10n.smartRequestSummaryProperty,
                  _propertyType == 'business'
                      ? l10n.smartRequestBusiness
                      : l10n.smartRequestHome,
                ),
                _summaryRow(
                  l10n.smartRequestSummaryCondition,
                  _conditionLabel(l10n, _condition),
                ),
                _summaryRow(l10n.timeline, _timelineLabel(l10n, _timeline)),
                _summaryRow(
                  l10n.smartRequestSummaryBudget,
                  _budgetLabel(l10n, _budgetPref),
                ),
                _summaryRow(
                  l10n.smartRequestSummaryPhotos,
                  '${_photos.length}',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Contact info
        Text(
          l10n.smartRequestContactInformation,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.name,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.email,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.phone,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.smartRequestAdditionalNotesOptional,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.notes),
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
          label: Text(
            _submitting ? l10n.submitting : l10n.smartRequestSubmitRequest,
          ),
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

  String _conditionLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'excellent':
        return l10n.smartRequestExcellent;
      case 'poor':
        return l10n.smartRequestPoor;
      case 'fair':
      default:
        return l10n.smartRequestFair;
    }
  }

  String _timelineLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'asap':
        return l10n.smartRequestTimelineAsap;
      case 'flexible':
        return l10n.smartRequestTimelineFlexible;
      case 'standard':
      default:
        return l10n.smartRequestTimelineStandard;
    }
  }

  String _budgetLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'low':
        return l10n.smartRequestBudgetFriendly;
      case 'premium':
        return l10n.smartRequestBudgetPremium;
      case 'recommended':
      default:
        return l10n.smartRequestBudgetRecommended;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════

class _DraftStatusCard extends StatelessWidget {
  final DateTime? lastSavedAt;

  const _DraftStatusCard({required this.lastSavedAt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final savedLabel = lastSavedAt == null
        ? l10n.smartRequestDraftAutosave
        : l10n.smartRequestDraftSavedAt(
            TimeOfDay.fromDateTime(lastSavedAt!).format(context),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              savedLabel,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoPlaceholder({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
            l10n.smartRequestPhotoPlaceholder,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(l10n.smartRequestCamera),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library, size: 18),
                label: Text(l10n.smartRequestGallery),
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
    final l10n = AppLocalizations.of(context)!;
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
              l10n.smartRequestAddMorePhotos,
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
                        color: selected ? scheme.primary : scheme.onSurface,
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
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
