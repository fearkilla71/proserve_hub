import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/version_check_service.dart';
import '../utils/legal_documents.dart';
import '../widgets/skeleton_loader.dart';
import 'legal_doc_screen.dart';

class ContractorProfileScreen extends StatefulWidget {
  const ContractorProfileScreen({super.key});

  @override
  State<ContractorProfileScreen> createState() =>
      _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends State<ContractorProfileScreen> {
  bool _loading = true;
  bool _working = false;
  bool _uploadingLogo = false;

  String _companyName = '';
  String _userName = '';
  String _email = '';
  String _logoUrl = '';

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
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userSnap.data() ?? <String, dynamic>{};
      _userName = (userData['name'] as String?)?.trim() ?? '';

      final contractorSnap = await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .get();
      final contractorData = contractorSnap.data() ?? <String, dynamic>{};
      _companyName =
          (contractorData['businessName'] as String?)?.trim() ??
          (contractorData['companyName'] as String?)?.trim() ??
          (contractorData['name'] as String?)?.trim() ??
          '';

      _logoUrl =
          (contractorData['logoUrl'] as String?)?.trim() ??
          (contractorData['businessLogoUrl'] as String?)?.trim() ??
          '';
    } catch (_) {
      // Keep form empty if load fails.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<({Uint8List bytes, String contentType, String ext})?>
  _pickLogoImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final ext = (file.extension ?? 'jpg').toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };

    return (bytes: bytes, contentType: contentType, ext: ext);
  }

  Future<void> _setLogo() async {
    if (_uploadingLogo || _working) return;

    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picked = await _pickLogoImage();
    if (picked == null) return;

    setState(() => _uploadingLogo = true);

    try {
      final storage = FirebaseStorage.instance;
      final path = 'contractor_logos/${user.uid}/logo.${picked.ext}';
      final ref = storage.ref().child(path);

      await ref.putData(
        picked.bytes,
        SettableMetadata(contentType: picked.contentType),
      );
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('contractors')
          .doc(user.uid)
          .set({
            'logoUrl': url,
            'logoUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _logoUrl = url);
      messenger.showSnackBar(const SnackBar(content: Text('Logo updated.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update logo: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
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
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const ProfileSkeleton()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _uploadingLogo ? null : _setLogo,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundImage: (_logoUrl.trim().isNotEmpty)
                              ? CachedNetworkImageProvider(_logoUrl.trim())
                              : null,
                          child: (_logoUrl.trim().isNotEmpty)
                              ? null
                              : Icon(
                                  Icons.image_outlined,
                                  size: 34,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                        ),
                        if (_uploadingLogo)
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    (_logoUrl.trim().isNotEmpty)
                        ? 'Tap logo to change'
                        : 'Tap to add logo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    (_companyName.isNotEmpty ? _companyName : 'Your Company'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    (_userName.isNotEmpty
                        ? _userName
                        : ((_email.isNotEmpty ? _email.split('@').first : '')
                                  .trim()
                                  .isNotEmpty
                              ? _email.split('@').first.trim()
                              : 'Contractor')),
                    style: Theme.of(context).textTheme.bodyLarge,
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
                  title: const Text('Reset password'),
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
                  'Get alerts when customers send you new leads or messages.',
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
