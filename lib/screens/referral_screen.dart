import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/referral_service.dart';
import '../theme/proserve_theme.dart';

/// Screen for viewing/sharing a referral code and entering someone else's code.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen>
    with SingleTickerProviderStateMixin {
  String? _myCode;
  String? _codeError;
  bool _loadingCode = true;
  final _applyController = TextEditingController();
  bool _applying = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCode();
  }

  @override
  void dispose() {
    _applyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    setState(() {
      _loadingCode = true;
      _codeError = null;
    });
    try {
      final code = await ReferralService.instance.getOrCreateCode();
      if (mounted) setState(() => _myCode = code);
    } catch (e) {
      if (mounted) setState(() => _codeError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<void> _apply() async {
    final code = _applyController.text.trim();
    if (code.isEmpty) return;

    setState(() => _applying = true);
    final error = await ReferralService.instance.applyCode(code);

    if (!mounted) return;
    setState(() => _applying = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      _applyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\$${ReferralService.creditAmount.toStringAsFixed(0)} credit applied!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Share & Earn'),
            Tab(text: 'Tracking'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_shareTab(scheme), _trackingTab(scheme)],
      ),
    );
  }

  // ─── Tab 1: Share & Earn ────────────────────────────────────────────

  Widget _shareTab(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Credit balance ──
          StreamBuilder<double>(
            stream: ReferralService.instance.watchCredits(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorCard(
                  scheme,
                  'Could not load credit balance.',
                  snap.error.toString(),
                );
              }
              final credits = snap.data ?? 0;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 36,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promo Credit',
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            '\$${credits.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Share your code ──
          Text(
            'Your Referral Code',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loadingCode)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_codeError != null)
            _errorCard(scheme, 'Could not generate referral code.', _codeError!,
                retry: _loadCode)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SelectableText(
                      _myCode ?? '—',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Share this code with friends. You both get '
                      '\$${ReferralService.creditAmount.toStringAsFixed(0)} credit!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _myCode == null
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(text: _myCode!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Code copied!')),
                                  );
                                },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _myCode == null
                              ? null
                              : () {
                                  Share.share(
                                    'Try ProServe Hub! Use my code $_myCode '
                                    'to get \$${ReferralService.creditAmount.toStringAsFixed(0)} off your first job.',
                                  );
                                },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),

          // ── How it works ──
          Text(
            'How It Works',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _howItWorksRow(
                    scheme,
                    Icons.share,
                    '1. Share your code',
                    'Send your unique code to friends & family.',
                  ),
                  const Divider(height: 24),
                  _howItWorksRow(
                    scheme,
                    Icons.person_add,
                    '2. They sign up',
                    'Your friend creates an account and enters your code.',
                  ),
                  const Divider(height: 24),
                  _howItWorksRow(
                    scheme,
                    Icons.card_giftcard,
                    '3. You both earn',
                    'You each get \$${ReferralService.creditAmount.toStringAsFixed(0)} promo credit!',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Enter someone else's code ──
          Text(
            'Have a Referral Code?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _applyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ProServeCTAButton(
                onPressed: _applying ? null : _apply,
                child: _applying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _howItWorksRow(
    ColorScheme scheme,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorCard(ColorScheme scheme, String message, String detail,
      {VoidCallback? retry}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 36, color: scheme.error),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text(detail,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            if (retry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Tab 2: Tracking Dashboard ─────────────────────────────────────

  Widget _trackingTab(ColorScheme scheme) {
    if (_loadingCode) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_codeError != null || _myCode == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Share your referral code first to start tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (_codeError != null) ...[
                const SizedBox(height: 8),
                Text(_codeError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadCode,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final code = _myCode!;
    final dateFormat = DateFormat.yMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats cards row ──
          StreamBuilder<int>(
            stream: ReferralService.instance.watchMyCodeUsageCount(code),
            builder: (context, countSnap) {
              final count = countSnap.data ?? 0;
              return StreamBuilder<double>(
                stream: ReferralService.instance.watchCredits(),
                builder: (context, creditSnap) {
                  final credits = creditSnap.data ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          scheme,
                          icon: Icons.people,
                          label: 'Total Referrals',
                          value: '$count',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          scheme,
                          icon: Icons.monetization_on,
                          label: 'Credits Earned',
                          value: '\$${credits.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Tier progress ──
          StreamBuilder<int>(
            stream: ReferralService.instance.watchMyCodeUsageCount(code),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return _tierProgressCard(scheme, count);
            },
          ),

          const SizedBox(height: 24),

          // ── People who used my code ──
          Text(
            'People Who Used Your Code',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ReferralService.instance.watchMyCodeUsedBy(code),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorCard(
                    scheme, 'Could not load referrals.', snap.error.toString());
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.group_add,
                            size: 48,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No referrals yet.\nShare your code to start earning!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: list.map((entry) {
                    final ts = entry['appliedAt'] as Timestamp?;
                    final date = ts != null
                        ? dateFormat.format(ts.toDate())
                        : '—';
                    final credit = (entry['credit'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.person, color: scheme.primary),
                      ),
                      title: Text('Referral #${list.indexOf(entry) + 1}'),
                      subtitle: Text(date),
                      trailing: Text(
                        '+\$${credit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── My redemptions ──
          Text(
            'Codes You Redeemed',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ReferralService.instance.watchMyRedemptions(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _errorCard(scheme, 'Could not load redemptions.',
                    snap.error.toString());
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No codes redeemed yet.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                );
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: list.map((entry) {
                    final ts = entry['appliedAt'] as Timestamp?;
                    final date = ts != null
                        ? dateFormat.format(ts.toDate())
                        : '—';
                    final credit = (entry['credit'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: const Icon(Icons.redeem, color: Colors.green),
                      ),
                      title: Text(entry['code'] ?? '—'),
                      subtitle: Text(date),
                      trailing: Text(
                        '+\$${credit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Stat card helper ──────────────────────────────────────────────

  Widget _statCard(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tier progress card ────────────────────────────────────────────

  Widget _tierProgressCard(ColorScheme scheme, int referrals) {
    final tiers = [
      {
        'name': 'Bronze',
        'min': 0,
        'icon': Icons.workspace_premium,
        'color': const Color(0xFFCD7F32),
      },
      {
        'name': 'Silver',
        'min': 5,
        'icon': Icons.workspace_premium,
        'color': const Color(0xFFC0C0C0),
      },
      {
        'name': 'Gold',
        'min': 15,
        'icon': Icons.workspace_premium,
        'color': const Color(0xFFFFD700),
      },
      {
        'name': 'Platinum',
        'min': 30,
        'icon': Icons.diamond,
        'color': const Color(0xFFE5E4E2),
      },
    ];

    // Determine current tier.
    int currentTierIdx = 0;
    for (int i = tiers.length - 1; i >= 0; i--) {
      if (referrals >= (tiers[i]['min'] as int)) {
        currentTierIdx = i;
        break;
      }
    }

    final currentTier = tiers[currentTierIdx];
    final nextTier = currentTierIdx < tiers.length - 1
        ? tiers[currentTierIdx + 1]
        : null;
    final nextMin = nextTier != null ? nextTier['min'] as int : referrals;
    final currentMin = currentTier['min'] as int;
    final progress = nextTier != null
        ? ((referrals - currentMin) / (nextMin - currentMin)).clamp(0.0, 1.0)
        : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  currentTier['icon'] as IconData,
                  color: currentTier['color'] as Color,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentTier['name']} Tier',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                color: currentTier['color'] as Color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nextTier != null
                  ? '$referrals / $nextMin referrals to ${nextTier['name']}'
                  : 'Max tier reached! $referrals referrals',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
