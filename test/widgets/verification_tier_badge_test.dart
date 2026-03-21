import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/widgets/verification_tier_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('tierFromString', () {
    test('parses known tier strings', () {
      expect(tierFromString('verified'), VerificationTier.verified);
      expect(tierFromString('trusted_pro'), VerificationTier.trustedPro);
      expect(tierFromString('elite_pro'), VerificationTier.elitePro);
    });

    test('returns none for unknown strings', () {
      expect(tierFromString('unknown'), VerificationTier.none);
      expect(tierFromString(''), VerificationTier.none);
      expect(tierFromString(null), VerificationTier.none);
    });
  });

  group('VerificationTierBadge', () {
    testWidgets('renders nothing for none tier', (tester) async {
      await tester.pumpWidget(
        wrap(const VerificationTierBadge(tier: VerificationTier.none)),
      );
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows Verified badge', (tester) async {
      await tester.pumpWidget(
        wrap(const VerificationTierBadge(tier: VerificationTier.verified)),
      );
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('shows Trusted Pro badge', (tester) async {
      await tester.pumpWidget(
        wrap(const VerificationTierBadge(tier: VerificationTier.trustedPro)),
      );
      expect(find.text('Trusted Pro'), findsOneWidget);
    });

    testWidgets('shows Elite Pro badge', (tester) async {
      await tester.pumpWidget(
        wrap(const VerificationTierBadge(tier: VerificationTier.elitePro)),
      );
      expect(find.text('Elite Pro'), findsOneWidget);
    });
  });

  group('VerificationTierCard', () {
    testWidgets('renders criteria for elite tier', (tester) async {
      await tester.pumpWidget(
        wrap(const SingleChildScrollView(
          child: VerificationTierCard(
            currentTier: VerificationTier.elitePro,
            completedJobs: 150,
            avgRating: 4.9,
            yearsActive: 5,
          ),
        )),
      );
      expect(find.textContaining('100+'), findsOneWidget);
      expect(find.textContaining('4.7'), findsOneWidget);
    });
  });
}
