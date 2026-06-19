import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/service_types.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/zip_lookup_service.dart';
import '../theme/proserve_theme.dart';
import '../utils/app_error_handler.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/proserve_entry_flow.dart';

class ContractorSignupPage extends StatefulWidget {
  const ContractorSignupPage({super.key});

  @override
  State<ContractorSignupPage> createState() => _ContractorSignupPageState();
}

class _ContractorSignupPageState extends State<ContractorSignupPage>
    with WidgetsBindingObserver {
  final _auth = AuthService();
  final _db = FirebaseFirestore.instance;

  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final company = TextEditingController();
  final zip = TextEditingController();
  final radiusMiles = TextEditingController(text: '25');
  final phone = TextEditingController();
  final phoneCode = TextEditingController();

  final List<String> _selectedServices = ['Interior Painting'];

  static const Map<String, List<String>> _serviceCategories =
      kHomeServiceCategories;

  bool loading = false;
  bool _obscurePassword = true;
  bool _awaitingEmailVerification = false;
  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _sendingPhoneCode = false;
  bool _verifyingPhoneCode = false;
  String? _phoneVerificationId;
  int? _forceResendingToken;
  int _step = 0;
  static const int _totalSteps = 5;
  bool _showZipPreview = false;
  String _zipAreaLabel = 'your area';
  bool _agreedToTerms = false;
  bool _appleLoading = false;

  Future<void> _handleAppleSignUp() async {
    if (_appleLoading || loading) return;
    setState(() => _appleLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = await _auth.signInWithApple(role: 'contractor');
      if (!mounted) return;
      if (user != null) {
        context.go('/contractor-portal');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'Apple sign-up');
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('1') && digits.length == 11) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+1$digits';
    }
    if (input.trim().startsWith('+')) {
      return '+$digits';
    }
    return '';
  }

  void _updateZipPreview(String value) async {
    final zipValue = value.trim();
    if (zipValue.length != 5) {
      setState(() => _showZipPreview = false);
      return;
    }
    // Try async geocoding for any US ZIP
    final loc = await ZipLookupService.instance.lookup(zipValue);
    if (!mounted) return;
    setState(() {
      _showZipPreview = loc != null;
      _zipAreaLabel = 'your area';
    });
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ProServeColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _serviceCategoryChips(String title, List<String> services) {
    final supported = title == 'Core instant-price services';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: supported
                      ? ProServeColors.accent
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (supported)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ProServeColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: ProServeColors.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: const Text(
                  'Instant price',
                  style: TextStyle(
                    color: ProServeColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: services.map(_serviceChip).toList(),
        ),
      ],
    );
  }

  Widget _serviceChip(String svc) {
    final selected = _selectedServices.contains(svc);
    return FilterChip(
      label: Text(svc),
      selected: selected,
      onSelected: (val) {
        setState(() {
          if (val) {
            if (!_selectedServices.contains(svc)) {
              _selectedServices.add(svc);
            }
          } else {
            _selectedServices.remove(svc);
          }
        });
      },
    );
  }

  void _goBackStep() {
    if (_step <= 0) return;
    setState(() => _step -= 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshEmailVerificationStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshEmailVerificationStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    email.dispose();
    password.dispose();
    name.dispose();
    company.dispose();
    zip.dispose();
    radiusMiles.dispose();
    phone.dispose();
    phoneCode.dispose();
    super.dispose();
  }

  Future<void> _refreshEmailVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } catch (e) {
      debugPrint('Email verification refresh failed: $e');
    }

    if (!mounted) return;
    setState(() {
      if (email.text.trim().isEmpty && (user.email ?? '').trim().isNotEmpty) {
        email.text = (user.email ?? '').trim();
      }
      _emailVerified = user.emailVerified;
      if (_emailVerified) {
        _awaitingEmailVerification = false;
        if (_step == 0) {
          _step = 2;
        }
      }
      _phoneVerified =
          (user.phoneNumber ?? '').trim().isNotEmpty || _phoneVerified;
    });
  }

  Future<void> _sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finish creating your account to verify your email.'),
        ),
      );
      return;
    }

    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check your inbox.'),
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'send verification email');
    }
  }

  Future<void> _handleGoogleSignUp(BuildContext context) async {
    setState(() => loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final user = await _auth.signInWithGoogle();
      if (user == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final role = await _auth.resolveRoleForUid(user.uid);
      if (!mounted) return;

      if (role == 'customer') {
        await _auth.signOut();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This Google account is already registered as a customer.',
            ),
          ),
        );
        return;
      }

      if (role == 'contractor') {
        // Already a contractor — just go to portal
        if (mounted) router.go('/contractor-portal');
        return;
      }

      // New user — assign contractor role
      await _auth.ensureGoogleUserRole(user.uid, 'contractor');
      if (mounted) router.go('/contractor-portal');
    } catch (e, st) {
      if (!context.mounted) return;
      AppError.show(context, e, st, action: 'Google sign-up');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sendPhoneCode() async {
    if (_sendingPhoneCode) return;
    final phoneValue = phone.text.trim();
    if (phoneValue.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a phone number.')));
      return;
    }

    final normalized = _normalizePhone(phoneValue);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number (ex: +1 555 123 4567).'),
        ),
      );
      return;
    }

    setState(() => _sendingPhoneCode = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        forceResendingToken: _forceResendingToken,
        verificationCompleted: (credential) async {
          await _applyPhoneCredential(credential, normalized);
        },
        verificationFailed: (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Phone verification failed.')),
          );
        },
        codeSent: (verificationId, forceResendingToken) {
          if (!mounted) return;
          setState(() {
            _phoneVerificationId = verificationId;
            _forceResendingToken = forceResendingToken;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code sent.')),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          setState(() => _phoneVerificationId = verificationId);
        },
      );
    } finally {
      if (mounted) setState(() => _sendingPhoneCode = false);
    }
  }

  Future<void> _verifyPhoneCode() async {
    if (_verifyingPhoneCode) return;
    final verificationId = _phoneVerificationId;
    if (verificationId == null || verificationId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Send the code first.')));
      return;
    }

    final code = phoneCode.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the SMS code.')));
      return;
    }

    setState(() => _verifyingPhoneCode = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _applyPhoneCredential(credential, phone.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone verified.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Invalid code.')));
    } finally {
      if (mounted) setState(() => _verifyingPhoneCode = false);
    }
  }

  Future<void> _applyPhoneCredential(
    PhoneAuthCredential credential,
    String phoneInput,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint('linkWithCredential failed, trying updatePhoneNumber: $e');
      try {
        await user.updatePhoneNumber(credential);
      } catch (e2) {
        debugPrint('updatePhoneNumber also failed: $e2');
      }
    }

    await _db.collection('users').doc(user.uid).set({
      'phone': phoneInput,
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      _phoneVerified = true;
    });
  }

  bool _validateStep() {
    final messenger = ScaffoldMessenger.of(context);

    if (_step == 0) {
      final emailValue = email.text.trim();
      if (emailValue.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Email is required.')),
        );
        return false;
      }
      if (_awaitingEmailVerification && !_emailVerified) {
        // Allow the Verify button to refresh status without blocking.
        return true;
      }
    }

    if (_step == 1) {
      final passwordValue = password.text;
      if (passwordValue.length < 6) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
          ),
        );
        return false;
      }
    }

    if (_step == 2) {
      if (_selectedServices.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Select at least one service you offer.'),
          ),
        );
        return false;
      }
    }

    if (_step == 3) {
      final phoneValue = phone.text.trim();
      if (phoneValue.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Phone number is required.')),
        );
        return false;
      }
      if (!_agreedToTerms) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please agree to the Terms and Privacy Policy.'),
          ),
        );
        return false;
      }
    }

    if (_step == 4) {
      final zipValue = zip.text.trim();
      if (zipValue.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ZIP code is required.')),
        );
        return false;
      }
      if (zipValue.length != 5 || int.tryParse(zipValue) == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid 5-digit US ZIP code.')),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _nextOrSubmit() async {
    if (!_validateStep()) return;
    if (_step == 0 && _awaitingEmailVerification) {
      await _refreshEmailVerificationStatus();
      if (_emailVerified) {
        if (mounted) setState(() => _step = 2);
      } else {
        await _sendEmailVerification();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not verified yet. We resent the email.'),
          ),
        );
      }
      return;
    }

    if (_step == 1) {
      await _createAccountAndSendVerification();
      return;
    }

    if (_step == 3 && !_phoneVerified) {
      if (_phoneVerificationId == null) {
        await _sendPhoneCode();
      } else {
        await _verifyPhoneCode();
      }
      return;
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
      return;
    }

    await submit();
  }

  String _primaryActionLabel() {
    if (_step == 0 && _awaitingEmailVerification) {
      return _emailVerified ? 'Next' : 'Verify';
    }
    if (_step == 1) {
      return 'Verify';
    }
    if (_step == 3 && !_phoneVerified) {
      return _phoneVerificationId == null ? 'Verify' : 'Confirm';
    }
    return _step == _totalSteps - 1 ? 'Create account' : 'Next';
  }

  String _stepTitle() {
    return switch (_step) {
      0 =>
        _awaitingEmailVerification ? 'Verify your email' : 'Start with email',
      1 => 'Secure your pro account',
      2 => 'Build your business profile',
      3 => 'Verify your phone',
      _ => 'Choose your lead area',
    };
  }

  String _stepSubtitle() {
    return switch (_step) {
      0 =>
        _awaitingEmailVerification
            ? 'Confirm your email so customers and ProServe can trust the account.'
            : 'Use the email you want tied to leads, quotes, invoices, and payouts.',
      1 =>
        'Protect your contractor tools, customer chats, and payment workflow.',
      2 => 'Tell homeowners what you do and where your business should appear.',
      3 =>
        'Verified contact info helps customers trust and reach your business.',
      _ => 'Set your ZIP and service radius so leads match your actual market.',
    };
  }

  Widget _buildStepContent() {
    final isApplePlatform = Platform.isIOS || Platform.isMacOS;
    switch (_step) {
      case 0:
        return Column(
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              enabled: !_awaitingEmailVerification,
              decoration: _inputDecoration(
                label: 'Email',
                hint: 'you@company.com',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _awaitingEmailVerification
                  ? 'Check your email, verify, then return to continue.'
                  : 'We’ll email a verification link after you create the account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_awaitingEmailVerification) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await _refreshEmailVerificationStatus();
                  if (!mounted) return;
                  if (!_emailVerified) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Not verified yet. Try again in a moment.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('I verified, refresh status'),
              ),
            ],
            if (!_awaitingEmailVerification && isApplePlatform) ...[
              const OrDivider(),
              _appleLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AppleSignInButton(
                      label: 'Sign up with Apple',
                      onPressed: (loading || _appleLoading)
                          ? null
                          : _handleAppleSignUp,
                    ),
            ],
          ],
        );
      case 1:
        return Column(
          children: [
            TextField(
              controller: password,
              obscureText: _obscurePassword,
              decoration: _inputDecoration(
                label: 'Password',
                hint: 'At least 6 characters',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            TextField(
              controller: name,
              decoration: _inputDecoration(
                label: 'Full name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: company,
              decoration: _inputDecoration(
                label: 'Company',
                icon: Icons.business_outlined,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Services you offer',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pick every trade you want customers to find you for. Instant pricing is available first for the core services.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ProServeColors.muted,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ..._serviceCategories.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _serviceCategoryChips(entry.key, entry.value),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: ProServeColors.cardElevated,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.phone_iphone,
                    size: 72,
                    color: ProServeColors.accent2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              enabled: !_phoneVerified,
              decoration: _inputDecoration(
                label: 'Phone',
                hint: '(123) 456-7890',
                icon: Icons.phone_outlined,
              ),
            ),
            if (_phoneVerificationId != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: phoneCode,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: 'Verification code',
                  hint: '123456',
                  icon: Icons.sms_outlined,
                ),
              ),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(
                          Uri.parse('https://proservehub.app/privacy'),
                          mode: LaunchMode.externalApplication,
                        ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(
                          Uri.parse('https://proservehub.app/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        );
      case 4:
      default:
        return Column(
          children: [
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: ProServeColors.cardElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/pitch/pin_card.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 230,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: ProServeColors.cardElevated,
                        child: Image.asset(
                          'assets/pitch/zipcode_card.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 14,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      offset: _showZipPreview
                          ? Offset.zero
                          : const Offset(0, 0.08),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _showZipPreview ? 1 : 0.92,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ProServeColors.card,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            _showZipPreview
                                ? 'ProServe Hub is active in $_zipAreaLabel — join local pros on the platform!'
                                : 'Enter your ZIP code to check availability in your area',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: ProServeColors.muted,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: zip,
              keyboardType: TextInputType.number,
              onChanged: _updateZipPreview,
              decoration: _inputDecoration(
                label: 'ZIP code',
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusMiles,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                label: 'Service radius (miles)',
                icon: Icons.radar_outlined,
              ),
            ),
          ],
        );
    }
  }

  Future<void> _createAccountAndSendVerification() async {
    if (loading) return;

    final emailValue = email.text.trim();
    final passwordValue = password.text;
    if (emailValue.isEmpty || passwordValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final user = await _auth.createContractorAccountShell(
        email: emailValue,
        password: passwordValue,
      );

      if (!mounted) return;
      setState(() {
        _awaitingEmailVerification = true;
        _emailVerified = user?.emailVerified ?? false;
        _step = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check your inbox.'),
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'create account');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (loading) return;

    final emailValue = email.text.trim();
    final passwordValue = password.text;
    if (emailValue.isEmpty || passwordValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required.')),
      );
      return;
    }
    if (passwordValue.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );
      return;
    }

    final zipValue = zip.text.trim();
    if (zipValue.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ZIP code is required.')));
      return;
    }
    if (zipValue.length != 5 || int.tryParse(zipValue) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 5-digit US ZIP code.')),
      );
      return;
    }

    setState(() => loading = true);

    final messenger = ScaffoldMessenger.of(context);

    final radiusParsed = int.tryParse(radiusMiles.text.trim());
    final radius = (radiusParsed != null && radiusParsed > 0)
        ? radiusParsed
        : 25;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please verify your email before continuing.');
      }

      await _auth.completeContractorProfile(
        user: user,
        name: name.text.trim(),
        company: company.text.trim(),
        services: _selectedServices,
        zip: zipValue,
        radius: radius,
        phone: phone.text.trim(),
      );

      if (!mounted) return;
      context.go('/verify-contact', extra: {'showPitchAfterVerify': true});
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplePlatform = Platform.isIOS || Platform.isMacOS;
    return Stack(
      children: [
        ProServeEntryScaffold(
          roleLabel: 'Contractor account',
          title: 'Win Work. Quote Fast. Get Paid.',
          subtitle:
              'Create your pro account to access local leads, job tools, invoices, escrow payouts, and customer follow-up workflows.',
          icon: Icons.business_center_outlined,
          accent: ProServeColors.accent2,
          onBack: loading ? null : _goBackStep,
          benefits: const [
            EntryBenefit(
              icon: Icons.location_searching_outlined,
              label: 'Local leads',
              description: 'match your services and ZIP radius',
            ),
            EntryBenefit(
              icon: Icons.calculate_outlined,
              label: 'Contractor OS',
              description: 'quote, estimate, invoice, and schedule',
            ),
            EntryBenefit(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Payout ready',
              description: 'prepare your account to receive payments',
            ),
          ],
          child: ProServeEntryPanel(
            title: _stepTitle(),
            subtitle: _stepSubtitle(),
            step: _step,
            totalSteps: _totalSteps,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0.0, 0.05),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: _buildStepContent(),
                ),
                const SizedBox(height: 24),
                ProServeEntryActionRow(
                  secondaryLabel: _step > 0 ? 'Back' : null,
                  onSecondary: _goBackStep,
                  primaryLabel: _primaryActionLabel(),
                  onPrimary:
                      loading ||
                          (_step == 0 &&
                              _awaitingEmailVerification &&
                              !_emailVerified)
                      ? null
                      : _nextOrSubmit,
                  loading: loading,
                ),
                const SizedBox(height: 10),
                if (_step == 0 && !isApplePlatform) ...[
                  const SizedBox(height: 8),
                  const ProServeEntryDivider(),
                  const SizedBox(height: 12),
                  GoogleSignInButton(
                    label: 'Sign up with Google',
                    onPressed: loading
                        ? null
                        : () => _handleGoogleSignUp(context),
                  ),
                ],
                Center(
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () => context.push('/contractor-login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (loading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.22),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
