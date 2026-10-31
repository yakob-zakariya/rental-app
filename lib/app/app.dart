import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

/// The root widget of the app.
///
/// A1 placeholder: shows "Hello" (and the base URL in debug builds).
/// A2 replaces this with the theme, router and translations.
class RentalApp extends StatelessWidget {
  const RentalApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Temporary placeholder text; moves to the ARB file in A2.
              const Text('Hello', style: TextStyle(fontSize: 32)),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Text(config.apiBaseUrl.toString()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
