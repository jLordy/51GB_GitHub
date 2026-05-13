import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeData>((
  ref,
) {
  return ThemeNotifier();
});

class Palette {
  // ---------------------------------------------------------------------------
  // Clinical color constants
  // Names are intentionally semantic so call-sites read as intent, not hex.
  // ---------------------------------------------------------------------------

  // Primary action color — clinical green conveys health and positive
  // outcomes; familiar to users of medical platforms.
  static const greenColor = Color(0xFF359361);

  // Light green container for interactive states (hover, focused rings).
  static const primaryContainerColor = Color(0xFFC8F0D8);

  // Secondary accent — a slightly deeper green for supplementary actions
  // such as "Continue as Guest" or informational chips.
  static const secondaryColor = Color(0xFF2A7A50);
  static const secondaryContainerColor = Color(0xFFB6E8CC);

  // Clinical alert red — high contrast, WCAG AA compliant against white.
  // Used exclusively for error states and critical clinical alerts.
  static const errorColor = Color(0xFFD62828);
  static const errorContainerColor = Color(0xFFFFDAD6);

  // ── Light mode surfaces ────────────────────────────────────────────────────
  // Pure clinical white for the main scaffold — reduces cognitive load.
  static const lightSurfaceColor = Color(0xFFFFFFFF);

  // Slightly off-white container: separates patient data cards from the
  // scaffold background without introducing visual noise.
  static const lightSurfaceContainerColor = Color(0xFFF0F6FA);

  // Muted slate for body copy; softer than pure black to reduce eye strain
  // during extended clinical sessions.
  static const lightOnSurfaceColor = Color(0xFF191A19);
  static const lightOnSurfaceVariantColor = Color(0xFF4A6070);

  // Outline used for form borders and dividers — light enough to stay
  // unobtrusive but visible at WCAG AA contrast against white.
  static const lightOutlineColor = Color.fromARGB(255, 65, 69, 65);

  // ── Dark mode surfaces — elevation-based hierarchy ──────────────────────────
  // Layer 0: deepest scaffold — deep navy-slate background.
  static const darkSurfaceColor = Color(0xFF1E2938);

  // Layer 1: +1 elevation for cards/drawers — navy step above the scaffold.
  static const darkSurfaceContainerColor = Color(0xFF253244);

  // Layer 2: +2 elevation for inputs and interactive wells — a clearly
  // distinguishable step above cards, signalling affordance.
  static const darkInputSurfaceColor = Color(0xFF2E3D52);

  // High-emphasis text: #E6E1E1 — warm near-white for dark surfaces.
  static const darkOnSurfaceColor = Color(0xFFE6E1E1);

  // Medium-emphasis text: ~60% white (alpha 153) — labels, captions, and
  // secondary info; clearly subordinate to primary text without disappearing.
  static const darkOnSurfaceVariantColor = Color(0x99FFFFFF);

  // Subtle outline: navy-toned border, delineates without competing with content.
  static const darkOutlineColor = Color(0xFF3A4A5C);

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------
  static ThemeData get lightModeAppTheme {
    const scheme = ColorScheme.light(
      // Primary green drives all interactive elements: buttons,
      // focused borders, FABs, and progress indicators.
      primary: greenColor,
      onPrimary: lightSurfaceColor,
      primaryContainer: Color.fromARGB(255, 210, 239, 222),
      onPrimaryContainer: Color(0xFF002112),

      secondary: secondaryColor,
      onSecondary: lightSurfaceColor,
      secondaryContainer: secondaryContainerColor,
      onSecondaryContainer: Color(0xFF001A0D),

      // errorColor maps to clinical alert states (validation, auth failures).
      error: errorColor,
      onError: lightSurfaceColor,
      errorContainer: errorContainerColor,
      onErrorContainer: Color(0xFF410002),

      // surface / onSurface drive scaffold, cards, and default text.
      surface: lightSurfaceColor,
      onSurface: lightOnSurfaceColor,
      onSurfaceVariant: lightOnSurfaceVariantColor,

      // surfaceContainerHighest is used for input fills and elevated cards.
      surfaceContainerHighest: Color.fromARGB(255, 254, 254, 254),

      outline: lightOutlineColor,
      outlineVariant: Color(0xFFD6E4EC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Inter is widely used in healthcare platforms for its legibility
      // at small sizes on clinical dashboards.
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      primaryTextTheme: GoogleFonts.interTextTheme(
        ThemeData.light().primaryTextTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        // Subtle bottom border replaces elevation shadow for a clean,
        // clinical look aligned with EHR system conventions.
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        // Using surfaceContainerHighest to separate patient data cards
        // from the scaffold background.
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Subtle fill distinguishes inputs from bare surface.
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          // Primary teal ring on focus signals active clinical input field.
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------
  static ThemeData get darkModeAppTheme {
    const scheme = ColorScheme.dark(
      // Same clinical green as light mode — full saturation on dark.
      primary: Color(0xFF359361),
      onPrimary: Color(0xFFE6E1E1),
      primaryContainer: Color(0xFF1A5C3A),
      onPrimaryContainer: Color(0xFFFFFFFF),

      // Secondary mirrors the desaturation strategy of primary.
      secondary: Color(0xFF85B59C),
      onSecondary: Color(0xFF003320),
      secondaryContainer: Color(0xFF1A4D33),
      onSecondaryContainer: Color(0xFFB6E8CC),

      // Error red lightened for legibility on deep green-gray surfaces.
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),

      // Layer 0 scaffold — deepest point in the elevation stack.
      surface: darkSurfaceColor,
      // ~87% white: high-emphasis; readable without pure-white glare.
      onSurface: darkOnSurfaceColor,
      // ~60% white: medium-emphasis for labels and captions.
      onSurfaceVariant: darkOnSurfaceVariantColor,

      // Layer 1 for cards — one elevation step above the scaffold.
      surfaceContainerHighest: darkSurfaceContainerColor,

      outline: darkOutlineColor,
      // Even subtler divider — hair-line separation without visual noise.
      outlineVariant: Color(0xFF252E3A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      primaryTextTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().primaryTextTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        // Layer 1: cards sit one step above the scaffold in the z-stack.
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      drawerTheme: DrawerThemeData(
        // Drawer matches card elevation — same visual tier as content panels.
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Layer 2 fill: inputs are visually elevated above cards,
        // immediately signalling they are interactive wells.
        fillColor: darkInputSurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          // Desaturated primary ring: clear focus state without chromatic buzz.
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        // ~38% white: disabled/hint text — present but clearly subordinate.
        hintStyle: const TextStyle(color: Color(0x61FFFFFF)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Layer 2 background: buttons sit on the same elevated tier as
          // inputs, reinforcing that both are interactive affordances.
          backgroundColor: darkInputSurfaceColor,
          // Desaturated primary signals clickability without over-saturating.
          foregroundColor: scheme.primary,
          minimumSize: const Size(double.infinity, 50),
          // Primary-tinted border completes the affordance signal.
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // Primary green text: consistent with outlined buttons; clearly
        // actionable against any Layer 0–2 background.
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeData> {
  ThemeMode _mode;
  ThemeNotifier({ThemeMode mode = ThemeMode.light})
    : _mode = mode,
      super(Palette.lightModeAppTheme) {
    getTheme();
  }

  ThemeMode get mode => _mode;

  void getTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme');

    if (theme == 'light') {
      _mode = ThemeMode.light;
      state = Palette.lightModeAppTheme;
    } else {
      _mode = ThemeMode.dark;
      state = Palette.darkModeAppTheme;
    }
  }

  void toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (_mode == ThemeMode.dark) {
      _mode = ThemeMode.light;
      state = Palette.lightModeAppTheme;
      prefs.setString('theme', 'light');
    } else {
      _mode = ThemeMode.dark;
      state = Palette.darkModeAppTheme;
      prefs.setString('theme', 'dark');
    }
  }
}