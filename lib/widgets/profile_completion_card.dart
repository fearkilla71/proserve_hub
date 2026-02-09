import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/verification_screen.dart';

class ProfileCompletionCard extends StatelessWidget {
  final VoidCallback? onTapComplete;
  final String actionLabel;

  const ProfileCompletionCard({
    super.key,
    this.onTapComplete,
    this.actionLabel = 'Complete profile',
  });

  Map<String, dynamic> _calculateCompletionFromData({
    required User user,
    required Map<String, dynamic> userData,
    Map<String, dynamic>? contractorData,
  }) {
    final role = (userData['role'] ?? '').toString().toLowerCase();

    final List<String> missing = [];
    int completed = 0;
    int total = 0;

    // Common fields
    total += 5;
    if ((userData['name'] ?? '').toString().trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('Full name');
    }

    final authEmail = (user.email ?? '').trim();
    if ((userData['email'] ?? '').toString().trim().isNotEmpty ||
        authEmail.isNotEmpty) {
      completed++;
    } else {
      missing.add('Email');
    }

    if ((userData['phone'] ?? '').toString().trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('Phone number');
    }

    if ((userData['address'] ?? '').toString().trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('Address');
    }

    if ((userData['zip'] ?? '').toString().trim().isNotEmpty) {
      completed++;
    } else {
      missing.add('ZIP code');
    }

    if (role == 'contractor') {
      // Contractor-specific fields
      total += 4;
      final c = contractorData ?? <String, dynamic>{};

      if ((c['bio'] ?? '').toString().trim().isNotEmpty) {
        completed++;
      } else {
        missing.add('Bio/description');
      }

      final services = c['services'];
      if (services is List && services.isNotEmpty) {
        completed++;
      } else {
        missing.add('Services offered');
      }

      if ((c['yearsExperience'] ?? 0) > 0) {
        completed++;
      } else {
        missing.add('Years of experience');
      }

      if ((c['verified'] ?? false) == true) {
        completed++;
      } else {
        missing.add('Profile verification');
      }
    }

    final percentage = total == 0 ? 0 : ((completed / total) * 100).round();
    return {'percentage': percentage, 'missing': missing, 'role': role};
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();

        final userData = userSnap.data!.data() ?? <String, dynamic>{};
        final role = (userData['role'] ?? '').toString().toLowerCase();

        if (role == 'contractor') {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('contractors')
                .doc(user.uid)
                .snapshots(),
            builder: (context, contractorSnap) {
              if (!contractorSnap.hasData) return const SizedBox.shrink();
              final contractorData =
                  contractorSnap.data!.data() ?? <String, dynamic>{};

              final data = _calculateCompletionFromData(
                user: user,
                userData: userData,
                contractorData: contractorData,
              );

              final percentage = data['percentage'] as int;
              final missing = (data['missing'] as List).cast<String>();

              if (percentage >= 100) {
                return const SizedBox.shrink();
              }

              return _buildCard(
                context: context,
                scheme: scheme,
                percentage: percentage,
                missing: missing,
              );
            },
          );
        }

        final data = _calculateCompletionFromData(
          user: user,
          userData: userData,
        );

        final percentage = data['percentage'] as int;
        final missing = (data['missing'] as List).cast<String>();

        if (percentage >= 100) {
          return const SizedBox.shrink();
        }

        return _buildCard(
          context: context,
          scheme: scheme,
          percentage: percentage,
          missing: missing,
        );
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required ColorScheme scheme,
    required int percentage,
    required List<String> missing,
  }) {
    final primaryMissing = missing.isNotEmpty ? missing.first : '';
    final resolvedLabel = primaryMissing.isNotEmpty
        ? 'Complete: $primaryMissing'
        : actionLabel;
    final resolvedOnTap = (primaryMissing == 'Profile verification')
        ? () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VerificationScreen()),
            );
          }
        : onTapComplete;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: scheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Missing:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: missing.take(3).map((item) {
                  return Chip(
                    label: Text(item, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            if (onTapComplete != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: resolvedOnTap,
                  child: Text(resolvedLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
