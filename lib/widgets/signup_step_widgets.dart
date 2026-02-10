import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// Step 0: Email entry + verification prompt.
class SignupStepEmail extends StatelessWidget {
  final TextEditingController emailController;
  final bool awaitingVerification;
  final bool emailVerified;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  })
  inputDecoration;
  final VoidCallback onRefreshVerification;

  const SignupStepEmail({
    super.key,
    required this.emailController,
    required this.awaitingVerification,
    required this.emailVerified,
    required this.inputDecoration,
    required this.onRefreshVerification,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !awaitingVerification,
          decoration: inputDecoration(
            label: 'Email',
            hint: 'you@company.com',
            icon: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          awaitingVerification
              ? 'Check your email, verify, then return to continue.'
              : 'We\u2019ll email a verification link after you create the account.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (awaitingVerification) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRefreshVerification,
            child: const Text('I verified, refresh status'),
          ),
        ],
      ],
    );
  }
}

/// Step 1: Password entry.
class SignupStepPassword extends StatelessWidget {
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  })
  inputDecoration;

  const SignupStepPassword({
    super.key,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: passwordController,
          obscureText: obscure,
          decoration: inputDecoration(
            label: 'Password',
            hint: 'At least 6 characters',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              tooltip: obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: onToggleObscure,
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 2: Name + company.
class SignupStepProfile extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController companyController;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  })
  inputDecoration;

  const SignupStepProfile({
    super.key,
    required this.nameController,
    required this.companyController,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: nameController,
          decoration: inputDecoration(
            label: 'Full name',
            icon: Icons.person_outline,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: companyController,
          decoration: inputDecoration(
            label: 'Company',
            icon: Icons.business_outlined,
          ),
        ),
      ],
    );
  }
}

/// Step 3: Phone verification.
class SignupStepPhone extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool phoneVerified;
  final String? phoneVerificationId;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  })
  inputDecoration;

  const SignupStepPhone({
    super.key,
    required this.phoneController,
    required this.codeController,
    required this.phoneVerified,
    required this.phoneVerificationId,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
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
          controller: phoneController,
          keyboardType: TextInputType.phone,
          enabled: !phoneVerified,
          decoration: inputDecoration(
            label: 'Phone',
            hint: '(123) 456-7890',
            icon: Icons.phone_outlined,
          ),
        ),
        if (phoneVerificationId != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration(
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
  }
}

/// Step 4: Location (ZIP + radius).
class SignupStepLocation extends StatelessWidget {
  final TextEditingController zipController;
  final TextEditingController radiusController;
  final bool showZipPreview;
  final String zipAreaLabel;
  final ValueChanged<String> onZipChanged;
  final InputDecoration Function({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  })
  inputDecoration;

  const SignupStepLocation({
    super.key,
    required this.zipController,
    required this.radiusController,
    required this.showZipPreview,
    required this.zipAreaLabel,
    required this.onZipChanged,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
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
                  offset: showZipPreview ? Offset.zero : const Offset(0, 0.08),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: showZipPreview ? 1 : 0.92,
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
                        showZipPreview
                            ? 'ProServe Hub is active in $zipAreaLabel \u2014 join local pros on the platform!'
                            : 'Enter your ZIP code to check availability in your area',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          controller: zipController,
          keyboardType: TextInputType.number,
          onChanged: onZipChanged,
          decoration: inputDecoration(
            label: 'ZIP code',
            icon: Icons.location_on_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: radiusController,
          keyboardType: TextInputType.number,
          decoration: inputDecoration(
            label: 'Service radius (miles)',
            icon: Icons.radar_outlined,
          ),
        ),
      ],
    );
  }
}
