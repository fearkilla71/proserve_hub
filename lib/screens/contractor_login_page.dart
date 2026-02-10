import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class ContractorLoginPage extends StatefulWidget {
  const ContractorLoginPage({super.key});

  @override
  State<ContractorLoginPage> createState() => _ContractorLoginPageState();
}

class _ContractorLoginPageState extends State<ContractorLoginPage> {
  final _auth = AuthService();

  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
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

      if (role == 'contractor') {
        context.go('/contractor-portal');
        return;
      }

      if (role == 'customer') {
        await _auth.signOut();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This email is registered as a customer. Please sign in from the Customer portal.',
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
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contractor Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      context.push('/contractor-signup');
                    },
              child: const Text("Don't have an account? Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
