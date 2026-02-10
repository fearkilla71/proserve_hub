import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ProServe Hub Brand Palette — matches the landing page at proservehub.netlify.app
///
/// Landing page CSS variables:
///   --bg:      #071022
///   --bg-deep: #050b18
///   --ink:     #e6f1ff
///   --muted:   #9fb2d4
///   --accent:  #22e39b  (teal / primary CTA)
///   --accent-2:#36b3ff  (blue / secondary)
///   --accent-3:#8f5bff  (purple / tertiary)
///   --card:    rgba(12,23,44,0.82)
///   --line:    rgba(255,255,255,0.08)
///
/// Fonts: Bebas Neue (headings) + Manrope (body)
class ProServeColors {
  ProServeColors._();

  // Core surfaces
  static const bg = Color(0xFF071022);
  static const bgDeep = Color(0xFF050B18);
  static const card = Color(0xFF0C172C);
  static const cardElevated = Color(0xFF101E38);

  // Text
  static const ink = Color(0xFFE6F1FF);
  static const muted = Color(0xFF9FB2D4);

  // Accents
  static const accent = Color(0xFF22E39B); // teal-green
  static const accent2 = Color(0xFF36B3FF); // sky-blue
  static const accent3 = Color(0xFF8F5BFF); // purple

  // Borders
  static const line = Color(0x14FFFFFF); // 8% white
  static const lineStrong = Color(0x29FFFFFF); // 16% white

  // Semantic
  static const error = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFB300);
  static const success = accent;

  // Gradient helpers
  static const ctaGradient = LinearGradient(
    colors: [accent, accent2],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF0A1731), Color(0xFF071022), Color(0xFF050B18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF0E1D3A), Color(0xFF0A152B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ProServeTheme {
  ProServeTheme._();

  static TextTheme _buildTextTheme() {
    final bodyBase = GoogleFonts.manropeTextTheme();
    final displayBase = GoogleFonts.bebasNeueTextTheme();

    return bodyBase.copyWith(
      // Display & Headline = Bebas Neue
      displayLarge: displayBase.displayLarge?.copyWith(
        color: ProServeColors.ink,
        letterSpacing: 1.5,
      ),
      displayMedium: displayBase.displayMedium?.copyWith(
        color: ProServeColors.ink,
        letterSpacing: 1.2,
      ),
      displaySmall: displayBase.displaySmall?.copyWith(
        color: ProServeColors.ink,
        letterSpacing: 1.0,
      ),
      headlineLarge: displayBase.headlineLarge?.copyWith(
        color: ProServeColors.ink,
        letterSpacing: 0.8,
      ),
      headlineMedium: displayBase.headlineMedium?.copyWith(
        color: ProServeColors.ink,
        letterSpacing: 0.5,
      ),
      headlineSmall: displayBase.headlineSmall?.copyWith(
        color: ProServeColors.ink,
        letterSpacing: 0.3,
      ),
      // Title & Body = Manrope
      titleLarge: bodyBase.titleLarge?.copyWith(
        color: ProServeColors.ink,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: bodyBase.titleMedium?.copyWith(
        color: ProServeColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: bodyBase.titleSmall?.copyWith(
        color: ProServeColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: bodyBase.bodyLarge?.copyWith(color: ProServeColors.ink),
      bodyMedium: bodyBase.bodyMedium?.copyWith(color: ProServeColors.muted),
      bodySmall: bodyBase.bodySmall?.copyWith(color: ProServeColors.muted),
      labelLarge: bodyBase.labelLarge?.copyWith(
        color: ProServeColors.ink,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: bodyBase.labelMedium?.copyWith(
        color: ProServeColors.muted,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: bodyBase.labelSmall?.copyWith(
        color: ProServeColors.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// The unified dark color scheme matching the landing page.
  static final ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary = accent teal
    primary: ProServeColors.accent,
    onPrimary: const Color(0xFF041016),
    primaryContainer: const Color(0xFF0A3D2D),
    onPrimaryContainer: ProServeColors.accent,
    // Secondary = accent blue
    secondary: ProServeColors.accent2,
    onSecondary: const Color(0xFF041016),
    secondaryContainer: const Color(0xFF0A2A44),
    onSecondaryContainer: ProServeColors.accent2,
    // Tertiary = accent purple
    tertiary: ProServeColors.accent3,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF2A1B52),
    onTertiaryContainer: ProServeColors.accent3,
    // Error
    error: ProServeColors.error,
    onError: Colors.white,
    errorContainer: const Color(0xFF3D1313),
    onErrorContainer: ProServeColors.error,
    // Surface hierarchy
    surface: ProServeColors.bg,
    onSurface: ProServeColors.ink,
    onSurfaceVariant: ProServeColors.muted,
    surfaceContainerLowest: ProServeColors.bgDeep,
    surfaceContainerLow: ProServeColors.card,
    surfaceContainer: ProServeColors.cardElevated,
    surfaceContainerHigh: const Color(0xFF142647),
    surfaceContainerHighest: const Color(0xFF1A2E52),
    // Outline
    outline: ProServeColors.lineStrong,
    outlineVariant: ProServeColors.line,
    // Misc
    inverseSurface: ProServeColors.ink,
    onInverseSurface: ProServeColors.bg,
    inversePrimary: const Color(0xFF0A6B4A),
    scrim: Colors.black,
    shadow: const Color(0xFF050C1A),
    surfaceTint: ProServeColors.accent,
  );

  /// Full ThemeData for the app.
  static ThemeData darkTheme() {
    final textTheme = _buildTextTheme();
    final scheme = darkScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: ProServeColors.bgDeep.withValues(alpha: 0.78),
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ProServeColors.card,
        hintStyle: TextStyle(
          color: ProServeColors.muted.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ProServeColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ProServeColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ProServeColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ProServeColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ProServeColors.error, width: 2),
        ),
      ),

      // Buttons — gradient CTA style handled per-widget, but base styles here
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ProServeColors.accent,
          foregroundColor: const Color(0xFF041016),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ProServeColors.accent,
          foregroundColor: const Color(0xFF041016),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ProServeColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide(color: ProServeColors.lineStrong),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ProServeColors.accent,
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: ProServeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ProServeColors.line),
        ),
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ProServeColors.bgDeep.withValues(alpha: 0.9),
        indicatorColor: ProServeColors.accent.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: ProServeColors.accent);
          }
          return const IconThemeData(color: ProServeColors.muted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ProServeColors.accent,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ProServeColors.muted,
          );
        }),
      ),

      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ProServeColors.accent,
        foregroundColor: Color(0xFF041016),
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: ProServeColors.card,
        selectedColor: ProServeColors.accent.withValues(alpha: 0.2),
        side: BorderSide(color: ProServeColors.line),
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          color: ProServeColors.ink,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: ProServeColors.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ProServeColors.ink,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ProServeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ProServeColors.cardElevated,
        contentTextStyle: GoogleFonts.manrope(
          color: ProServeColors.ink,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ProServeColors.line),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: ProServeColors.line,
        thickness: 1,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        iconColor: ProServeColors.muted,
        textColor: ProServeColors.ink,
        subtitleTextStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: ProServeColors.muted,
        ),
      ),

      // Switch / checkbox
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ProServeColors.accent;
          }
          return ProServeColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ProServeColors.accent.withValues(alpha: 0.35);
          }
          return ProServeColors.line;
        }),
      ),

      // Tab bar
      tabBarTheme: TabBarThemeData(
        labelColor: ProServeColors.accent,
        unselectedLabelColor: ProServeColors.muted,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: ProServeColors.accent, width: 3),
        ),
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ProServeColors.accent,
        linearTrackColor: ProServeColors.line,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: ProServeColors.muted),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ProServeColors.cardElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ProServeColors.line),
        ),
        textStyle: GoogleFonts.manrope(fontSize: 12, color: ProServeColors.ink),
      ),
    );
  }
}

/// Reusable gradient CTA button matching the landing-page `.cta` style.
class ProServeCTAButton extends StatelessWidget {
  const ProServeCTAButton({
    super.key,
    this.label,
    this.child,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  }) : assert(
         label != null || child != null,
         'Either label or child must be provided',
       );

  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final buttonChild = Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: onPressed != null ? ProServeColors.ctaGradient : null,
        color: onPressed == null ? Colors.grey[700] : null,
        borderRadius: BorderRadius.circular(999),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: ProServeColors.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child:
          child ??
          Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF041016), size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label ?? '',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF041016),
                ),
              ),
            ],
          ),
    );

    return Semantics(
      button: true,
      label: label,
      child: expanded
          ? SizedBox(
              width: double.infinity,
              child: GestureDetector(onTap: onPressed, child: buttonChild),
            )
          : GestureDetector(onTap: onPressed, child: buttonChild),
    );
  }
}

/// Floating orb widget (matches the landing page hero orbs).
class FloatingOrb extends StatefulWidget {
  const FloatingOrb({
    super.key,
    required this.color,
    required this.size,
    this.delay = Duration.zero,
  });

  final Color color;
  final double size;
  final Duration delay;

  @override
  State<FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<FloatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Transform.translate(
          offset: Offset(0, 20 * (t - 0.5)),
          child: Opacity(opacity: 0.4 + 0.2 * t, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4),
              blurRadius: widget.size * 0.6,
            ),
          ],
        ),
      ),
    );
  }
}
