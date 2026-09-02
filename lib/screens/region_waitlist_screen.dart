import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/launch_regions.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/region_waitlist_service.dart';
import '../state/app_state.dart';
import '../theme/proserve_theme.dart';

class RegionWaitlistScreen extends StatefulWidget {
  const RegionWaitlistScreen({super.key});

  @override
  State<RegionWaitlistScreen> createState() => _RegionWaitlistScreenState();
}

class _RegionWaitlistScreenState extends State<RegionWaitlistScreen> {
  final _zipController = TextEditingController();
  final _waitlist = RegionWaitlistService();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileZip = AppState.of(context).profile['zip']?.toString() ?? '';
    if (_zipController.text.isEmpty && profileZip.isNotEmpty) {
      _zipController.text = normalizeZip(profileZip);
    }
  }

  @override
  void dispose() {
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _updateZip() async {
    final l10n = AppLocalizations.of(context)!;
    final appState = AppState.read(context);
    final zip = normalizeZip(_zipController.text);
    if (zip.length != 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.regionWaitlistInvalidZip)));
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = appState.profile;
      await _waitlist.saveAccountRegion(
        role: appState.role ?? 'customer',
        zip: zip,
        name: profile['name']?.toString(),
        email: profile['email']?.toString() ?? appState.user?.email,
        phone: profile['phone']?.toString(),
        service: profile['serviceNeeded']?.toString(),
        services: (profile['servicesOffered'] as List?)
            ?.map((item) => item.toString())
            .toList(),
      );

      if (!mounted) return;
      if (isSupportedLaunchZip(zip)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.regionWaitlistUnlocked)));
        context.go('/');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.regionWaitlistSaved)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.regionWaitlistSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = AppState.of(context);
    final profile = appState.profile;
    final role = appState.role ?? profile['role']?.toString() ?? '';
    final servicesText = (profile['servicesOffered'] as List?)
        ?.map((item) => item.toString())
        .take(2)
        .join(', ');
    final serviceNeeded = profile['serviceNeeded']?.toString().trim();
    final service = serviceNeeded?.isNotEmpty == true
        ? serviceNeeded!
        : (servicesText?.trim().isNotEmpty == true
              ? servicesText!
              : l10n.regionWaitlistServiceFallback);

    return Scaffold(
      backgroundColor: ProServeColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ProServeColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ProServeColors.accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: ProServeColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.regionWaitlistBadge(kLaunchRegionName),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ProServeColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                l10n.regionWaitlistTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.regionWaitlistBody,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ProServeColors.muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.account_circle_outlined,
                    label: l10n.regionWaitlistRole,
                    value: role.isEmpty
                        ? l10n.regionWaitlistRoleFallback
                        : role,
                  ),
                  _InfoRow(
                    icon: Icons.pin_drop_outlined,
                    label: l10n.regionWaitlistZip,
                    value:
                        normalizeZip(
                          profile['zip']?.toString() ?? '',
                        ).isNotEmpty
                        ? normalizeZip(profile['zip'].toString())
                        : l10n.regionWaitlistMissingZip,
                  ),
                  _InfoRow(
                    icon: Icons.handyman_outlined,
                    label: l10n.regionWaitlistService,
                    value: service,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _InfoCard(
                children: [
                  Text(
                    l10n.regionWaitlistUpdateTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.regionWaitlistUpdateBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ProServeColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _zipController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: l10n.regionWaitlistZipField,
                      prefixIcon: const Icon(Icons.location_searching_outlined),
                      filled: true,
                      fillColor: ProServeColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _updateZip,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(l10n.regionWaitlistUpdateCta),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.regionWaitlistSignOut),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ProServeColors.cardElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: ProServeColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ProServeColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
