import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_provider.dart';
import '../storage/storage_providers.dart';
import 'api_client.dart';
import 'auth_interceptor.dart';
import 'dio_factory.dart';
import 'session_events.dart';

/// The app's main [Dio], with the auth interceptor.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = createDio(config);
  // A second Dio without the interceptor, only for POST /auth/refresh.
  final refreshDio = createDio(config);
  final sessionEvents = ref.watch(sessionEventsProvider);

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokens: ref.watch(tokenStorageProvider),
      onSessionEnded: sessionEvents.add,
    ),
  );
  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });
  return dio;
});

/// What repositories use to call the API.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
