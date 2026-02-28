import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// A styled "Sign in with Apple" button matching Apple's HIG guidelines.
/// Uses the native Apple button style on iOS, custom styled on other platforms.
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Sign in with Apple',
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS || Platform.isMacOS) {
      return SizedBox(
        height: 50,
        child: SignInWithAppleButton(
          text: label,
          onPressed: onPressed ?? () {},
          style: SignInWithAppleButtonStyle.black,
        ),
      );
    }

    // Fallback for non-Apple platforms (Android, Windows, etc.)
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.apple, size: 24),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Divider with "or" text between sign-in methods.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withAlpha(100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('or', style: TextStyle(color: color, fontSize: 14)),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}
