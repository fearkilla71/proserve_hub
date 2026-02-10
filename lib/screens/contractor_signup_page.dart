import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/proserve_theme.dart';
import '../utils/zip_locations.dart';
import 'verify_contact_info_page.dart';
import 'contractor_login_page.dart';

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

  final String _selectedService = 'Interior Painting';

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
  int _zipDemandCount = 0;

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

  String _areaForZip(String zipValue) {
    if (zipValue.startsWith('770') ||
        zipValue.startsWith('771') ||
        zipValue.startsWith('772') ||
        zipValue.startsWith('773') ||
        zipValue.startsWith('774') ||
        zipValue.startsWith('775')) {
      return 'Houston, TX';
    }
    return 'your area';
  }

  int _demandForZip(String zipValue) {
    final numeric = int.tryParse(zipValue) ?? 0;
    return 12000 + (numeric % 4000);
  }

  void _updateZipPreview(String value) {
    final zipValue = value.trim();
    final isKnown = zipValue.length == 5 && zipLocations.containsKey(zipValue);
    setState(() {
      _showZipPreview = isKnown;
      if (isKnown) {
        _zipAreaLabel = _areaForZip(zipValue);
        _zipDemandCount = _demandForZip(zipValue);
      }
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
    } catch (_) {
      // best-effort
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    } on FirebaseAuthException catch (_) {
      try {
        await user.updatePhoneNumber(credential);
      } catch (_) {
        // Ignore; we still set app-level verification flag below.
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

    if (_step == 3) {
      final phoneValue = phone.text.trim();
      if (phoneValue.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Phone number is required.')),
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
      if (!zipLocations.containsKey(zipValue)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'ZIP not supported yet for smart matching. Add it to zip_locations.dart.',
            ),
          ),
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

  Widget _stepIndicator(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(_totalSteps, (index) {
        final active = index <= _step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 8),
            decoration: BoxDecoration(
              color: active ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
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

  Widget _buildStepContent() {
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
            Text(
              'By creating an account, you agree to the ProServe Hub Privacy Policy and Terms of Service.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                ? '$_zipDemandCount General Contractors in $_zipAreaLabel won bids last week using ProServe Hub'
                                : 'Enter your ZIP code to see demand in your area',
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    if (!zipLocations.containsKey(zipValue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ZIP not supported yet for smart matching. Add it to zip_locations.dart.',
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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
        services: [_selectedService],
        zip: zipValue,
        radius: radius,
        phone: phone.text.trim(),
      );

      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const VerifyContactInfoPage(showPitchAfterVerify: true),
        ),
        (r) => false,
      );
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
    return Scaffold(
      backgroundColor: ProServeColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: loading ? null : _goBackStep,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'ProServe Hub',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                    decoration: const BoxDecoration(
                      color: ProServeColors.card,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _step == 0
                                ? 'Create your contractor account'
                                : _step == 1
                                ? 'Create Password'
                                : _step == 2
                                ? 'Tell us about your business'
                                : _step == 3
                                ? 'Enter your mobile number'
                                : 'Set your price location',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _step == 0
                                ? 'Start receiving leads in minutes.'
                                : _step == 1
                                ? 'Secure your account to protect your leads.'
                                : _step == 2
                                ? 'Help customers trust your business.'
                                : _step == 3
                                ? 'We’ll use this to verify your account.'
                                : 'Choose where you want to receive leads.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _stepIndicator(context),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              final offset = Tween<Offset>(
                                begin: const Offset(0.0, 0.05),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildStepContent(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              if (_step > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loading ? null : _goBackStep,
                                    child: const Text('Back'),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed:
                                        loading ||
                                            (_step == 0 &&
                                                _awaitingEmailVerification &&
                                                !_emailVerified)
                                        ? null
                                        : _nextOrSubmit,
                                    child: loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(_primaryActionLabel()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ContractorLoginPage(),
                                        ),
                                      );
                                    },
                              child: const Text(
                                'Already have an account? Sign in',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
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
