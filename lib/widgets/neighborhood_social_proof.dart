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
    // Completed job request documents are private. Keep this widget hidden until
    // a server-maintained public aggregate is available for neighborhood proof.
    if (mounted) {
      setState(() {
        _data = null;
        _loading = false;
      });
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
