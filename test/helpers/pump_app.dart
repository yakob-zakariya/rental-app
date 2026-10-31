import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the type of a provider override) lives in misc.dart in Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/app.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/core/config/app_config_provider.dart';
import 'package:rental_app/l10n/generated/app_localizations.dart';

/// The config tests use unless they pass their own.
final testConfig = AppConfig.parse('http://localhost:3000');

extension PumpApp on WidgetTester {
  /// Pumps the whole app (router included) with test overrides.
  Future<void> pumpRentalApp({
    AppConfig? config,
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config ?? testConfig),
          ...overrides,
        ],
        child: const RentalApp(),
      ),
    );
    await pumpAndSettle();
  }

  /// Pumps a single screen with translations and providers, without the router.
  Future<void> pumpScreen(
    Widget screen, {
    AppConfig? config,
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config ?? testConfig),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await pumpAndSettle();
  }
}
