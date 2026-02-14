import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/version_check_service.dart';
import '../state/app_state.dart';
import '../utils/legal_documents.dart';
import '../widgets/skeleton_loader.dart';
import 'legal_doc_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _loading = true;
  bool _working = false;

  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    _email = (user.email ?? '').trim();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? <String, dynamic>{};

      _name = (data['name'] as String?)?.trim() ?? '';
    } catch (_) {
      // Keep form empty if load fails.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _languageLabel(Locale? locale) {
    if (locale == null) return 'System default';
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      default:
        return locale.languageCode;
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final appState = AppState.read(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('System default'),
                trailing: appState.locale == null
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  appState.setLocale(null);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('English'),
                trailing: appState.locale?.languageCode == 'en'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  appState.setLocale(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Español'),
                trailing: appState.locale?.languageCode == 'es'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  appState.setLocale(const Locale('es'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Français'),
                trailing: appState.locale?.languageCode == 'fr'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  appState.setLocale(const Locale('fr'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openDoc({required String title, required String body}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocScreen(title: title, body: body),
      ),
    );
  }

  Future<void> _setPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    if (user == null || email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No email found for this account.')),
      );
      return;
    }

    setState(() => _working = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send email: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _allowPushNotifications() async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _working = true);
    try {
      await FcmService.syncTokenOnce();
      final ok = await FcmService.hasPermission();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Notifications enabled.'
                : 'Notifications permission not granted.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to enable notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Signed out.')));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: _loading
          ? const ProfileSkeleton()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 24),
                Center(
                  child: CircleAvatar(
                    radius: 38,
                    child: Icon(
                      Icons.person,
                      size: 38,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    (_name.isNotEmpty ? _name : 'Customer'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const Text('Set password'),
                  onTap: _working ? null : _setPassword,
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  'Notification settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Get alerts when pros send you cost estimates or messages.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _working ? null : _allowPushNotifications,
                    child: Text(
                      _working ? 'Working…' : 'Allow Push Notifications',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  subtitle: Text(_languageLabel(AppState.of(context).locale)),
                  onTap: () => _showLanguagePicker(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Contact Support'),
                  subtitle: const Text('support@proservehub.app'),
                  onTap: () =>
                      launchUrl(Uri.parse('mailto:support@proservehub.app')),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Help'),
                  onTap: () =>
                      _openDoc(title: 'Help', body: LegalDocuments.help()),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Privacy Policy'),
                  onTap: () => _openDoc(
                    title: 'Privacy Policy',
                    body: LegalDocuments.privacyPolicy(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('CA Notice at Collection'),
                  onTap: () => _openDoc(
                    title: 'CA Notice at Collection',
                    body: LegalDocuments.caNoticeAtCollection(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Terms of Use'),
                  onTap: () => _openDoc(
                    title: 'Terms of Use',
                    body: LegalDocuments.termsOfUse(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Report a technical problem'),
                  onTap: () => _openDoc(
                    title: 'Report a technical problem',
                    body: LegalDocuments.reportTechnicalProblem(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Do not sell or share my info'),
                  onTap: () => _openDoc(
                    title: 'Do not sell or share my info',
                    body: LegalDocuments.doNotSellOrShare(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Deactivate account'),
                  onTap: () => _openDoc(
                    title: 'Deactivate account',
                    body: LegalDocuments.deactivateAccount(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Delete my account data'),
                  onTap: () => _openDoc(
                    title: 'Delete my account data',
                    body: LegalDocuments.deleteAccountData(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Sign out'),
                  onTap: _working ? null : _signOut,
                ),
                const SizedBox(height: 20),
                Center(
                  child: FutureBuilder<String>(
                    future: VersionCheckService.currentVersionLabel(),
                    builder: (context, snap) => Text(
                      snap.data ?? 'Version …',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
