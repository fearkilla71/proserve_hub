import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
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

  String _languageLabel(BuildContext context, Locale? locale) {
    final l10n = AppLocalizations.of(context)!;
    if (locale == null) return l10n.languageSystemDefault;
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return locale.languageCode;
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final appState = AppState.read(context);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectLanguage,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: Text(l10n.languageSystemDefault),
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
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    if (user == null || email.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noEmailFound)));
      return;
    }

    setState(() => _working = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passwordResetEmailSent(email))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failedToSendEmail(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _allowPushNotifications() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _working = true);
    try {
      await FcmService.syncTokenOnce();
      final ok = await FcmService.hasPermission();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.notificationsEnabled
                : l10n.notificationsPermissionNotGranted,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failedToEnableNotifications(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working = true);
    try {
      await AuthService().signOut();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.signedOut)));
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.signOutFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.you)),
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
                    (_name.isNotEmpty ? _name : l10n.customer),
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
                  title: Text(l10n.setPassword),
                  onTap: _working ? null : _setPassword,
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  l10n.notificationSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.notificationSettingsDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _working ? null : _allowPushNotifications,
                    child: Text(
                      _working ? l10n.working : l10n.allowPushNotifications,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.language),
                  subtitle: Text(
                    _languageLabel(context, AppState.of(context).locale),
                  ),
                  onTap: () => _showLanguagePicker(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(l10n.contactSupport),
                  subtitle: const Text('support@proservehub.app'),
                  onTap: () =>
                      launchUrl(Uri.parse('mailto:support@proservehub.app')),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.help),
                  onTap: () =>
                      _openDoc(title: l10n.help, body: LegalDocuments.help()),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.privacyPolicy),
                  onTap: () => _openDoc(
                    title: l10n.privacyPolicy,
                    body: LegalDocuments.privacyPolicy(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.caNoticeAtCollection),
                  onTap: () => _openDoc(
                    title: l10n.caNoticeAtCollection,
                    body: LegalDocuments.caNoticeAtCollection(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.termsOfUse),
                  onTap: () => _openDoc(
                    title: l10n.termsOfUse,
                    body: LegalDocuments.termsOfUse(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.reportTechnicalProblem),
                  onTap: () => _openDoc(
                    title: l10n.reportTechnicalProblem,
                    body: LegalDocuments.reportTechnicalProblem(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.doNotSellOrShareMyInfo),
                  onTap: () => _openDoc(
                    title: l10n.doNotSellOrShareMyInfo,
                    body: LegalDocuments.doNotSellOrShare(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.deactivateAccount),
                  onTap: () => _openDoc(
                    title: l10n.deactivateAccount,
                    body: LegalDocuments.deactivateAccount(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.deleteAccountData),
                  onTap: () => _openDoc(
                    title: l10n.deleteAccountData,
                    body: LegalDocuments.deleteAccountData(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.signOut),
                  onTap: _working ? null : _signOut,
                ),
                const SizedBox(height: 20),
                Center(
                  child: FutureBuilder<String>(
                    future: VersionCheckService.currentVersionLabel(),
                    builder: (context, snap) => Text(
                      snap.data ?? l10n.versionLoading,
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
