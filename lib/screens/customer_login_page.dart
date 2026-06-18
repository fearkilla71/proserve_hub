import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';
import '../theme/proserve_theme.dart';
import '../utils/app_error_handler.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/proserve_entry_flow.dart';

class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _auth = AuthService();

  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = await _auth.signInWithGoogle();
      if (user == null) {
        // User cancelled
        if (mounted) setState(() => _googleLoading = false);
        return;
      }

      final role = await _auth.resolveRoleForUid(user.uid);
      if (!mounted) return;

      if (role == 'contractor') {
        await _auth.signOut();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This Google account is registered as a contractor. Please sign in from the Contractor portal.',
            ),
          ),
        );
        return;
      }

      // Assign customer role if new user
      if (role == null) {
        await _auth.ensureGoogleUserRole(user.uid, 'customer');
      }

      if (!mounted) return;
      context.go('/customer-portal');
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'Google sign-in');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_appleLoading || loading) return;
    setState(() => _appleLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = await _auth.signInWithApple(role: 'customer');
      final uid = user?.uid;
      final role = uid == null ? null : await _auth.resolveRoleForUid(uid);
      if (!mounted) return;

      if (role == 'customer') {
        context.go('/customer-portal');
        return;
      }

      if (role == 'contractor') {
        await _auth.signOut();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This Apple ID is registered as a contractor. Please sign in from the Contractor portal.',
            ),
          ),
        );
        return;
      }

      // No role found — new Apple sign-in created a customer doc, route there.
      if (uid != null) {
        context.go('/customer-portal');
        return;
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User cancelled — do nothing.
      } else {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, st) {
      if (!mounted) return;
      AppError.show(context, e, st, action: 'Apple sign-in');
    } finally {
      if (mounted) setState(() => _appleLoading = false);
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

    setState(() => loading = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = await _auth.signIn(emailValue, passwordValue);

      final uid = user?.uid;
      final role = uid == null ? null : await _auth.resolveRoleForUid(uid);
      if (!mounted) return;

      if (role == 'customer') {
        context.go('/customer-portal');
        return;
      }

      if (role == 'contractor') {
        await _auth.signOut();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This email is registered as a contractor. Please sign in from the Contractor portal.',
            ),
          ),
        );
        return;
      }

      await _auth.signOut();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your account is missing a role. Please contact support.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplePlatform = Platform.isIOS || Platform.isMacOS;
    final showGoogleSignIn = !isApplePlatform;
    return ProServeEntryScaffold(
      roleLabel: 'Homeowner portal',
      title: 'Welcome Back.',
      subtitle:
          'Sign in to manage quotes, messages, escrow payments, project tracking, and reviews.',
      icon: Icons.home_outlined,
      accent: ProServeColors.accent,
      benefits: const [
        EntryBenefit(
          icon: Icons.request_quote_outlined,
          label: 'Quotes',
          description: 'review bids and contractor details',
        ),
        EntryBenefit(
          icon: Icons.lock_outline,
          label: 'Escrow',
          description: 'track protected payment milestones',
        ),
        EntryBenefit(
          icon: Icons.chat_bubble_outline,
          label: 'Messages',
          description: 'keep job conversations organized',
        ),
      ],
      child: ProServeEntryPanel(
        title: 'Customer sign in',
        subtitle: 'Continue with your saved project history and active jobs.',
        child: Column(
          children: [
            if (showGoogleSignIn)
              OutlinedButton.icon(
                onPressed: (loading || _googleLoading)
                    ? null
                    : _signInWithGoogle,
                icon: _googleLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.g_mobiledata, size: 24),
                      ),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            if (isApplePlatform) ...[
              const SizedBox(height: 12),
              _appleLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AppleSignInButton(
                      onPressed: (loading || _appleLoading)
                          ? null
                          : _handleAppleSignIn,
                    ),
            ],
            const SizedBox(height: 14),
            const ProServeEntryDivider(),
            const SizedBox(height: 14),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        final emailValue = email.text.trim();
                        if (emailValue.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter your email above, then tap Forgot password.',
                              ),
                            ),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: emailValue,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset email sent. Check your inbox.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                            ),
                          );
                        }
                      },
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading
                  ? null
                  : () => context.push('/customer-signup'),
              child: const Text("Don't have an account? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
