import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/service_types.dart';
import 'contractor_card.dart';
import 'card_aura_painter.dart';

List<Color> defaultGradientForTheme(String themeKey, ColorScheme scheme) {
  switch (themeKey) {
    case 'forest':
      return const [Color(0xFF0F3D2E), Color(0xFF3BAA6B)];
    case 'amber':
      return const [Color(0xFF4E2A0C), Color(0xFFFFA726)];
    case 'slate':
      return const [Color(0xFF1F2937), Color(0xFF94A3B8)];
    case 'ocean':
      return const [Color(0xFF0F172A), Color(0xFF38BDF8)];
    case 'rose':
      return const [Color(0xFF4C0519), Color(0xFFFB7185)];
    case 'sunburst':
      return const [Color(0xFF2C1200), Color(0xFFFF6D00)];
    case 'ember':
      return const [Color(0xFF2B0C0C), Color(0xFFFF7043)];
    case 'neon':
      return const [Color(0xFF051A13), Color(0xFF00E676)];
    case 'carbon':
      return const [Color(0xFF111827), Color(0xFF374151)];
    case 'gold':
      return const [Color(0xFF3A2A00), Color(0xFFFFD54F)];
    case 'navy':
    default:
      return [scheme.primary.withValues(alpha: 0.9), scheme.primary];
  }
}

Color colorFromDoc(dynamic value, Color fallback) {
  if (value is int) {
    return Color(value);
  }
  return fallback;
}

/// Builds a [ContractorCard] populated from a Firestore user/contractor map.
Widget buildContractorCardFromDoc({
  required BuildContext context,
  required User user,
  required Map<String, dynamic>? data,
  required String fallbackName,
}) {
  final scheme = Theme.of(context).colorScheme;
  final themeKey =
      (data?['cardTheme'] as String?)?.trim().toLowerCase() ?? 'navy';
  final dg = defaultGradientForTheme(themeKey, scheme);
  final gradientStart = colorFromDoc(data?['gradientStart'], dg[0]);
  final gradientEnd = colorFromDoc(data?['gradientEnd'], dg[1]);
  final displayName =
      (data?['publicName'] as String?)?.trim().isNotEmpty == true
      ? (data?['publicName'] as String).trim()
      : ((data?['businessName'] as String?)?.trim().isNotEmpty == true
            ? (data?['businessName'] as String).trim()
            : ((data?['companyName'] as String?)?.trim().isNotEmpty == true
                  ? (data?['companyName'] as String).trim()
                  : ((data?['name'] as String?)?.trim().isNotEmpty == true
                        ? (data?['name'] as String).trim()
                        : fallbackName)));
  final phone = (data?['publicPhone'] as String?)?.trim() ?? '';
  final contractorName = (data?['name'] as String?)?.trim() ?? '';
  final headline = (data?['headline'] as String?)?.trim() ?? '';
  final bio = (data?['bio'] as String?)?.trim() ?? '';
  final logoUrl = (data?['logoUrl'] as String?)?.trim() ?? '';
  final avatarStyle = (data?['avatarStyle'] as String?)?.trim() ?? 'monogram';
  final avatarShape = (data?['avatarShape'] as String?)?.trim() ?? 'circle';
  final texture = (data?['cardTexture'] as String?)?.trim() ?? 'none';
  final textureOpacityRaw = data?['textureOpacity'];
  final textureOpacity = textureOpacityRaw is num
      ? textureOpacityRaw.toDouble().clamp(0.04, 0.5)
      : 0.12;
  final showBanner = data?['showBanner'] as bool? ?? true;
  final bannerIcon = (data?['bannerIcon'] as String?)?.trim() ?? 'spark';
  final avatarGlow = data?['avatarGlow'] as bool? ?? false;
  final avgRating = (data?['avgRating'] ?? data?['averageRating']);
  final ratingValue = avgRating is num ? avgRating.toDouble() : 0.0;
  final reviewCountRaw = data?['reviewCount'] ?? data?['totalReviews'];
  final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
  final yearsExpRaw = data?['yearsExperience'];
  final yearsExp = yearsExpRaw is num ? yearsExpRaw.toInt() : 0;
  final badges =
      (data?['badges'] as List?)
          ?.whereType<String>()
          .map((badge) => badge.trim())
          .where((badge) => badge.isNotEmpty)
          .toList() ??
      <String>[];
  final totalJobsRaw = data?['totalJobsCompleted'] ?? data?['completedJobs'];
  final totalJobsCompleted = totalJobsRaw is num ? totalJobsRaw.toInt() : 0;

  final aura = auraFromString((data?['cardAura'] as String?)?.trim());
  final responseTime = (data?['responseTime'] as String?)?.trim() ?? '';
  final completionRateRaw = data?['completionRate'];
  final completionRate = completionRateRaw is num
      ? completionRateRaw.toInt()
      : 0;
  final certifications =
      (data?['certifications'] as List?)
          ?.whereType<String>()
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList() ??
      <String>[];
  final servicesOffered = contractorServicesFromData(data);
  final memberSince = (data?['memberSince'] as String?)?.trim() ?? '';

  final reviewStream = FirebaseFirestore.instance
      .collection('reviews')
      .where('contractorId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots();

  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: reviewStream,
    builder: (context, reviewSnap) {
      String latestReview = '';
      if (reviewSnap.hasData && reviewSnap.data!.docs.isNotEmpty) {
        final review = reviewSnap.data!.docs.first.data();
        latestReview = (review['comment'] as String?)?.trim() ?? '';
      }

      return ContractorCard(
        data: ContractorCardData(
          displayName: displayName,
          contractorName: contractorName,
          contactLine: phone.isNotEmpty ? phone : (user.email ?? ''),
          logoUrl: logoUrl,
          headline: headline,
          bio: bio,
          ratingValue: ratingValue,
          reviewCount: reviewCount,
          yearsExp: yearsExp,
          badges: badges,
          themeKey: themeKey,
          gradientStart: gradientStart,
          gradientEnd: gradientEnd,
          avatarStyle: avatarStyle,
          avatarShape: avatarShape,
          texture: texture,
          textureOpacity: textureOpacity,
          showBanner: showBanner,
          bannerIcon: bannerIcon,
          avatarGlow: avatarGlow,
          latestReview: latestReview,
          totalJobsCompleted: totalJobsCompleted,
          aura: aura,
          responseTime: responseTime,
          completionRate: completionRate,
          certifications: certifications,
          servicesOffered: servicesOffered,
          memberSince: memberSince,
        ),
        onEdit: () {
          context.push('/edit-card');
        },
      );
    },
  );
}
