import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/theme.dart';

/// The `launch_background` colour from an Android colors.xml file.
String launchColor(String path) {
  final xml = File(path).readAsStringSync();
  final match = RegExp(
    r'<color name="launch_background">(#[0-9A-Fa-f]{6})</color>',
  ).firstMatch(xml);
  expect(match, isNotNull, reason: 'launch_background missing in $path');
  return match!.group(1)!.toUpperCase();
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Android paints the launch screen before Flutter starts, from XML. These
/// tests keep it the same colour as the app's background, so opening the app
/// shows no flash in either mode.
void main() {
  const res = 'android/app/src/main/res';

  test('light launch colour = the light theme background', () {
    expect(
      launchColor('$res/values/colors.xml'),
      hex(buildLightTheme().colorScheme.surface),
    );
  });

  test('dark launch colour = the dark theme background', () {
    expect(
      launchColor('$res/values-night/colors.xml'),
      hex(buildDarkTheme().colorScheme.surface),
    );
  });

  test('every launch theme uses the launch colour (incl. Android 12+)', () {
    for (final dir in [
      'values',
      'values-night',
      'values-v31',
      'values-night-v31',
    ]) {
      final styles = File('$res/$dir/styles.xml').readAsStringSync();
      expect(
        styles,
        contains(
          '<item name="android:windowBackground">@color/launch_background</item>',
        ),
        reason: '$dir NormalTheme',
      );
      if (dir.endsWith('v31')) {
        expect(
          styles,
          contains(
            '<item name="android:windowSplashScreenBackground">@color/launch_background</item>',
          ),
          reason: '$dir LaunchTheme',
        );
      }
    }
  });
}
