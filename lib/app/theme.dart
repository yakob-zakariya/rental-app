import 'package:flutter/material.dart';

/// The app's one Material 3 theme (light only in Phase 1).
///
/// Many users have small or older phones, so buttons and fields are large and
/// text is slightly bigger than Material's defaults.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1B6E5A));
  final base = ThemeData(colorScheme: colorScheme);

  const buttonSize = Size(64, 52);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
