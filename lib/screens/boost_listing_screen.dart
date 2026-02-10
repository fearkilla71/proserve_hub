import 'package:flutter/material.dart';
import '../services/boost_service.dart';
import '../theme/proserve_theme.dart';

class BoostListingScreen extends StatefulWidget {
  const BoostListingScreen({super.key});

  @override
  State<BoostListingScreen> createState() => _BoostListingScreenState();
}

class _BoostListingScreenState extends State<BoostListingScreen> {
  final _boost = BoostService();
  BoostStatus? _status;
  bool _loading = true;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final status = await _boost.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load boost status: $e')),
      );
    }
  }

  Future<void> _activate(String planId) async {
    if (_activating) return;
    setState(() => _activating = true);
    try {
      await _boost.activateBoost(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boost activated! Your listing is now featured.'),
        ),
      );
      await _loadStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Boost?'),
        content: const Text(
          'Your listing will no longer appear as featured. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Boost'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _boost.cancelBoost();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Boost cancelled.')));
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Boost Your Listing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _status?.active == true
                                  ? Icons.rocket_launch
                                  : Icons.trending_up,
                              color: _status?.active == true
                                  ? ProServeColors.accent
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _status?.active == true
                                    ? 'Boost Active'
                                    : 'Not Boosted',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (_status?.active == true)
                              Chip(
                                label: const Text('FEATURED'),
                                backgroundColor: scheme.primary,
                                labelStyle: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        if (_status?.active == true &&
                            _status?.expiresAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Expires: ${_formatDate(_status!.expiresAt!)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cancel,
                              child: const Text('Cancel Boost'),
                            ),
                          ),
                        ],
                        if (_status?.active != true) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Boosted listings appear at the top of search results '
                            'with a "FEATURED" badge so customers see you first.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Plan cards
                if (_status?.active != true) ...[
                  Text(
                    'Choose a plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...BoostService.plans.values.map(
                    (plan) => _PlanCard(
                      plan: plan,
                      loading: _activating,
                      onActivate: () => _activate(plan.id),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _PlanCard extends StatelessWidget {
  final BoostPlan plan;
  final bool loading;
  final VoidCallback onActivate;

  const _PlanCard({
    required this.plan,
    required this.loading,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.priceLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: loading ? null : onActivate,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Boost'),
            ),
          ],
        ),
      ),
    );
  }
}
