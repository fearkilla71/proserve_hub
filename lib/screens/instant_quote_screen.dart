import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/price_guarantee_badge.dart';

/// Camera-first screen: snap → instant AI price → CTA to full request flow.
///
/// Supports no-signup first quote via anonymous auth — email capture after.
class InstantQuoteScreen extends StatefulWidget {
  const InstantQuoteScreen({super.key});

  @override
  State<InstantQuoteScreen> createState() => _InstantQuoteScreenState();
}

class _InstantQuoteScreenState extends State<InstantQuoteScreen> {
  XFile? _photo;
  String? _selectedService;
  String? _zip;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  static const _quickServices = <String, String>{
    'interior_painting': 'Interior Painting',
    'exterior_painting': 'Exterior Painting',
    'drywall_repair': 'Drywall Repair',
    'pressure_washing': 'Pressure Washing',
    'cabinets': 'Cabinet Painting',
    'roofing': 'Roofing',
    'flooring': 'Flooring',
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
  };

  @override
  void initState() {
    super.initState();
    _loadUserZip();
  }

  Future<void> _loadUserZip() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.data() != null && mounted) {
        setState(() => _zip = doc.data()!['zip'] as String?);
      }
    } catch (_) {}
  }

  // ─── Camera / Gallery ─────────────────────────────────────
  Future<void> _takePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _pickFromGallery() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  // ─── AI Estimate ──────────────────────────────────────────
  Future<void> _getInstantQuote() async {
    if (_photo == null || _selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a photo and select a service.'),
        ),
      );
      return;
    }
    if (_zip == null || _zip!.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your ZIP code.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // Support no-signup: sign in anonymously if needed.
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      }
      final uid = user!.uid;
      final estimateId = FirebaseFirestore.instance
          .collection('estimates')
          .doc()
          .id;

      // Upload photo.
      final bytes = await _photo!.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1920,
        minHeight: 1920,
        quality: 85,
      );
      final path = 'estimate_images/$estimateId/$uid/0_${_photo!.name}';
      await FirebaseStorage.instance
          .ref(path)
          .putData(Uint8List.fromList(compressed));

      // Call cloud function.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'estimateFromImagesInputs',
      );
      final res = await callable.call<dynamic>({
        'estimateId': estimateId,
        'service': _selectedService,
        'zip': _zip,
        'urgency': 'standard',
        'quantity': 0,
        'unit': 'sqft',
        'imagePaths': [path],
      });

      if (!mounted) return;
      setState(() {
        _result = Map<String, dynamic>.from(
          res.data as Map<dynamic, dynamic>? ?? {},
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not generate estimate. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Result view.
    if (_result != null) return _buildResultView(scheme);

    // Loading view.
    if (_loading) return _buildLoadingView(scheme);

    // Capture view.
    return _buildCaptureView(scheme);
  }

  // ─── Capture View ──────────────────────────────────────────
  Widget _buildCaptureView(ColorScheme scheme) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instant Quote')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Hero prompt
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.camera_alt, size: 48, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Snap a photo, get a price in seconds',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Our AI will analyze your project and give you an instant estimate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Photo area
          if (_photo == null)
            Row(
              children: [
                Expanded(
                  child: _BigButton(
                    icon: Icons.camera_alt,
                    label: 'Take Photo',
                    onTap: _takePhoto,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: _pickFromGallery,
                    primary: false,
                  ),
                ),
              ],
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FutureBuilder<Uint8List>(
                    future: _photo!.readAsBytes(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return Image.memory(
                        snap.data!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Service picker
          Text('Service', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickServices.entries.map((e) {
              final sel = _selectedService == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: sel,
                onSelected: (_) => setState(() => _selectedService = e.key),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ZIP
          TextField(
            decoration: InputDecoration(
              labelText: 'ZIP Code',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on_outlined),
              hintText: _zip ?? '12345',
            ),
            controller: TextEditingController(text: _zip ?? ''),
            maxLength: 5,
            keyboardType: TextInputType.number,
            onChanged: (v) => _zip = v,
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _getInstantQuote,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Get Instant Quote'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading View ──────────────────────────────────────────
  Widget _buildLoadingView(ColorScheme scheme) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instant Quote')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Analyzing your photo...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Our AI is estimating your project',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Result View ───────────────────────────────────────────
  Widget _buildResultView(ColorScheme scheme) {
    final price = (_result!['price'] as num?)?.toDouble() ?? 0;
    final confidence = (_result!['confidence'] as num?)?.toDouble() ?? 0;
    final notes = _result!['notes']?.toString() ?? '';
    final qty = (_result!['quantity'] as num?)?.toDouble() ?? 0;
    final serviceName =
        _quickServices[_selectedService] ?? _selectedService ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Your Estimate')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Price hero
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Text(
                    serviceName,
                    style: TextStyle(
                      fontSize: 16,
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estimated Price',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'AI Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Price Guarantee badge
          PriceGuaranteeBadge(estimatedPrice: price),

          const SizedBox(height: 16),

          if (qty > 0) ...[
            _detailTile(
              scheme,
              Icons.square_foot,
              'Estimated Size',
              '${qty.toStringAsFixed(0)} sqft',
            ),
          ],
          if (notes.isNotEmpty) ...[
            _detailTile(scheme, Icons.notes, 'AI Notes', notes),
          ],
          _detailTile(
            scheme,
            Icons.location_on_outlined,
            'ZIP Code',
            _zip ?? '',
          ),

          const SizedBox(height: 28),

          // Primary CTA: Get real quotes (email capture for anon users)
          FilledButton.icon(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && user.isAnonymous) {
                final captured = await _showEmailCapture(context);
                if (!captured && !context.mounted) return;
              }
              if (!context.mounted) return;
              context.go(
                '/smart-request',
                extra: {
                  'serviceType': _selectedService,
                  'serviceName': serviceName,
                },
              );
            },
            icon: const Icon(Icons.groups),
            label: const Text('Get Real Quotes from Pros'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA: Try another
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _result = null;
                _photo = null;
              });
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Try Another Photo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Email Capture for Anonymous Users ──────────────────
  Future<bool> _showEmailCapture(BuildContext context) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save Your Quote',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a free account to get quotes from real pros and track your project.',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final email = emailCtrl.text.trim();
                    final pass = passCtrl.text.trim();
                    if (email.isEmpty || pass.length < 6) return;
                    try {
                      final cred = EmailAuthProvider.credential(
                        email: email,
                        password: pass,
                      );
                      await FirebaseAuth.instance.currentUser
                          ?.linkWithCredential(cred);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (_) {
                      if (ctx.mounted) Navigator.pop(ctx, false);
                    }
                  },
                  child: const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        );
      },
    );
    return result ?? true; // default: proceed even if dismissed
  }

  Widget _detailTile(
    ColorScheme scheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: primary ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: primary ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primary ? scheme.primary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
