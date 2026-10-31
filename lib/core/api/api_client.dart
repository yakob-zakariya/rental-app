import 'package:dio/dio.dart';

import 'api_error.dart';
import 'api_error_mapper.dart';

/// The only way the app talks to the rental-api.
///
/// Repositories (under `features/*/data/`) use this class; screens never use
/// it or `dio` directly. Every method returns the response's JSON object
/// (an empty map for `204 No Content`) or throws an [ApiError].
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> get(String path) =>
      _send(() => _dio.get<Object?>(path));

  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?>? body,
  }) => _send(() => _dio.post<Object?>(path, data: body));

  Future<Map<String, Object?>> patch(
    String path, {
    Map<String, Object?>? body,
  }) => _send(() => _dio.patch<Object?>(path, data: body));

  /// Runs the request and converts every failure into an [ApiError].
  ///
  /// `async`/`await` works like in JavaScript: `await` waits for the Future
  /// (≈ Promise) to finish, and a failure surfaces as a thrown exception.
  Future<Map<String, Object?>> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw apiErrorFromDioException(e);
    }

    final data = response.data;
    if (data is Map) return Map<String, Object?>.from(data);
    // 204 No Content (e.g. logout) has no body.
    if (data == null || data == '') return {};
    // A 2xx that isn't a JSON object: not something the contract ever sends.
    throw ApiError(ApiErrorCode.unknownError, statusCode: response.statusCode);
  }
}
