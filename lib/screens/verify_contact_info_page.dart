import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'contractor_portal_page.dart';
import 'customer_portal_page.dart';
import 'contractor_signup_pitch_page.dart';
import 'landing_page.dart';

class VerifyContactInfoPage extends StatefulWidget {
  const VerifyContactInfoPage({super.key, this.showPitchAfterVerify = false});

  final bool showPitchAfterVerify;

  @override
  State<VerifyContactInfoPage> createState() => _VerifyContactInfoPageState();
}

class _VerifyContactInfoPageState extends State<VerifyContactInfoPage>
    with WidgetsBindingObserver {
  final _db = FirebaseFirestore.instance;

  bool _sendingEmail = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _continuing = false;

  int _sendCooldownSeconds = 0;
  Timer? _sendCooldownTimer;

  String? _verificationId;
  int? _forceResendingToken;

  bool _navigated = false;

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  Future<void> _configurePhoneAuthForDevelopment() async {
    // In debug builds, allow phone auth testing without Play Integrity / reCAPTCHA
    // blocking development. This does NOT apply to release builds.
    if (!kDebugMode) return;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
        // On Android emulators, Play Integrity often fails. For development,
        // force the web reCAPTCHA flow instead of device verification.
        forceRecaptchaFlow: defaultTargetPlatform == TargetPlatform.android,
      );
    } catch (_) {
      // Best-effort; if it fails we'll fall back to normal behavior.
    }
  }

  String _phoneAuthErrorMessage(FirebaseAuthException e) {
    final raw = (e.message ?? '').trim();
    final lower = raw.toLowerCase();

    if (e.code == 'too-many-requests') {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (e.code == 'invalid-phone-number') {
      return 'That phone number looks invalid. Use E.164 format (example: +15551234567).';
    }
    if (e.code == 'quota-exceeded') {
      return 'SMS quota exceeded for this project. Try again later or use a different phone number.';
    }

    // Common Android setup issue: Play Integrity / app identifier.
    if (e.code == 'missing-client-identifier' ||
        lower.contains('missing a valid app identifier') ||
        lower.contains('play integrity') ||
        lower.contains('recaptcha')) {
      return 'Phone verification is blocked by Android app verification (Play Integrity/reCAPTCHA).\n'
          'Fix: add SHA-256 (and SHA-1) fingerprints in Firebase Console → Project Settings → Your apps, then download the updated google-services.json and rebuild.\n'
          'Dev tip: in debug builds you can use Firebase Auth test phone numbers.';
    }

    if (raw.isNotEmpty) return raw;
    return 'Phone verification failed (${e.code}).';
  }

  String _normalizePhoneForE164(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    // If user already provided E.164, keep it.
    if (trimmed.startsWith('+')) return trimmed;

    // Remove common formatting characters.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    // Convenience for US numbers: 10 digits -> +1XXXXXXXXXX
    if (digits.length == 10) return '+1$digits';

    // US numbers sometimes entered as 1XXXXXXXXXX.
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';

    // Fall back to original (Firebase will error with a helpful message).
    return trimmed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendCooldownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeAutoContinue();
    }
  }

  void _startSendCooldown([int seconds = 45]) {
    _sendCooldownTimer?.cancel();
    setState(() => _sendCooldownSeconds = seconds);
    _sendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_sendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _sendCooldownSeconds = 0);
      } else {
        setState(() => _sendCooldownSeconds -= 1);
      }
    });
  }

  User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('VerifyContactInfoPage requires a signed-in user.');
    }
    return user;
  }

  Future<Map<String, dynamic>> _loadUserDoc() async {
    final snap = await _db.collection('users').doc(_user.uid).get();
    return snap.data() ?? <String, dynamic>{};
  }

  bool _isPhoneVerified(Map<String, dynamic> data, User user) {
    // Prefer explicit app-side marker (works even if phone isn’t linked as an auth provider).
    final verified = data['phoneVerified'] as bool?;
    if (verified == true) return true;

    if (data['phoneVerifiedAt'] != null) return true;

    // If the user is linked with phone provider, we can also treat that as verified.
    final phone = (user.phoneNumber ?? '').trim();
    return phone.isNotEmpty;
  }

  Future<void> _resendEmailVerification() async {
    if (_sendingEmail) return;
    setState(() => _sendingEmail = true);

    try {
      final user = _user;
      final email = (user.email ?? '').trim();
      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'No email address is attached to this account.',
        );
      }
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification email sent to $email. Check Spam/Promotions, or search for “Firebase” or “verify”.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'too-many-requests':
          message =
              'Too many requests. Please wait a few minutes and try again.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection and try again.';
          break;
        case 'missing-email':
          message =
              e.message ?? 'No email address is attached to this account.';
          break;
        default:
          message = e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'Could not send email (${e.code}).';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send email: $e')));
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  Future<void> _refreshStatus() async {
    try {
      await _user.reload();
    } catch (_) {
      // Ignore; status will update next auth refresh.
    }

    if (!mounted) return;
    setState(() {
      // Rebuild.
    });
  }

  Future<void> _continueIntoApp() async {
    if (_continuing) return;
    setState(() => _continuing = true);

    try {
      await _refreshStatus();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final data = await _loadUserDoc();
      final emailOk = user.emailVerified;
      final phoneOk = _isPhoneVerified(data, user);

      if (!emailOk || !phoneOk) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify both email and phone first.'),
          ),
        );
        return;
      }

      Widget destination;

      final role = (data['role'] as String?)?.trim().toLowerCase();
      if (role == 'customer') {
        destination = const CustomerPortalPage();
      } else if (role == 'contractor') {
        if (widget.showPitchAfterVerify) {
          destination = const ContractorSignupPitchPage();
        } else {
          destination = const ContractorPortalPage();
        }
      } else {
        // Backward-compatible fallback: if they have contractors/{uid}, treat
        // as contractor and backfill role.
        final contractorSnap = await _db
            .collection('contractors')
            .doc(user.uid)
            .get();
        if (contractorSnap.exists) {
          try {
            await _db.collection('users').doc(user.uid).set({
              'role': 'contractor',
            }, SetOptions(merge: true));
          } catch (_) {
            // Best-effort.
          }
          destination = const ContractorPortalPage();
        } else {
          destination = const CustomerPortalPage();
        }
      }

      if (!mounted) return;
      _navigated = true;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (r) => false,
      );
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  Future<void> _maybeAutoContinue() async {
    if (_navigated || _continuing) return;
    try {
      await _refreshStatus();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final data = await _loadUserDoc();
      final emailOk = user.emailVerified;
      final phoneOk = _isPhoneVerified(data, user);
      if (emailOk && phoneOk) {
        await _continueIntoApp();
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  Future<void> _sendPhoneCode() async {
    if (_sendingCode) return;
    if (_sendCooldownSeconds > 0) return;

    final phone = _normalizePhoneForE164(_phoneController.text);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a phone number.')));
      return;
    }

    setState(() => _sendingCode = true);

    try {
      await _configurePhoneAuthForDevelopment();
      _startSendCooldown();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: _forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval (Android) — attempt to link/update immediately.
          try {
            await _applyPhoneCredential(credential, phone);
          } catch (_) {
            // Ignore; user can still enter SMS code manually.
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          final msg = _phoneAuthErrorMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
          );
        },
        codeSent: (String verificationId, int? forceResendingToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _forceResendingToken = forceResendingToken;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Code sent.')));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_phoneAuthErrorMessage(e)),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send code: $e')));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _verifyPhoneCode() async {
    if (_verifyingCode) return;

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Send a code first.')));
      return;
    }

    final smsCode = _codeController.text.trim();
    if (smsCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the SMS code.')));
      return;
    }

    final phone = _normalizePhoneForE164(_phoneController.text);

    setState(() => _verifyingCode = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _applyPhoneCredential(credential, phone);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone verified.')));
      await _refreshStatus();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not verify code.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not verify code: $e')));
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  Future<void> _applyPhoneCredential(
    PhoneAuthCredential credential,
    String phoneInput,
  ) async {
    final user = _user;

    // Linking is preferred, but can fail if phone provider already linked.
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'credential-already-in-use') {
        // If already linked or used elsewhere, try updatePhoneNumber when possible.
        try {
          await user.updatePhoneNumber(credential);
        } catch (_) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    // Store an app-side marker so we can gate on it reliably.
    await _db.collection('users').doc(user.uid).set({
      'phone': phoneInput,
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _signOutAndExit() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    final busyOverlay =
        _sendingEmail || _sendingCode || _verifyingCode || _continuing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your account'),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _signOutAndExit, child: const Text('Sign out')),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _loadUserDoc(),
            builder: (context, snap) {
              final data = snap.data ?? <String, dynamic>{};
              final emailOk = user.emailVerified;
              final phoneOk = _isPhoneVerified(data, user);

              final storedPhone = (data['phone'] as String?)?.trim() ?? '';
              if (_phoneController.text.trim().isEmpty &&
                  storedPhone.isNotEmpty) {
                // One-time best-effort prefill.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_phoneController.text.trim().isEmpty) {
                    _phoneController.text = storedPhone;
                  }
                });
              }

              final activeStep = emailOk ? (phoneOk ? 2 : 1) : 0;

              Widget emailCard() {
                return Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              emailOk
                                  ? Icons.check_circle
                                  : Icons.email_outlined,
                              color: emailOk
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Email verification',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              emailOk ? 'Verified' : 'Pending',
                              style: TextStyle(
                                color: emailOk
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user.email ?? 'Unknown email',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Didn\'t get it? Check Spam/Promotions/All Mail. Gmail users can search: “Firebase” or “verify”. It can take a few minutes.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: _sendingEmail
                                    ? null
                                    : _resendEmailVerification,
                                child: _sendingEmail
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Resend email'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _refreshStatus,
                                child: const Text("I've verified"),
                              ),
                            ),
                          ],
                        ),
                        if (kIsWeb)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Tip: on web, the verification link may open in a new tab. Come back and press “I\'ve verified”.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              Widget phoneCard() {
                return Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              phoneOk ? Icons.check_circle : Icons.sms_outlined,
                              color: phoneOk
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Phone verification',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              phoneOk ? 'Verified' : 'Pending',
                              style: TextStyle(
                                color: phoneOk
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone number',
                            hintText: 'e.g. +15551234567',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          enabled: !phoneOk,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    (phoneOk ||
                                        _sendingCode ||
                                        _sendCooldownSeconds > 0)
                                    ? null
                                    : _sendPhoneCode,
                                child: _sendingCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _sendCooldownSeconds > 0
                                            ? 'Send again in ${_sendCooldownSeconds}s'
                                            : 'Send code',
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (_sendCooldownSeconds > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Please wait before requesting another code.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'SMS code',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          enabled: !phoneOk,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: (phoneOk || _verifyingCode)
                                    ? null
                                    : _verifyPhoneCode,
                                child: _verifyingCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Verify code'),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Use E.164 format with country code (example: +1...).',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget doneCard() {
                return Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All set! You can continue.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        FilledButton(
                          onPressed: _continuing ? null : _continueIntoApp,
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final steps = <Widget>[emailCard(), phoneCard(), doneCard()];

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Text(
                    'Verify your contact info',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'To protect the marketplace, please verify your email and phone number.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(3, (index) {
                      final active = index <= activeStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                          decoration: BoxDecoration(
                            color: active
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: steps[activeStep],
                  ),
                ],
              );
            },
          ),
          if (busyOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
