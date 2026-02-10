import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/models/contractor_badge.dart';

void main() {
  // ── computeEarnedAchievements ─────────────────────────────────────────

  group('computeEarnedAchievements', () {
    test('returns empty list for zero stats', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 0,
        reviewCount: 0,
        avgRating: 0.0,
      );
      expect(earned, isEmpty);
    });

    test('awards first-job badge at 1 job', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 1,
        reviewCount: 0,
        avgRating: 0.0,
      );
      expect(earned, contains('jobs_1'));
      expect(earned, isNot(contains('jobs_5')));
    });

    test('awards multiple job milestones', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 50,
        reviewCount: 0,
        avgRating: 0.0,
      );
      expect(
        earned,
        containsAll(['jobs_1', 'jobs_5', 'jobs_10', 'jobs_25', 'jobs_50']),
      );
      expect(earned, isNot(contains('jobs_100')));
    });

    test('awards review milestones', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 0,
        reviewCount: 25,
        avgRating: 0.0,
      );
      expect(earned, containsAll(['reviews_1', 'reviews_10', 'reviews_25']));
      expect(earned, isNot(contains('reviews_50')));
    });

    test(
      'awards rating milestone when both rating and count thresholds met',
      () {
        final earned = computeEarnedAchievements(
          totalJobsCompleted: 0,
          reviewCount: 10,
          avgRating: 4.5,
        );
        expect(earned, contains('rating_45'));
      },
    );

    test('does not award rating milestone when review count too low', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 0,
        reviewCount: 5,
        avgRating: 5.0,
      );
      // rating_50 requires 10+ reviews
      expect(earned, isNot(contains('rating_50')));
    });

    test('awards perfect score badge', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 0,
        reviewCount: 10,
        avgRating: 5.0,
      );
      expect(earned, contains('rating_50'));
    });

    test('awards all possible badges for legendary contractor', () {
      final earned = computeEarnedAchievements(
        totalJobsCompleted: 500,
        reviewCount: 50,
        avgRating: 5.0,
      );
      // Should have all 8 job milestones + 4 review milestones + 3 rating milestones = 15
      expect(earned.length, 15);
    });
  });

  // ── badgeById ─────────────────────────────────────────────────────────

  group('badgeById', () {
    test('finds profile badge by id', () {
      final badge = badgeById('licensed');
      expect(badge, isNotNull);
      expect(badge!.label, 'Licensed');
      expect(badge.category, BadgeCategory.profile);
    });

    test('finds achievement badge by id', () {
      final badge = badgeById('jobs_1');
      expect(badge, isNotNull);
      expect(badge!.label, 'First Job');
      expect(badge.category, BadgeCategory.achievement);
    });

    test('returns null for unknown id', () {
      expect(badgeById('nonexistent_badge'), isNull);
    });
  });

  // ── migrateLegacyBadgeId ──────────────────────────────────────────────

  group('migrateLegacyBadgeId', () {
    test('converts "Top Rated" to "top_rated"', () {
      expect(migrateLegacyBadgeId('Top Rated'), 'top_rated');
    });

    test('converts "Family Owned" to "family_owned"', () {
      expect(migrateLegacyBadgeId('Family Owned'), 'family_owned');
    });

    test('converts "Background Checked" to "background_checked"', () {
      expect(migrateLegacyBadgeId('Background Checked'), 'background_checked');
    });

    test('converts "Eco Friendly" to "eco_friendly"', () {
      expect(migrateLegacyBadgeId('Eco Friendly'), 'eco_friendly');
    });

    test('converts "Quick Response" to "quick_response"', () {
      expect(migrateLegacyBadgeId('Quick Response'), 'quick_response');
    });

    test('is case-insensitive', () {
      expect(migrateLegacyBadgeId('TOP RATED'), 'top_rated');
      expect(migrateLegacyBadgeId('licensed'), 'licensed');
    });

    test('handles unknown legacy string with generic conversion', () {
      expect(migrateLegacyBadgeId('Some New Badge'), 'some_new_badge');
    });

    test('trims whitespace', () {
      expect(migrateLegacyBadgeId('  Licensed  '), 'licensed');
    });
  });

  // ── resolveBadges ─────────────────────────────────────────────────────

  group('resolveBadges', () {
    test('resolves list of known badge ids', () {
      final badges = resolveBadges(['licensed', 'insured']);
      expect(badges.length, 2);
      expect(badges[0].id, 'licensed');
      expect(badges[1].id, 'insured');
    });

    test('resolves legacy strings through migration', () {
      final badges = resolveBadges(['Top Rated', 'Family Owned']);
      expect(badges.length, 2);
      expect(badges[0].id, 'top_rated');
      expect(badges[1].id, 'family_owned');
    });

    test('skips unknown badges', () {
      final badges = resolveBadges(['licensed', 'totally_fake', 'insured']);
      expect(badges.length, 2);
    });

    test('returns empty list for empty input', () {
      expect(resolveBadges([]), isEmpty);
    });
  });

  // ── achievementBadges getter ──────────────────────────────────────────

  group('achievementBadges', () {
    test('contains expected number of badges', () {
      // 8 job + 4 review + 3 rating = 15
      expect(achievementBadges.length, 15);
    });

    test('all have achievement category', () {
      for (final b in achievementBadges) {
        expect(b.category, BadgeCategory.achievement);
      }
    });

    test('all have a tier', () {
      for (final b in achievementBadges) {
        expect(b.tier, isNotNull);
      }
    });

    test('ids are unique', () {
      final ids = achievementBadges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // ── profileBadges ─────────────────────────────────────────────────────

  group('profileBadges', () {
    test('contains 7 profile badges', () {
      expect(profileBadges.length, 7);
    });

    test('all have profile category', () {
      for (final b in profileBadges) {
        expect(b.category, BadgeCategory.profile);
      }
    });

    test('ids are unique', () {
      final ids = profileBadges.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // ── tierLabel ─────────────────────────────────────────────────────────

  group('tierLabel', () {
    test('returns correct labels', () {
      expect(tierLabel(BadgeTier.bronze), 'Bronze');
      expect(tierLabel(BadgeTier.silver), 'Silver');
      expect(tierLabel(BadgeTier.gold), 'Gold');
      expect(tierLabel(BadgeTier.platinum), 'Platinum');
      expect(tierLabel(BadgeTier.legendary), 'Legendary');
    });
  });
}
