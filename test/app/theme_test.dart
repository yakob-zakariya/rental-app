import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/design_tokens.dart';
import 'package:rental_app/app/theme.dart';

/// WCAG contrast ratio between two opaque colours (1:1 … 21:1).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (light, dark) = la > lb ? (la, lb) : (lb, la);
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  final themes = {'light': buildLightTheme(), 'dark': buildDarkTheme()};

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group('$name theme', () {
      final c = theme.colorScheme;

      test('has the right brightness', () {
        expect(
          c.brightness,
          name == 'light' ? Brightness.light : Brightness.dark,
        );
      });

      // WCAG AA: at least 4.5:1 for normal text.
      final pairs = {
        'onPrimary on primary': (c.onPrimary, c.primary),
        'onSurface on surface': (c.onSurface, c.surface),
        'onSurfaceVariant on surface': (c.onSurfaceVariant, c.surface),
        'onSurface on card (surfaceContainerLow)': (
          c.onSurface,
          c.surfaceContainerLow,
        ),
        'onPrimaryContainer on primaryContainer': (
          c.onPrimaryContainer,
          c.primaryContainer,
        ),
        'onError on error': (c.onError, c.error),
        'primary (text buttons) on surface': (c.primary, c.surface),
      };
      for (final MapEntry(key: pair, value: (fg, bg)) in pairs.entries) {
        test('meets WCAG AA contrast: $pair', () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }

      test('uses the bundled fonts, with Ethiopic as fallback', () {
        final body = theme.textTheme.bodyLarge!;
        expect(body.fontFamily, appFontFamily);
        expect(body.fontFamilyFallback, appFontFamilyFallback);
      });

      test('cards are flat with a 16 px radius', () {
        final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
        expect(theme.cardTheme.elevation, 0);
      });

      test('main buttons are at least 52 px tall', () {
        for (final style in [
          theme.filledButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
        ]) {
          final size = style.minimumSize!.resolve({})!;
          expect(size.height, AppTapTarget.mainButton);
        }
      });

      test('text buttons are at least 48 × 48', () {
        final size = theme.textButtonTheme.style!.minimumSize!.resolve({})!;
        expect(size, const Size(AppTapTarget.min, AppTapTarget.min));
      });
    });
  }

  test('both themes come from the same seed (same hue family)', () {
    final light = HSLColor.fromColor(buildLightTheme().colorScheme.primary);
    final dark = HSLColor.fromColor(buildDarkTheme().colorScheme.primary);
    expect((light.hue - dark.hue).abs(), lessThan(15));
  });
}
