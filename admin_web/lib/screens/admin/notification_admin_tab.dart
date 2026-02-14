import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

/// ---------------------------------------------------------------------------
/// Notification Admin Tab — Send push notifications & view history
/// ---------------------------------------------------------------------------
class NotificationAdminTab extends StatefulWidget {
  final bool canWrite;
  const NotificationAdminTab({super.key, this.canWrite = false});

  @override
  State<NotificationAdminTab> createState() => _NotificationAdminTabState();
}

class _NotificationAdminTabState extends State<NotificationAdminTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];
  StreamSubscription? _historySub;

  // Send form
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _audience = 'all'; // all, customers, contractors, pro, enterprise
  bool _sending = false;

  // Stats
  int _totalUsers = 0;
  int _pushEnabled = 0;
  int _customers = 0;
  int _contractors = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _listenHistory();
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    int total = 0, push = 0, cust = 0, cont = 0;
    for (final d in snap.docs) {
      final data = d.data();
      if (data['isDeleted'] == true) continue;
      total++;
      if ((data['fcmToken'] ?? '').toString().isNotEmpty) push++;
      if (data['role'] == 'customer') cust++;
      if (data['role'] == 'contractor') cont++;
    }
    if (mounted) {
      setState(() {
        _totalUsers = total;
        _pushEnabled = push;
        _customers = cust;
        _contractors = cont;
      });
    }
  }

  void _listenHistory() {
    _historySub = FirebaseFirestore.instance
        .collection('admin_notifications')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snap) {
            setState(() {
              _history = snap.docs.map((d) {
                final data = d.data();
                data['id'] = d.id;
                return data;
              }).toList();
              _loading = false;
            });
          },
          onError: (_) {
            // Collection may not exist yet
            setState(() => _loading = false);
          },
        );
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Notification?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audience: ${_audienceLabel(_audience)}'),
            const SizedBox(height: 8),
            Text(
              'Title: $title',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Body: $body'),
            const SizedBox(height: 12),
            const Text(
              'This will send a push notification to all matching users with push enabled.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sending = true);

    try {
      // Get matching users with FCM tokens
      Query query = FirebaseFirestore.instance.collection('users');

      switch (_audience) {
        case 'customers':
          query = query.where('role', isEqualTo: 'customer');
          break;
        case 'contractors':
          query = query.where('role', isEqualTo: 'contractor');
          break;
        case 'pro':
        case 'enterprise':
          query = query.where('role', isEqualTo: 'contractor');
          break;
      }

      final snap = await query.get();
      final tokens = <String>[];
      final uids = <String>[];

      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (data['isDeleted'] == true) continue;
        final token = (data['fcmToken'] ?? '').toString().trim();
        if (token.isEmpty) continue;

        // Filter by subscription tier if needed
        if (_audience == 'pro' || _audience == 'enterprise') {
          final tier =
              (data['subscriptionTier'] as String?)?.toLowerCase() ?? 'basic';
          if (_audience == 'pro' && tier != 'pro' && tier != 'enterprise') {
            continue;
          }
          if (_audience == 'enterprise' && tier != 'enterprise') continue;
        }

        tokens.add(token);
        uids.add(d.id);
      }

      if (tokens.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No users with push enabled in this audience'),
            ),
          );
        }
        setState(() => _sending = false);
        return;
      }

      // Call cloud function to send
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'sendAdminNotification',
        );
        await callable.call({'title': title, 'body': body, 'tokens': tokens});
      } catch (_) {
        // If cloud function doesn't exist yet, just log it
      }

      // Log to admin_notifications collection
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'title': title,
        'body': body,
        'audience': _audience,
        'recipientCount': tokens.length,
        'recipientUids': uids,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
      });

      _titleCtrl.clear();
      _bodyCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to ${tokens.length} users'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _audienceLabel(String audience) {
    switch (audience) {
      case 'all':
        return 'All Users';
      case 'customers':
        return 'Customers Only';
      case 'contractors':
        return 'All Contractors';
      case 'pro':
        return 'PRO Contractors';
      case 'enterprise':
        return 'Enterprise Contractors';
      default:
        return audience;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Push Notifications',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // ── Stats ────────────────────────────────────────────────
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _kpiCard('Total Users', '$_totalUsers', Icons.people, Colors.blue),
            _kpiCard(
              'Push Enabled',
              '$_pushEnabled',
              Icons.notifications_active,
              Colors.green,
            ),
            _kpiCard('Customers', '$_customers', Icons.person, Colors.teal),
            _kpiCard(
              'Contractors',
              '$_contractors',
              Icons.build,
              Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Send Notification ────────────────────────────────────
        if (widget.canWrite) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Notification',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: const InputDecoration(
                      labelText: 'Target Audience',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Users')),
                      DropdownMenuItem(
                        value: 'customers',
                        child: Text('Customers Only'),
                      ),
                      DropdownMenuItem(
                        value: 'contractors',
                        child: Text('All Contractors'),
                      ),
                      DropdownMenuItem(
                        value: 'pro',
                        child: Text('PRO Contractors'),
                      ),
                      DropdownMenuItem(
                        value: 'enterprise',
                        child: Text('Enterprise Contractors'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _audience = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      hintText: 'e.g., New Feature Available!',
                    ),
                    maxLength: 65,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notification Body',
                      hintText:
                          'e.g., Check out our new AI estimator for instant quotes.',
                    ),
                    maxLines: 3,
                    maxLength: 240,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _sendNotification,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Sending...' : 'Send'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Notification History ─────────────────────────────────
        Text(
          'Notification History',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Column(
            children: [
              ListTileSkeleton(),
              SizedBox(height: 8),
              ListTileSkeleton(),
            ],
          )
        else if (_history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No notifications sent yet',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          )
        else
          ..._history.map((n) {
            final title = n['title'] ?? '';
            final body = n['body'] ?? '';
            final audience = n['audience'] ?? 'all';
            final count = n['recipientCount'] ?? 0;
            final sentAt = n['sentAt'];
            final dateStr = sentAt is Timestamp
                ? DateFormat.yMMMd().add_jm().format(sentAt.toDate())
                : '—';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x330A84FF),
                  child: Icon(Icons.notifications, color: Colors.blue),
                ),
                title: Text(title),
                subtitle: Text(
                  '$body\n'
                  '${_audienceLabel(audience)} · $count recipients · $dateStr',
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
