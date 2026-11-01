import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The one seed colour both themes are generated from: a deep teal.
const appSeedColor = Color(0xFF0B6E69);

/// Bundled fonts (assets/fonts/, declared in pubspec.yaml). Noto Sans covers
/// Latin (English, Afaan Oromoo); characters it lacks — Ethiopic script for
/// Amharic — come from the fallback.
const appFontFamily = 'NotoSans';
const appFontFamilyFallback = ['NotoSansEthiopic'];

ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

/// Calm and modern: one accent colour, flat rounded cards, large controls.
/// See the Design section in CLAUDE.md.
ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: appSeedColor,
    brightness: brightness,
  );
  final base = ThemeData(
    colorScheme: colorScheme,
    fontFamily: appFontFamily,
    fontFamilyFallback: appFontFamilyFallback,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final text = base.textTheme;

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
  );
  const mainButtonSize = Size(64, AppTapTarget.mainButton);
  const mainButtonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.sm,
  );
  final buttonText = text.labelLarge?.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  return base.copyWith(
    // A clear hierarchy: bold-ish headings, slightly larger body text for
    // small and older phones.
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: mainButtonSize,
        padding: mainButtonPadding,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: mainButtonSize,
        padding: mainButtonPadding,
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppTapTarget.min, AppTapTarget.min),
        shape: controlShape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      contentPadding: const EdgeInsets.all(AppSpacing.md),
    ),
  );
}
