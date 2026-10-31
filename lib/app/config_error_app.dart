import 'package:flutter/material.dart';

import 'theme.dart';

/// Shown instead of the app when `API_BASE_URL` is missing or invalid.
///
/// This is a developer-facing screen: a correctly built app never shows it.
/// Its text is intentionally hard-coded English, because it can appear before
/// the app itself (and its translations) is set up.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuration error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 16),
                const Text('Connect the phone by USB and start the app with:'),
                const SizedBox(height: 8),
                const SelectableText(
                  'adb reverse tcp:3000 tcp:3000',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                const SelectableText(
                  'flutter run --dart-define=API_BASE_URL=http://localhost:3000',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
