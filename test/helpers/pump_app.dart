import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the type of a provider override) lives in misc.dart in Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/app.dart';
import 'package:rental_app/app/theme.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/core/config/app_config_provider.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/l10n/generated/app_localizations.dart';

/// The config tests use unless they pass their own.
final testConfig = AppConfig.parse('http://localhost:3000');

/// Runs a widget test once with the phone in light mode and once in dark mode
/// (the Design rule: every screen must look right in both). Use with
/// `testWidgets(..., variant: brightnessVariant)` and read
/// `brightnessVariant.currentValue!`.
final brightnessVariant = ValueVariant<Brightness>({
  Brightness.light,
  Brightness.dark,
});

/// Replaces secure storage with an in-memory one (from flutter_secure_storage),
/// holding [tokens] if given — i.e. the app starts signed in.
void useInMemorySecureStorage({AuthTokens? tokens}) {
  FlutterSecureStorage.setMockInitialValues({
    if (tokens != null)
      TokenStorage.storageKey: jsonEncode({
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
      }),
  });
}

/// Flutter's built-in accessibility checks: 48 px tap targets (Android),
/// labelled tap targets, and WCAG AA text contrast.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

extension PumpApp on WidgetTester {
  /// Sets the phone's light/dark setting for this test (reset afterwards).
  void setBrightness(Brightness brightness) {
    platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(platformDispatcher.clearPlatformBrightnessTestValue);
  }

  /// Pumps the whole app (router included) with test overrides.
  ///
  /// Secure storage is in-memory and empty (signed out) unless
  /// [storedTokens] is given. With [settle] false, the app is left at its
  /// first frame (e.g. to see the splash while a request is pending).
  Future<void> pumpRentalApp({
    AppConfig? config,
    List<Override> overrides = const [],
    Brightness brightness = Brightness.light,
    AuthTokens? storedTokens,
    bool settle = true,
  }) async {
    setBrightness(brightness);
    useInMemorySecureStorage(tokens: storedTokens);
    await pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config ?? testConfig),
          ...overrides,
        ],
        child: const RentalApp(),
      ),
    );
    if (settle) await pumpAndSettle();
  }

  /// Pumps a single screen with translations and providers, without the router.
  Future<void> pumpScreen(
    Widget screen, {
    AppConfig? config,
    List<Override> overrides = const [],
    Brightness brightness = Brightness.light,
  }) async {
    setBrightness(brightness);
    await pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config ?? testConfig),
          ...overrides,
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await pumpAndSettle();
  }
}
