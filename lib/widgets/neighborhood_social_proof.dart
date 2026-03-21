import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

/// "3 homes in your area painted this month" social proof section.
class NeighborhoodSocialProof extends StatefulWidget {
  const NeighborhoodSocialProof({super.key});

  @override
  State<NeighborhoodSocialProof> createState() =>
      _NeighborhoodSocialProofState();
}

class _NeighborhoodSocialProofState extends State<NeighborhoodSocialProof> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Get user's ZIP
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final zip = userDoc.data()?['zip'] as String? ?? '';
      if (zip.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Prefix match for neighborhood (first 3 digits)
      final prefix = zip.substring(0, zip.length.clamp(0, 3));

      // Count recently completed jobs nearby
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final query = await FirebaseFirestore.instance
          .collection('job_requests')
          .where('status', isEqualTo: 'completed')
          .where('zip', isGreaterThanOrEqualTo: prefix)
          .where('zip', isLessThan: '${prefix}z')
          .where(
            'completedAt',
            isGreaterThan: Timestamp.fromDate(thirtyDaysAgo),
          )
          .limit(50)
          .get();

      // Aggregate by service type
      final serviceCount = <String, int>{};
      for (final doc in query.docs) {
        final svc = doc.data()['serviceName'] as String? ?? 'home project';
        serviceCount[svc] = (serviceCount[svc] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _data = {
            'totalJobs': query.docs.length,
            'topServices': serviceCount,
            'zip': zip,
          };
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_data == null || (_data!['totalJobs'] as int) == 0) {
      return const SizedBox.shrink();
    }

    final total = _data!['totalJobs'] as int;
    final services = _data!['topServices'] as Map<String, int>;

    // Find top service
    String topService = 'home projects';
    if (services.isNotEmpty) {
      final sorted = services.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topService = _friendlyName(sorted.first.key);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProServeColors.accent2.withValues(alpha: 0.08),
            ProServeColors.accent3.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ProServeColors.accent2.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ProServeColors.accent2.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on,
              color: ProServeColors.accent2,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total homes near you this month',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Most popular: $topService',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.trending_up, color: ProServeColors.accent, size: 20),
        ],
      ),
    );
  }

  String _friendlyName(String key) {
    const names = {
      'interior_painting': 'Interior Painting',
      'exterior_painting': 'Exterior Painting',
      'drywall_repair': 'Drywall Repair',
      'pressure_washing': 'Pressure Washing',
      'cabinets': 'Cabinet Painting',
      'roofing': 'Roofing',
      'flooring': 'Flooring',
      'plumbing': 'Plumbing',
      'electrical': 'Electrical',
    };
    return names[key] ?? key.replaceAll('_', ' ');
  }
}
