import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/proserve_theme.dart';
import 'verify_contact_info_page.dart';
import 'customer_login_page.dart';

class CustomerSignupPage extends StatefulWidget {
  const CustomerSignupPage({super.key});

  @override
  State<CustomerSignupPage> createState() => _CustomerSignupPageState();
}

class _CustomerSignupPageState extends State<CustomerSignupPage> {
  final _auth = AuthService();

  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final phone = TextEditingController();
  final phoneCode = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  bool _phoneVerified = false;
  bool _sendingPhoneCode = false;
  bool _verifyingPhoneCode = false;
  String? _phoneVerificationId;
  int? _forceResendingToken;
  int _step = 0;
  static const int _totalSteps = 4;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    phone.dispose();
    phoneCode.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('1') && digits.length == 11) return '+$digits';
    if (digits.length == 10) return '+1$digits';
    if (input.trim().startsWith('+')) return '+$digits';
    return '';
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
      ).showSnackBar(const SnackBar(content: Text('Phone verified!')));
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

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'phone': phoneInput,
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() => _phoneVerified = true);
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

    setState(() => loading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _auth.signUpCustomer(
        email: emailValue,
        password: passwordValue,
        name: name.text.trim(),
        phone: phone.text.trim(),
      );

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Account created.')));
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VerifyContactInfoPage()),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
    if (_step <= 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
  }

  bool _validateStep() {
    final emailValue = email.text.trim();
    final passwordValue = password.text;
    if (_step == 0) {
      if (emailValue.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email is required.')));
        return false;
      }
    }
    if (_step == 1) {
      if (passwordValue.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password is required.')));
        return false;
      }
      if (passwordValue.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
          ),
        );
        return false;
      }
    }
    if (_step == 2) {
      if (phone.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number is required.')),
        );
        return false;
      }
    }
    return true;
  }

  void _nextOrSubmit() async {
    if (!_validateStep()) return;

    // Phone verification step
    if (_step == 3) {
      if (!_phoneVerified) {
        if (_phoneVerificationId == null) {
          await _sendPhoneCode();
        } else {
          await _verifyPhoneCode();
        }
        if (_phoneVerified) {
          // Phone verified — proceed to submit
          await submit();
        }
        return;
      }
      await submit();
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

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return Column(
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                label: 'Email',
                hint: 'you@email.com',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We will only use this to secure your account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ProServeColors.cardElevated,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: ProServeColors.card,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: ProServeColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Local pros respond faster when your profile is complete.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ProServeColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: _inputDecoration(
                label: 'Full name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                label: 'Phone',
                hint: '(123) 456-7890',
                icon: Icons.phone_outlined,
              ),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: ProServeColors.cardElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _phoneVerified ? Icons.verified : Icons.phone_iphone,
                    size: 56,
                    color: _phoneVerified
                        ? ProServeColors.accent
                        : ProServeColors.accent2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_phoneVerified)
              Text(
                'Phone verified!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ProServeColors.accent,
                ),
              )
            else ...[
              Text(
                'Verify your phone number',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'We sent a code to ${phone.text.trim()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_phoneVerificationId != null) ...[
                const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: _sendingPhoneCode ? null : _sendPhoneCode,
                child: Text(
                  _phoneVerificationId == null
                      ? 'Send verification code'
                      : 'Resend code',
                ),
              ),
            ],
          ],
        );
      default:
        return const SizedBox.shrink();
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
                                ? 'Create your customer account'
                                : _step == 1
                                ? 'Create Password'
                                : _step == 2
                                ? 'Tell us who you are'
                                : 'Verify your phone',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _step == 0
                                ? 'Start getting bids from trusted pros.'
                                : _step == 1
                                ? 'Secure your account for faster support.'
                                : _step == 2
                                ? 'So contractors can contact you quickly.'
                                : 'One last step to secure your account.',
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
                                    onPressed: loading ? null : _nextOrSubmit,
                                    child: loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _step == 3 && !_phoneVerified
                                                ? (_phoneVerificationId == null
                                                      ? 'Send code'
                                                      : 'Verify')
                                                : _step == _totalSteps - 1
                                                ? 'Create account'
                                                : 'Next',
                                          ),
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
                                              const CustomerLoginPage(),
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
        ],
      ),
    );
  }
}
