import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette mirroring the main ProServe Hub app and landing page.
///
/// CSS variables from proservehub.netlify.app:
///   --bg:      #071022      --accent:  #22e39b (teal)
///   --bg-deep: #050b18      --accent-2:#36b3ff (blue)
///   --ink:     #e6f1ff      --accent-3:#8f5bff (purple)
///   --muted:   #9fb2d4      --card:    rgba(12,23,44,0.82)
///   --line:    rgba(255,255,255,0.08)
class AdminColors {
  AdminColors._();

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
  static const line = Color(0x14FFFFFF); // 8 % white
  static const lineStrong = Color(0x29FFFFFF); // 16 % white

  // Semantic
  static const error = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFB300);
  static const success = accent;
}

class AdminTheme {
  AdminTheme._();

  // ── Typography ──────────────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    final body = GoogleFonts.manropeTextTheme();
    final display = GoogleFonts.bebasNeueTextTheme();

    return body.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        color: AdminColors.ink,
        letterSpacing: 1.5,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: AdminColors.ink,
        letterSpacing: 1.2,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: AdminColors.ink,
        letterSpacing: 1.0,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        color: AdminColors.ink,
        letterSpacing: 0.8,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        color: AdminColors.ink,
        letterSpacing: 0.5,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        color: AdminColors.ink,
        letterSpacing: 0.3,
      ),
      titleLarge: body.titleLarge?.copyWith(
        color: AdminColors.ink,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: body.titleMedium?.copyWith(
        color: AdminColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AdminColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AdminColors.ink),
      bodyMedium: body.bodyMedium?.copyWith(color: AdminColors.muted),
      bodySmall: body.bodySmall?.copyWith(color: AdminColors.muted),
      labelLarge: body.labelLarge?.copyWith(
        color: AdminColors.ink,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: body.labelMedium?.copyWith(
        color: AdminColors.muted,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: body.labelSmall?.copyWith(
        color: AdminColors.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Color scheme ────────────────────────────────────────────────────
  static final ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AdminColors.accent,
    onPrimary: const Color(0xFF041016),
    primaryContainer: const Color(0xFF0A3D2D),
    onPrimaryContainer: AdminColors.accent,
    secondary: AdminColors.accent2,
    onSecondary: const Color(0xFF041016),
    secondaryContainer: const Color(0xFF0A2A44),
    onSecondaryContainer: AdminColors.accent2,
    tertiary: AdminColors.accent3,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF2A1B52),
    onTertiaryContainer: AdminColors.accent3,
    error: AdminColors.error,
    onError: Colors.white,
    errorContainer: const Color(0xFF3D1313),
    onErrorContainer: AdminColors.error,
    surface: AdminColors.bg,
    onSurface: AdminColors.ink,
    onSurfaceVariant: AdminColors.muted,
    surfaceContainerLowest: AdminColors.bgDeep,
    surfaceContainerLow: AdminColors.card,
    surfaceContainer: AdminColors.cardElevated,
    surfaceContainerHigh: const Color(0xFF142647),
    surfaceContainerHighest: const Color(0xFF1A2E52),
    outline: AdminColors.lineStrong,
    outlineVariant: AdminColors.line,
    inverseSurface: AdminColors.ink,
    onInverseSurface: AdminColors.bg,
    inversePrimary: const Color(0xFF0A6B4A),
    scrim: Colors.black,
    shadow: const Color(0xFF050C1A),
    surfaceTint: AdminColors.accent,
  );

  // ── Full ThemeData ──────────────────────────────────────────────────
  static ThemeData darkTheme() {
    final text = _buildTextTheme();
    final s = darkScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: s,
      textTheme: text,
      scaffoldBackgroundColor: s.surface,

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AdminColors.bgDeep,
        foregroundColor: s.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: s.onSurface,
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.card,
        hintStyle: TextStyle(color: AdminColors.muted.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AdminColors.error, width: 2),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.accent,
          foregroundColor: const Color(0xFF041016),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.accent,
          foregroundColor: const Color(0xFF041016),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: AdminColors.lineStrong),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.accent,
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: AdminColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AdminColors.line),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.card,
        selectedColor: AdminColors.accent.withValues(alpha: 0.2),
        side: BorderSide(color: AdminColors.line),
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          color: AdminColors.ink,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AdminColors.ink,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AdminColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminColors.cardElevated,
        contentTextStyle: GoogleFonts.manrope(
          color: AdminColors.ink,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AdminColors.line),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AdminColors.line,
        thickness: 1,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        iconColor: AdminColors.muted,
        textColor: AdminColors.ink,
        subtitleTextStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: AdminColors.muted,
        ),
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: AdminColors.accent,
        unselectedLabelColor: AdminColors.muted,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AdminColors.accent, width: 3),
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

      // NavigationRail (sidebar)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AdminColors.bgDeep,
        selectedIconTheme: const IconThemeData(color: AdminColors.accent),
        unselectedIconTheme: const IconThemeData(color: AdminColors.muted),
        selectedLabelTextStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AdminColors.accent,
        ),
        unselectedLabelTextStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AdminColors.muted,
        ),
        indicatorColor: AdminColors.accent.withValues(alpha: 0.15),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected)
              ? AdminColors.accent
              : AdminColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected)
              ? AdminColors.accent.withValues(alpha: 0.35)
              : AdminColors.line;
        }),
      ),

      // Progress
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.accent,
        linearTrackColor: AdminColors.line,
      ),

      // Icons
      iconTheme: const IconThemeData(color: AdminColors.muted),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AdminColors.cardElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminColors.line),
        ),
        textStyle: GoogleFonts.manrope(fontSize: 12, color: AdminColors.ink),
      ),

      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: AdminColors.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AdminColors.line),
        ),
        textStyle: GoogleFonts.manrope(fontSize: 14, color: AdminColors.ink),
      ),

      // Dropdown menu
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AdminColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AdminColors.line),
          ),
        ),
      ),

      // Expansion tile
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AdminColors.muted,
        collapsedIconColor: AdminColors.muted,
        textColor: AdminColors.ink,
        collapsedTextColor: AdminColors.ink,
      ),
    );
  }
}
