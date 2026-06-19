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
          ...DemoModeService.captureRoutes.map(
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
      ),
    );
  }
}
