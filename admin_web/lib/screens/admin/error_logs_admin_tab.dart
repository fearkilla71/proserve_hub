import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ---------------------------------------------------------------------------
/// Error Logs Admin Tab — View app errors reported from mobile/web clients
/// ---------------------------------------------------------------------------
class ErrorLogsAdminTab extends StatefulWidget {
  const ErrorLogsAdminTab({super.key});

  @override
  State<ErrorLogsAdminTab> createState() => _ErrorLogsAdminTabState();
}

class _ErrorLogsAdminTabState extends State<ErrorLogsAdminTab> {
  static const _pageSize = 50;

  final _ref = FirebaseFirestore.instance.collection('error_logs');
  final _fmt = DateFormat('MMM d, yyyy  h:mm a');

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String _levelFilter = 'all'; // all | error | flutter_error
  String _platformFilter = 'all'; // all | android | iOS | web | windows

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      _lastDoc = null;
      _docs = [];
      _hasMore = true;
    }
    if (!_hasMore) return;

    setState(() => _loading = true);

    try {
      Query<Map<String, dynamic>> q = _ref
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (_levelFilter != 'all') {
        q = q.where('level', isEqualTo: _levelFilter);
      }
      if (_platformFilter != 'all') {
        q = q.where('platform', isEqualTo: _platformFilter);
      }
      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.get();
      if (!mounted) return;

      setState(() {
        _docs.addAll(snap.docs);
        _hasMore = snap.docs.length == _pageSize;
        if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteLog(String docId) async {
    await _ref.doc(docId).delete();
    setState(() => _docs.removeWhere((d) => d.id == docId));
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Error Logs?'),
        content: const Text(
          'This will permanently delete all error log entries. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Batch delete in groups of 500.
    final allDocs = await _ref.limit(500).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in allDocs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    _loadPage(reset: true);
  }

  Color _levelColor(String level) {
    return switch (level) {
      'flutter_error' => Colors.red,
      'error' => Colors.orange,
      _ => Colors.grey,
    };
  }

  IconData _platformIcon(String platform) {
    return switch (platform) {
      'android' => Icons.android,
      'iOS' => Icons.phone_iphone,
      'web' => Icons.language,
      'windows' => Icons.desktop_windows,
      'macOS' => Icons.laptop_mac,
      _ => Icons.devices_other,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.bug_report, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Error Logs',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Text('${_docs.length} entries', style: theme.textTheme.bodySmall),
              const Spacer(),
              // Level filter
              DropdownButton<String>(
                value: _levelFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Levels')),
                  DropdownMenuItem(value: 'error', child: Text('Error')),
                  DropdownMenuItem(
                    value: 'flutter_error',
                    child: Text('Flutter Error'),
                  ),
                ],
                onChanged: (v) {
                  _levelFilter = v ?? 'all';
                  _loadPage(reset: true);
                },
              ),
              const SizedBox(width: 8),
              // Platform filter
              DropdownButton<String>(
                value: _platformFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Platforms')),
                  DropdownMenuItem(value: 'android', child: Text('Android')),
                  DropdownMenuItem(value: 'iOS', child: Text('iOS')),
                  DropdownMenuItem(value: 'web', child: Text('Web')),
                  DropdownMenuItem(value: 'windows', child: Text('Windows')),
                ],
                onChanged: (v) {
                  _platformFilter = v ?? 'all';
                  _loadPage(reset: true);
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => _loadPage(reset: true),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All',
                onPressed: _clearAll,
              ),
            ],
          ),
        ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: _docs.isEmpty && !_loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No errors logged',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your app is running clean!',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _docs.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _docs.length) {
                      // Load-more trigger
                      if (!_loading) _loadPage();
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final doc = _docs[i];
                    final d = doc.data();
                    final level = d['level'] as String? ?? 'error';
                    final msg = d['message'] as String? ?? '';
                    final ctx = d['context'] as String? ?? '';
                    final uid = d['uid'] as String? ?? '';
                    final platform = d['platform'] as String? ?? '';
                    final stack = d['stackTrace'] as String? ?? '';
                    final ts = (d['createdAt'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: _levelColor(
                            level,
                          ).withValues(alpha: 0.15),
                          child: Icon(
                            _platformIcon(platform),
                            size: 18,
                            color: _levelColor(level),
                          ),
                        ),
                        title: Text(
                          msg.length > 120 ? '${msg.substring(0, 120)}…' : msg,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _levelColor(
                                  level,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                level.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _levelColor(level),
                                ),
                              ),
                            ),
                            if (ctx.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                'ctx: $ctx',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const Spacer(),
                            if (ts != null)
                              Text(
                                _fmt.format(ts),
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                _detailRow('User ID', uid),
                                _detailRow('Platform', platform),
                                _detailRow(
                                  'App Version',
                                  d['appVersion'] as String? ?? '',
                                ),
                                if (ctx.isNotEmpty) _detailRow('Context', ctx),
                                const SizedBox(height: 8),
                                Text(
                                  'Error Message',
                                  style: theme.textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: SelectableText(
                                    msg,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                if (stack.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Stack Trace',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SingleChildScrollView(
                                      child: SelectableText(
                                        stack,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Delete'),
                                    onPressed: () => _deleteLog(doc.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        if (_loading && _docs.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
