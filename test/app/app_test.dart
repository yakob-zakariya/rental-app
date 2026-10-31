import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/config_error_app.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../helpers/pump_app.dart';

void main() {
  // The English strings, straight from the generated class (so tests break
  // if a screen hard-codes text instead of using the ARB file).
  final l10n = AppLocalizationsEn();

  group('RentalApp', () {
    // Every test in this group runs twice: phone in light mode, then dark.
    testWidgets('opens on sign-in, showing the base URL in debug', (
      tester,
    ) async {
      await tester.pumpRentalApp(brightness: brightnessVariant.currentValue!);

      expect(find.text(l10n.signInTitle), findsOneWidget);
      // Tests run in debug mode, so the base URL is visible.
      expect(find.text('http://localhost:3000'), findsOneWidget);
    }, variant: brightnessVariant);

    testWidgets('follows the phone\'s light/dark setting', (tester) async {
      final brightness = brightnessVariant.currentValue!;
      await tester.pumpRentalApp(brightness: brightness);

      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, brightness);
    }, variant: brightnessVariant);

    testWidgets('takes its title from the ARB file', (tester) async {
      await tester.pumpRentalApp();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final context = tester.element(find.byType(Scaffold));
      expect(app.onGenerateTitle!(context), l10n.appTitle);
    });
  });

  testWidgets('ConfigErrorApp shows the error and how to fix it', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue =
        brightnessVariant.currentValue!;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      const ConfigErrorApp(message: 'API_BASE_URL is missing.'),
    );

    expect(find.text('Configuration error'), findsOneWidget);
    expect(find.text('API_BASE_URL is missing.'), findsOneWidget);
    expect(find.text('adb reverse tcp:3000 tcp:3000'), findsOneWidget);
    expect(
      find.text('flutter run --dart-define=API_BASE_URL=http://localhost:3000'),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }, variant: brightnessVariant);
}
