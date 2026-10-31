import 'package:flutter/material.dart';

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
                const Text('Start the app with, for example:'),
                const SizedBox(height: 8),
                const SelectableText(
                  'flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000',
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
