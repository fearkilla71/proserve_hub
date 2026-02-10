import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../utils/zip_locations.dart';
import '../widgets/contractor_card.dart';
import '../widgets/skeleton_loader.dart';
import '../models/contractor_badge.dart';
import '../widgets/badge_widget.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();

  // Contractor-only
  final _bioController = TextEditingController();
  final _yearsExpController = TextEditingController();
  final _publicNameController = TextEditingController();
  final _publicPhoneController = TextEditingController();
  final _headlineController = TextEditingController();
  String _cardTheme = 'navy';
  int? _gradientStart;
  int? _gradientEnd;
  String _avatarStyle = 'monogram';
  String _avatarShape = 'circle';
  String _texture = 'none';
  double _textureOpacity = 0.12;
  bool _showBanner = true;
  String _bannerIcon = 'spark';
  bool _avatarGlow = false;
  List<String> _selectedBadges = [];
  int _totalJobsCompleted = 0;
  int _reviewCount = 0;
  double _avgRating = 0.0;

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  String _role = 'customer';

  final List<_ThemePreset> _themePresets = const [
    _ThemePreset('navy', 'Navy', Color(0xFF0F172A), Color(0xFF2563EB)),
    _ThemePreset('forest', 'Forest', Color(0xFF0F3D2E), Color(0xFF3BAA6B)),
    _ThemePreset('amber', 'Amber', Color(0xFF4E2A0C), Color(0xFFFFA726)),
    _ThemePreset('slate', 'Slate', Color(0xFF1F2937), Color(0xFF64748B)),
    _ThemePreset('rose', 'Rose', Color(0xFF4A1D2D), Color(0xFFF472B6)),
  ];

  final List<Color> _gradientPalette = const [
    Color(0xFF0F172A),
    Color(0xFF1F2937),
    Color(0xFF2563EB),
    Color(0xFF0F3D2E),
    Color(0xFF3BAA6B),
    Color(0xFF4E2A0C),
    Color(0xFFFFA726),
    Color(0xFF4A1D2D),
    Color(0xFFF472B6),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _bioController.dispose();
    _yearsExpController.dispose();
    _publicNameController.dispose();
    _publicPhoneController.dispose();
    _headlineController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userSnap.data() ?? <String, dynamic>{};
      final role = (userData['role'] ?? '').toString().trim().toLowerCase();

      _nameController.text = (userData['name'] ?? '').toString();
      _phoneController.text = (userData['phone'] ?? '').toString();
      _addressController.text = (userData['address'] ?? '').toString();
      _zipController.text = (userData['zip'] ?? '').toString();
      _role = role.isEmpty ? _role : role;

      if (_role == 'contractor') {
        final contractorSnap = await FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .get();
        final data = contractorSnap.data() ?? <String, dynamic>{};

        _yearsExpController.text = (data['yearsExperience'] ?? '').toString();
        _bioController.text = (data['bio'] ?? '').toString();
        _publicNameController.text = (data['publicName'] ?? '').toString();
        _publicPhoneController.text = (data['publicPhone'] ?? '').toString();
        _headlineController.text = (data['headline'] ?? '').toString();

        _cardTheme =
            (data['cardTheme'] as String?)?.trim().toLowerCase() ?? _cardTheme;
        _gradientStart = _toColorInt(data['gradientStart']);
        _gradientEnd = _toColorInt(data['gradientEnd']);
        _avatarStyle = (data['avatarStyle'] as String?)?.trim() ?? _avatarStyle;
        _avatarShape = (data['avatarShape'] as String?)?.trim() ?? _avatarShape;
        _texture = (data['cardTexture'] as String?)?.trim() ?? _texture;
        final opacityRaw = data['textureOpacity'];
        if (opacityRaw is num) {
          _textureOpacity = opacityRaw.toDouble().clamp(0.04, 0.5);
        }
        _showBanner = data['showBanner'] as bool? ?? _showBanner;
        _bannerIcon = (data['bannerIcon'] as String?)?.trim() ?? _bannerIcon;
        _avatarGlow = data['avatarGlow'] as bool? ?? _avatarGlow;
        _selectedBadges =
            (data['badges'] as List?)?.whereType<String>().toList() ?? [];
        _totalJobsCompleted =
            (data['totalJobsCompleted'] as num?)?.toInt() ?? 0;
        _reviewCount =
            (data['reviewCount'] as num?)?.toInt() ??
            (data['totalReviews'] as num?)?.toInt() ??
            0;
        _avgRating =
            (data['avgRating'] as num?)?.toDouble() ??
            (data['averageRating'] as num?)?.toDouble() ??
            0.0;
      }
    } catch (_) {
      // Keep form empty if load fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'zip': _zipController.text.trim(),
        'role': _role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_role == 'contractor') {
        await FirebaseFirestore.instance
            .collection('contractors')
            .doc(user.uid)
            .set({
              'publicName': _publicNameController.text.trim(),
              'publicPhone': _publicPhoneController.text.trim(),
              'headline': _headlineController.text.trim(),
              'bio': _bioController.text.trim(),
              'yearsExperience':
                  int.tryParse(_yearsExpController.text.trim()) ?? 0,
              'cardTheme': _cardTheme,
              'gradientStart': _gradientStart,
              'gradientEnd': _gradientEnd,
              'avatarStyle': _avatarStyle,
              'avatarShape': _avatarShape,
              'cardTexture': _texture,
              'textureOpacity': _textureOpacity,
              'showBanner': _showBanner,
              'bannerIcon': _bannerIcon,
              'avatarGlow': _avatarGlow,
              'badges': _selectedBadges,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateZip(String? value) {
    final zip = (value ?? '').trim();
    if (zip.isEmpty) return 'ZIP code is required.';
    if (zip.length != 5 || int.tryParse(zip) == null) {
      return 'Enter a valid 5-digit ZIP.';
    }
    if (!zipLocations.containsKey(zip)) {
      return 'ZIP not supported yet.';
    }
    return null;
  }

  Future<void> _fillFromLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final result = await LocationService().getCurrentZipAndCity();
      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location unavailable.')));
        return;
      }

      if (result.zip.isNotEmpty) {
        _zipController.text = result.zip;
      }
      if (_addressController.text.trim().isEmpty) {
        final location = result.formatCityState();
        if (location.isNotEmpty) {
          _addressController.text = location;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location error: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  int? _toColorInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  InputDecoration _fieldDecoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _expandableSectionCard({
    required String title,
    required Widget child,
    String? subtitle,
    IconData? icon,
    bool initiallyExpanded = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        subtitle: subtitle == null || subtitle.trim().isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
        children: [child],
      ),
    );
  }

  Widget _themePresetChip(_ThemePreset preset) {
    final selected = _cardTheme == preset.key;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [preset.start, preset.end]),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 6),
          Text(preset.label),
        ],
      ),
      onSelected: (isSelected) {
        if (!isSelected) return;
        setState(() {
          _cardTheme = preset.key;
          _gradientStart = preset.start.toARGB32();
          _gradientEnd = preset.end.toARGB32();
        });
      },
    );
  }

  Widget _colorChip({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  List<Color> _defaultGradientForTheme(String theme) {
    final match = _themePresets
        .where((preset) => preset.key == theme)
        .toList(growable: false);
    if (match.isNotEmpty) {
      return [match.first.start, match.first.end];
    }
    return [const Color(0xFF0F172A), const Color(0xFF2563EB)];
  }

  ContractorCardData _previewCardData() {
    final defaultGradient = _defaultGradientForTheme(_cardTheme);
    final gradientStart = _gradientStart != null
        ? Color(_gradientStart!)
        : defaultGradient[0];
    final gradientEnd = _gradientEnd != null
        ? Color(_gradientEnd!)
        : defaultGradient[1];
    return ContractorCardData(
      displayName: _publicNameController.text.trim().isNotEmpty
          ? _publicNameController.text.trim()
          : 'Summit Builders Co.',
      contactLine: _publicPhoneController.text.trim().isNotEmpty
          ? _publicPhoneController.text.trim()
          : 'Licensed / Insured',
      logoUrl: '',
      headline: _headlineController.text.trim().isNotEmpty
          ? _headlineController.text.trim()
          : 'Luxury kitchen and bath transformations',
      bio: _bioController.text.trim(),
      ratingValue: 4.9,
      reviewCount: 38,
      yearsExp: int.tryParse(_yearsExpController.text.trim()) ?? 7,
      badges: _selectedBadges.isNotEmpty
          ? _selectedBadges
          : ['licensed', 'insured', 'top_rated'],
      themeKey: _cardTheme,
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
      avatarStyle: _avatarStyle,
      avatarShape: _avatarShape,
      texture: _texture,
      textureOpacity: _textureOpacity,
      showBanner: _showBanner,
      bannerIcon: _bannerIcon,
      avatarGlow: _avatarGlow,
      latestReview: 'Quick response and flawless finish.',
      totalJobsCompleted: _totalJobsCompleted,
    );
  }

  void _randomizeCard() {
    final rand = math.Random();
    final preset = _themePresets[rand.nextInt(_themePresets.length)];
    final usePreset = rand.nextBool();
    final start = _gradientPalette[rand.nextInt(_gradientPalette.length)];
    Color end = _gradientPalette[rand.nextInt(_gradientPalette.length)];
    while (end.toARGB32() == start.toARGB32()) {
      end = _gradientPalette[rand.nextInt(_gradientPalette.length)];
    }

    const avatarStyles = ['monogram', 'logo'];
    const avatarShapes = ['circle', 'hex', 'shield'];
    const textures = ['none', 'dots', 'grid', 'waves'];
    const bannerIcons = ['spark', 'bolt', 'shield', 'star', 'check'];

    final badgePool = profileBadges.map((b) => b.id).toList()..shuffle(rand);
    final badgeCount = 2 + rand.nextInt(3);

    setState(() {
      if (usePreset) {
        _cardTheme = preset.key;
        _gradientStart = preset.start.toARGB32();
        _gradientEnd = preset.end.toARGB32();
      } else {
        _cardTheme = 'custom';
        _gradientStart = start.toARGB32();
        _gradientEnd = end.toARGB32();
      }

      _avatarStyle = avatarStyles[rand.nextInt(avatarStyles.length)];
      _avatarShape = avatarShapes[rand.nextInt(avatarShapes.length)];
      _texture = textures[rand.nextInt(textures.length)];
      _textureOpacity = _texture == 'none'
          ? 0.12
          : 0.08 + (rand.nextDouble() * 0.22);
      _showBanner = rand.nextBool();
      _bannerIcon = bannerIcons[rand.nextInt(bannerIcons.length)];
      _avatarGlow = rand.nextBool();
      _selectedBadges = badgePool.take(badgeCount).toList();
    });
  }

  Widget _bannerIconChip(String key, String label, IconData icon) {
    final selected = _bannerIcon == key;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      onSelected: (isSelected) {
        if (!isSelected) return;
        setState(() => _bannerIcon = key);
      },
    );
  }

  Widget _optionGroup({required String title, required List<Widget> children}) {
    return ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _headerCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.tertiary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.person, color: scheme.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your details so clients can trust and contact you.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: (_loading || _saving) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: _loading
          ? const ProfileSkeleton()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _headerCard(),
                  const SizedBox(height: 16),
                  _expandableSectionCard(
                    title: 'Your details',
                    subtitle: 'This helps clients recognize and contact you.',
                    icon: Icons.badge_outlined,
                    initiallyExpanded: false,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: _fieldDecoration(
                            label: 'Full name',
                            icon: Icons.person_outline,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Name is required.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: _fieldDecoration(
                            label: 'Phone',
                            icon: Icons.phone_outlined,
                          ),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Phone is required.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          decoration: _fieldDecoration(
                            label: 'Address',
                            icon: Icons.location_on_outlined,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Address is required.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _zipController,
                          decoration: _fieldDecoration(
                            label: 'ZIP code',
                            icon: Icons.markunread_mailbox_outlined,
                            hint: 'e.g. 77005',
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: _validateZip,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(
                              _locating
                                  ? 'Finding your location...'
                                  : 'Use my location',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_role == 'contractor') ...[
                    const SizedBox(height: 16),
                    _expandableSectionCard(
                      title: 'Contractor details',
                      subtitle: 'Showcase your experience and skills.',
                      icon: Icons.handyman_outlined,
                      initiallyExpanded: false,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _yearsExpController,
                            decoration: _fieldDecoration(
                              label: 'Years of experience',
                              icon: Icons.timeline,
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bioController,
                            decoration: _fieldDecoration(
                              label: 'Bio/description',
                              icon: Icons.short_text,
                              hint:
                                  'Describe your specialties and recent work.',
                            ),
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _expandableSectionCard(
                      title: 'Public contractor card',
                      subtitle:
                          'Customize how customers and other contractors see you.',
                      icon: Icons.badge_outlined,
                      initiallyExpanded: true,
                      child: Column(
                        children: [
                          ContractorCard(
                            data: _previewCardData(),
                            showEdit: false,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _randomizeCard,
                              icon: const Icon(Icons.shuffle),
                              label: const Text('Randomize card'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _optionGroup(
                            title: 'Card details',
                            children: [
                              TextFormField(
                                controller: _publicNameController,
                                decoration: _fieldDecoration(
                                  label: 'Display name',
                                  icon: Icons.storefront_outlined,
                                  hint: 'e.g. Franco Renovations',
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _publicPhoneController,
                                decoration: _fieldDecoration(
                                  label: 'Public phone',
                                  icon: Icons.phone_outlined,
                                ),
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _headlineController,
                                decoration: _fieldDecoration(
                                  label: 'Headline',
                                  icon: Icons.star_outline,
                                  hint: 'Short, customer-facing tagline',
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                          ),
                          _optionGroup(
                            title: 'Theme presets',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _themePresets
                                    .map(_themePresetChip)
                                    .toList(),
                              ),
                            ],
                          ),
                          _optionGroup(
                            title: 'Gradient start',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _gradientPalette.map((color) {
                                  final selected =
                                      _gradientStart == color.toARGB32();
                                  return _colorChip(
                                    color: color,
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        _gradientStart = color.toARGB32();
                                        _cardTheme = 'custom';
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          _optionGroup(
                            title: 'Gradient end',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _gradientPalette.map((color) {
                                  final selected =
                                      _gradientEnd == color.toARGB32();
                                  return _colorChip(
                                    color: color,
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        _gradientEnd = color.toARGB32();
                                        _cardTheme = 'custom';
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          _optionGroup(
                            title: 'Avatar',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Monogram'),
                                    selected: _avatarStyle == 'monogram',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _avatarStyle = 'monogram');
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Logo'),
                                    selected: _avatarStyle == 'logo',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _avatarStyle = 'logo');
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Circle'),
                                    selected: _avatarShape == 'circle',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _avatarShape = 'circle');
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Hex'),
                                    selected: _avatarShape == 'hex',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _avatarShape = 'hex');
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Shield'),
                                    selected: _avatarShape == 'shield',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _avatarShape = 'shield');
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                value: _avatarGlow,
                                onChanged: (value) {
                                  setState(() => _avatarGlow = value);
                                },
                                title: const Text('Avatar glow'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          _optionGroup(
                            title: 'Texture',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('None'),
                                    selected: _texture == 'none',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _texture = 'none');
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Dots'),
                                    selected: _texture == 'dots',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _texture = 'dots');
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Grid'),
                                    selected: _texture == 'grid',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _texture = 'grid');
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Waves'),
                                    selected: _texture == 'waves',
                                    onSelected: (selected) {
                                      if (!selected) return;
                                      setState(() => _texture = 'waves');
                                    },
                                  ),
                                ],
                              ),
                              if (_texture != 'none') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Opacity'),
                                    Expanded(
                                      child: Slider(
                                        value: _textureOpacity,
                                        min: 0.04,
                                        max: 0.4,
                                        divisions: 6,
                                        label: _textureOpacity.toStringAsFixed(
                                          2,
                                        ),
                                        onChanged: (value) {
                                          setState(
                                            () => _textureOpacity = value,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          _optionGroup(
                            title: 'Status Banner',
                            children: [
                              Text(
                                'Shows your tier level, jobs completed, and a decorative icon at the top of your card.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                value: _showBanner,
                                onChanged: (value) {
                                  setState(() => _showBanner = value);
                                },
                                title: const Text('Show status banner'),
                                subtitle: const Text(
                                  'Displays your rank and stats',
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              if (_showBanner) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Banner accent icon',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _bannerIconChip(
                                      'spark',
                                      'Spark',
                                      Icons.auto_awesome,
                                    ),
                                    _bannerIconChip('bolt', 'Bolt', Icons.bolt),
                                    _bannerIconChip(
                                      'shield',
                                      'Shield',
                                      Icons.shield_outlined,
                                    ),
                                    _bannerIconChip(
                                      'star',
                                      'Star',
                                      Icons.star_outline,
                                    ),
                                    _bannerIconChip(
                                      'check',
                                      'Verified',
                                      Icons.verified_outlined,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          _optionGroup(
                            title: 'Profile Badges',
                            children: [
                              Text(
                                'Select badges that represent your business. These appear on your public card.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 12,
                                children: profileBadges.map((badge) {
                                  final selected =
                                      _selectedBadges.contains(badge.id) ||
                                      _selectedBadges.contains(badge.label);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          _selectedBadges = _selectedBadges
                                              .where(
                                                (id) =>
                                                    id != badge.id &&
                                                    id != badge.label,
                                              )
                                              .toList();
                                        } else {
                                          _selectedBadges = [
                                            ..._selectedBadges,
                                            badge.id,
                                          ];
                                        }
                                      });
                                    },
                                    onLongPress: () =>
                                        showBadgeDetail(context, badge),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? badge.color.withValues(
                                                alpha: 0.15,
                                              )
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selected
                                              ? badge.color.withValues(
                                                  alpha: 0.5,
                                                )
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          BadgeWidget(
                                            badge: badge,
                                            size: BadgeSize.small,
                                            showLabel: false,
                                            earned: selected,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            badge.label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? badge.color
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          _optionGroup(
                            title: 'Achievements',
                            children: [
                              Text(
                                'Badges earned automatically based on your performance. Complete jobs and earn reviews to unlock more!',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final earnedIds = computeEarnedAchievements(
                                    totalJobsCompleted: _totalJobsCompleted,
                                    reviewCount: _reviewCount,
                                    avgRating: _avgRating,
                                  );
                                  final allAchievements = achievementBadges;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 14,
                                    children: allAchievements.map((badge) {
                                      final isEarned = earnedIds.contains(
                                        badge.id,
                                      );
                                      return GestureDetector(
                                        onTap: () => showBadgeDetail(
                                          context,
                                          badge,
                                          earned: isEarned,
                                        ),
                                        child: BadgeWidget(
                                          badge: badge,
                                          size: BadgeSize.medium,
                                          showLabel: true,
                                          earned: isEarned,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving...' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ThemePreset {
  const _ThemePreset(this.key, this.label, this.start, this.end);

  final String key;
  final String label;
  final Color start;
  final Color end;
}
