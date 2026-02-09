import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  final bool showSubtitle;
  final bool showTrailing;

  const SkeletonListTile({
    super.key,
    this.showSubtitle = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SkeletonBox(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14, width: 180),
                if (showSubtitle) ...[
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 12, width: 240),
                ],
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const SkeletonBox(height: 12, width: 44),
          ],
        ],
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(height: 16, width: 160),
            SizedBox(height: 12),
            SkeletonBox(height: 12, width: double.infinity),
            SizedBox(height: 8),
            SkeletonBox(height: 12, width: 260),
          ],
        ),
      ),
    );
  }
}

class SkeletonForm extends StatelessWidget {
  final int fieldCount;

  const SkeletonForm({super.key, this.fieldCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SkeletonBox(height: 22, width: 180),
        const SizedBox(height: 18),
        for (int i = 0; i < fieldCount; i++) ...[
          const SkeletonBox(height: 54, width: double.infinity),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
