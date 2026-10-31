import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// The app's [AppConfig], available to every provider and widget.
///
/// It has no default: `main.dart` overrides it in the root `ProviderScope` with
/// the config read from `--dart-define` (tests override it with their own).
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in ProviderScope',
  ),
);
