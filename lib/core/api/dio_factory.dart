import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Mobile networks are slow: allow 20 seconds per phase (connect, send, receive).
const apiTimeout = Duration(seconds: 20);

/// Builds the app's one [Dio] instance for the rental-api.
///
/// There is deliberately **no log interceptor** (hard rule 2: tokens, OTP codes
/// and identity data must never be logged).
Dio createDio(AppConfig config) {
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl.toString(),
      connectTimeout: apiTimeout,
      sendTimeout: apiTimeout,
      receiveTimeout: apiTimeout,
      responseType: ResponseType.json,
      headers: {
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
        if (isNgrokHost(config.apiBaseUrl.host))
          // Otherwise ngrok's free tier may answer with a browser warning page.
          'ngrok-skip-browser-warning': 'true',
      },
    ),
  );
}

/// True for ngrok's free tunnel domains.
bool isNgrokHost(String host) {
  final h = host.toLowerCase();
  return h.endsWith('.ngrok-free.dev') || h.endsWith('.ngrok-free.app');
}
