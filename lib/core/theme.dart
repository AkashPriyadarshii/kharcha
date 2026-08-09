import 'package:flutter/material.dart';

/// Kharcha's visual identity — a deliberate Material 3 theme, not a template.
///
/// Signature moves:
/// - Deep ink-green primary on warm paper background (₹-green, calm, Indian).
/// - Money amounts render in a condensed display weight with a tabular
///   figure style so every screen's hero is the ₹ figure.
/// - One amber accent reserved for spend-over-budget states (semantic, not
///   decorative — never used for branding).
const seed = Color(0xFF0A6B4D);

/// Money numeral style — strong condensed treatment shared by every screen.
const moneyStyle = TextStyle(
  fontFamily: 'monospace',
  fontWeight: FontWeight.w700,
  fontFeatures: [FontFeature.tabularFigures()],
);

ThemeData kharchaTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    // Light: warm paper. Dark: warm near-black (keeps the ₹-green warmth).
    surface: dark ? const Color(0xFF14120D) : const Color(0xFFFBF7EF),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? scheme.surfaceContainerHigh : const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? scheme.surfaceContainer : const Color(0xFFFFFFFF),
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF1ECE1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
  );
}

/// Same identity, dark — used when [ThemeMode] is dark/system-dark.
ThemeData kharchaDarkTheme() => kharchaTheme(brightness: Brightness.dark);

/// Small-caps section label used across dashboard/reports/budget screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
