import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_provider.dart';
import 'api_client.dart';
import 'dio_factory.dart';

/// The app's one [Dio] instance. A5 adds the auth interceptor here.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(appConfigProvider));
  ref.onDispose(dio.close);
  return dio;
});

/// What repositories use to call the API.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
