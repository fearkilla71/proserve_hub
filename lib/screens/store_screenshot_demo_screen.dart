import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/demo_mode_service.dart';
import '../theme/proserve_theme.dart';

class StoreScreenshotDemoScreen extends StatelessWidget {
  const StoreScreenshotDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DemoModeService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Screenshot Mode')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Screenshot/demo mode is disabled in this build.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ProServeColors.bg,
      appBar: AppBar(title: const Text('Store Screenshot Mode')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: ProServeColors.cardGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ProServeColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.photo_camera_outlined, color: ProServeColors.accent),
                SizedBox(height: 10),
                Text(
                  'Capture-ready app screens',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  'Use this internal-only page to open polished screens for Play Store and App Store screenshots. No fake production data is written.',
                  style: TextStyle(color: ProServeColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _ScreenshotStoryCard(),
          const SizedBox(height: 16),
          for (final entry in _groupedRoutes().entries) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: ProServeColors.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ...entry.value.map(
              (item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: Text(item.label),
                  subtitle: Text(item.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(item.route),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, List<DemoCaptureRoute>> _groupedRoutes() {
    final grouped = <String, List<DemoCaptureRoute>>{};
    for (final item in DemoModeService.captureRoutes) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }
}

class _ScreenshotStoryCard extends StatelessWidget {
  const _ScreenshotStoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProServeColors.card.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProServeColors.lineStrong),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screenshot story',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Capture the release story in this order: choose a role, start a project, compare trusted pros, protect payment, then show contractor tools and lead workflow.',
            style: TextStyle(color: ProServeColors.muted),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StoryChip('1 Landing'),
              _StoryChip('2 Customer'),
              _StoryChip('3 Quote'),
              _StoryChip('4 Escrow'),
              _StoryChip('5 Contractor OS'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryChip extends StatelessWidget {
  const _StoryChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: ProServeColors.accent.withValues(alpha: 0.10),
      side: BorderSide(color: ProServeColors.accent.withValues(alpha: 0.30)),
    );
  }
}
