import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config_error_app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_config_provider.dart';

/// The entry point, like `main.ts` in NestJS: it runs once when the app starts.
void main() {
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppConfigException catch (e) {
    // Refuse to start the real app without a valid API_BASE_URL.
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  // `ProviderScope` holds every Riverpod provider (like the root NestJS module).
  // `runApp` puts the root widget on the screen.
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const RentalApp(),
    ),
  );
}
