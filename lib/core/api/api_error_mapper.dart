import 'package:dio/dio.dart';

import 'api_error.dart';

/// Turns any dio failure into an [ApiError].
///
/// A pure function (no side effects), so every case can be unit-tested.
ApiError apiErrorFromDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);

    // No (complete) response arrived: the UI shows "check your connection".
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const ApiError(ApiErrorCode.networkError);

    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return ApiError(
        ApiErrorCode.unknownError,
        statusCode: e.response?.statusCode,
      );
  }
}

ApiError _fromResponse(Response<Object?>? response) {
  final statusCode = response?.statusCode;
  final body = response?.data;

  // Error bodies are JSON objects like {"code": "OTP_INVALID", ...}. Anything
  // else (an HTML page, an empty body) has no readable code.
  if (body is! Map) {
    return ApiError(
      ApiErrorCode.unknownError,
      statusCode: statusCode,
      retryAfterSeconds: _retryAfterHeader(response),
    );
  }

  final code = body['code'];
  return ApiError(
    code is String && code.isNotEmpty ? code : ApiErrorCode.unknownError,
    statusCode: statusCode,
    // The body's value wins; the Retry-After header is the fallback.
    retryAfterSeconds:
        _positiveInt(body['retryAfterSeconds']) ?? _retryAfterHeader(response),
    attemptsRemaining: _nonNegativeInt(body['attemptsRemaining']),
    manualReviewAvailable: switch (body['manualReviewAvailable']) {
      final bool value => value,
      _ => null,
    },
  );
}

/// The `Retry-After` header in seconds (the only form the API sends).
int? _retryAfterHeader(Response<Object?>? response) {
  final value = response?.headers.value('retry-after');
  return value == null ? null : _positiveInt(int.tryParse(value.trim()));
}

int? _positiveInt(Object? value) => value is int && value > 0 ? value : null;

int? _nonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;
