import 'package:flutter/material.dart';
import '../theme/proserve_theme.dart';

import 'contractor_portal_page.dart';
import 'contractor_subscription_screen.dart';

class ContractorSignupPitchPage extends StatefulWidget {
  const ContractorSignupPitchPage({super.key});

  @override
  State<ContractorSignupPitchPage> createState() =>
      _ContractorSignupPitchPageState();
}

class _ContractorSignupPitchPageState extends State<ContractorSignupPitchPage> {
  final PageController _controller = PageController();
  int _index = 0;

  final _slides = const [
    _PitchSlide(
      title: 'Instant estimates to win more work',
      subtitle: 'Accurate bids in under 30 seconds.',
      illustration: _AssetIllustration(
        assetPath: 'assets/pitch/estimate_card.png',
        width: 220,
        height: 220,
      ),
    ),
    _PitchSlide(
      title: 'Be 4x More Profitable with AI',
      subtitle: 'Bid smarter & charge more with local price data.',
      illustration: _AssetIllustration(
        assetPath: 'assets/pitch/profit_chart.png',
        width: 240,
        height: 200,
      ),
    ),
    _PitchSlide(
      title: 'Win More Jobs. In Minutes.',
      subtitle: 'Send accurate estimates in minutes, not hours.',
      illustration: _AssetIllustration(
        assetPath: 'assets/pitch/cost_estimator.png',
        width: 210,
        height: 240,
      ),
    ),
    _PitchSlide(
      title: 'Results in Week One.',
      subtitle: 'Real contractors, real results.',
      illustration: _AssetIllustration(
        assetPath: 'assets/pitch/review_card.png',
        width: 260,
        height: 240,
      ),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _slides.length - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ContractorPortalPage()),
      (r) => false,
    );
  }

  void _openSubscribe() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ContractorSubscriptionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: ProServeColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'ProServe Hub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
                decoration: const BoxDecoration(
                  color: ProServeColors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) {
                          final slide = _slides[i];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.92, end: 1),
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: child,
                                  );
                                },
                                child: slide.illustration,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                slide.subtitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 16 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Swipe to continue →',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_index == _slides.length - 1) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _openSubscribe,
                          child: const Text('Subscribe to Pro Tools'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goToHome,
                          child: const Text('Start'),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _next,
                          child: const Text('Next'),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    TextButton(
                      onPressed: _goToHome,
                      child: const Text('Skip for now'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchSlide {
  const _PitchSlide({
    required this.title,
    required this.subtitle,
    required this.illustration,
  });

  final String title;
  final String subtitle;
  final Widget illustration;
}

class _AssetIllustration extends StatelessWidget {
  const _AssetIllustration({
    required this.assetPath,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}
