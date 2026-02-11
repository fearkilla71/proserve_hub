import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/notification_preferences_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activity'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivityTab(scheme: scheme),
          const _SettingsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Tab — shows notification history from Firestore
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  final ColorScheme scheme;

  const _ActivityTab({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to view notifications.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'No notifications yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final title = data['title'] as String? ?? 'Notification';
            final body = data['body'] as String? ?? '';
            final type = data['type'] as String? ?? 'general';
            final read = data['read'] as bool? ?? false;
            final createdAt = data['createdAt'] as Timestamp?;
            final route = data['route'] as String?;

            final dateStr = createdAt != null
                ? DateFormat.MMMd().add_jm().format(createdAt.toDate())
                : '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: read
                    ? scheme.surfaceContainerHighest
                    : scheme.primaryContainer,
                child: Icon(
                  _iconForType(type),
                  color: read ? scheme.onSurfaceVariant : scheme.primary,
                  size: 22,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: read ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                dateStr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              onTap: () {
                // Mark as read
                if (!read) {
                  docs[i].reference.update({'read': true});
                }
                // Navigate
                if (route != null && route.isNotEmpty) {
                  context.push(route);
                }
              },
            );
          },
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'bid':
        return Icons.gavel;
      case 'job':
        return Icons.work_outline;
      case 'review':
        return Icons.star_outline;
      case 'referral':
        return Icons.people_outline;
      case 'promotion':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Tab — notification preference toggles
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  static const _labels = <String, String>{
    'messages': 'Messages',
    'bids': 'Bids & Quotes',
    'jobUpdates': 'Job Updates',
    'reviews': 'Reviews',
    'referrals': 'Referrals',
    'promotions': 'Promotions',
  };

  static const _icons = <String, IconData>{
    'messages': Icons.chat_bubble_outline,
    'bids': Icons.gavel,
    'jobUpdates': Icons.work_outline,
    'reviews': Icons.star_outline,
    'referrals': Icons.people_outline,
    'promotions': Icons.local_offer_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, bool>>(
      stream: NotificationPreferencesService.stream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final prefs =
            snapshot.data ?? NotificationPreferencesService.defaultPrefs;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Choose which notifications you want to receive.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final key in _labels.keys)
              SwitchListTile.adaptive(
                secondary: Icon(_icons[key]),
                title: Text(_labels[key]!),
                value: prefs[key] ?? true,
                onChanged: (val) {
                  NotificationPreferencesService.setPreference(key, val);
                },
              ),
          ],
        );
      },
    );
  }
}
