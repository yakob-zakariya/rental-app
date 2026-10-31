/// App configuration that is baked in at build time with `--dart-define`.
///
/// Run the app with, for example:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// The rental-api base URL, e.g. `http://localhost:3000`.
  final Uri apiBaseUrl;

  /// The raw value passed with `--dart-define=API_BASE_URL=...`.
  ///
  /// `String.fromEnvironment` is evaluated at compile time, so it must be a
  /// `const`. If the define is missing, the value is an empty string.
  static const String _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Reads the config compiled into this build.
  static AppConfig fromEnvironment() => parse(_rawApiBaseUrl);

  /// Validates [rawApiBaseUrl] and builds an [AppConfig].
  ///
  /// Throws an [AppConfigException] if the value is empty or isn't an
  /// absolute `http`/`https` URL with a host.
  static AppConfig parse(String rawApiBaseUrl) {
    final value = rawApiBaseUrl.trim();
    if (value.isEmpty) {
      throw const AppConfigException('API_BASE_URL is missing.');
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw AppConfigException(
        'API_BASE_URL must be an http:// or https:// URL with a host, '
        'got "$value".',
      );
    }

    return AppConfig(apiBaseUrl: uri);
  }
}

/// Thrown when the build-time configuration is missing or invalid.
class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}
