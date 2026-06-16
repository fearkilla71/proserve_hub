import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LinkedJobContextCard extends StatelessWidget {
  const LinkedJobContextCard({
    super.key,
    required this.jobId,
    required this.jobData,
    this.title = 'Linked job',
    this.compact = false,
  });

  final String? jobId;
  final Map<String, dynamic>? jobData;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final id = jobId?.trim() ?? '';
    final data = jobData ?? const <String, dynamic>{};
    if (id.isEmpty && data.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final service = _firstText(data, const ['service', 'title', 'jobTitle']);
    final location = _firstText(data, const ['location', 'address']);
    final status = _firstText(data, const ['status']);

    return Card(
      color: scheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.work_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.isEmpty ? 'Job ${_shortId(id)}' : service,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location.isNotEmpty || status.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (location.isNotEmpty) location,
                        if (status.isNotEmpty) _statusLabel(status),
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer.withValues(
                          alpha: 0.78,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (id.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/job-command/$id'),
                child: const Text('Open'),
              ),
          ],
        ),
      ),
    );
  }

  static String _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _shortId(String id) => id.length <= 6 ? id : id.substring(0, 6);

  static String _statusLabel(String status) {
    return status
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
