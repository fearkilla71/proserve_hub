import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.chips,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;

  /// Optional chips/badges rendered under the title/subtitle.
  final List<Widget>? chips;

  /// Optional trailing widget (e.g., action button or icon).
  final Widget? trailing;

  /// Defaults to EdgeInsets.fromLTRB(16, 12, 16, 16).
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 16);
    final subtitleText = (subtitle ?? '').trim();
    final chipsList = chips ?? const <Widget>[];

    return Padding(
      padding: resolvedPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (chipsList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: chipsList),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
