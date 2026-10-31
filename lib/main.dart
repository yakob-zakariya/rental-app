import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/config_error_app.dart';
import 'core/config/app_config.dart';

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

  // `runApp` takes the root widget and puts it on the screen.
  runApp(RentalApp(config: config));
}
