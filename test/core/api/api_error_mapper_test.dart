import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/api_error_mapper.dart';

final _options = RequestOptions(path: '/test');

/// A non-2xx response, as dio reports it.
DioException _badResponse(
  int statusCode, {
  Object? data,
  Map<String, List<String>> headers = const {},
}) {
  return DioException.badResponse(
    statusCode: statusCode,
    requestOptions: _options,
    response: Response<Object?>(
      requestOptions: _options,
      statusCode: statusCode,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );
}

void main() {
  group('error responses', () {
    // Every code and status from the error table in docs/api-for-mobile.md.
    const contract = {
      'VALIDATION_FAILED': 400,
      'INVALID_PHONE': 400,
      'OTP_INVALID': 400,
      'OTP_EXPIRED': 400,
      'OTP_ATTEMPTS_EXCEEDED': 400,
      'OTP_RATE_LIMITED': 429,
      'RATE_LIMITED': 429,
      'SMS_SEND_FAILED': 503,
      'UNAUTHENTICATED': 401,
      'ACCESS_TOKEN_EXPIRED': 401,
      'INVALID_REFRESH_TOKEN': 401,
      'ACCOUNT_UNAVAILABLE': 403,
      'ALREADY_VERIFIED': 409,
      'VERIFICATION_IN_REVIEW': 409,
      'VERIFICATION_UNAVAILABLE': 403,
      'VERIFICATION_RETRY_LIMIT': 429,
      'VERIFICATION_PROVIDER_UNAVAILABLE': 503,
      'MANUAL_REVIEW_NOT_AVAILABLE': 409,
    };

    test('ApiErrorCode.fromApi lists exactly the contract codes', () {
      expect(ApiErrorCode.fromApi.toSet(), contract.keys.toSet());
    });

    for (final MapEntry(key: code, value: status) in contract.entries) {
      test('$code ($status) keeps its code and status', () {
        final error = apiErrorFromDioException(
          _badResponse(status, data: {'code': code}),
        );

        expect(error.code, code);
        expect(error.statusCode, status);
        expect(error.isNetworkError, isFalse);
      });
    }

    test('an unknown code is kept as-is', () {
      final error = apiErrorFromDioException(
        _badResponse(400, data: {'code': 'SOMETHING_NEW'}),
      );

      expect(error.code, 'SOMETHING_NEW');
      expect(error.statusCode, 400);
    });

    test('a non-JSON body (e.g. an ngrok error page) → UNKNOWN_ERROR', () {
      final error = apiErrorFromDioException(
        _badResponse(502, data: '<html>Bad gateway</html>'),
      );

      expect(error.code, ApiErrorCode.unknownError);
      expect(error.statusCode, 502);
    });

    test('an empty body → UNKNOWN_ERROR', () {
      final error = apiErrorFromDioException(_badResponse(500));

      expect(error.code, ApiErrorCode.unknownError);
      expect(error.statusCode, 500);
    });

    test('JSON without a usable code → UNKNOWN_ERROR', () {
      for (final body in [
        <String, Object?>{},
        {'code': ''},
        {'code': 42},
        {'message': 'Internal server error'},
      ]) {
        final error = apiErrorFromDioException(_badResponse(500, data: body));
        expect(error.code, ApiErrorCode.unknownError, reason: '$body');
      }
    });
  });

  group('retryAfterSeconds', () {
    test('is read from the body', () {
      final error = apiErrorFromDioException(
        _badResponse(
          429,
          data: {'code': 'OTP_RATE_LIMITED', 'retryAfterSeconds': 420},
        ),
      );

      expect(error.retryAfterSeconds, 420);
    });

    test('falls back to the Retry-After header', () {
      final error = apiErrorFromDioException(
        _badResponse(
          429,
          data: {'code': 'RATE_LIMITED'},
          headers: {
            'retry-after': ['60'],
          },
        ),
      );

      expect(error.retryAfterSeconds, 60);
    });

    test('the body wins over the header', () {
      final error = apiErrorFromDioException(
        _badResponse(
          429,
          data: {'code': 'VERIFICATION_RETRY_LIMIT', 'retryAfterSeconds': 3600},
          headers: {
            'retry-after': ['60'],
          },
        ),
      );

      expect(error.retryAfterSeconds, 3600);
    });

    test('is read from the header even without a JSON body', () {
      final error = apiErrorFromDioException(
        _badResponse(
          429,
          data: 'Too Many Requests',
          headers: {
            'retry-after': ['30'],
          },
        ),
      );

      expect(error.code, ApiErrorCode.unknownError);
      expect(error.retryAfterSeconds, 30);
    });

    test('ignores unusable values', () {
      final error = apiErrorFromDioException(
        _badResponse(
          429,
          data: {'code': 'RATE_LIMITED', 'retryAfterSeconds': 'soon'},
          headers: {
            // HTTP-date form: the API never sends it, so it's ignored.
            'retry-after': ['Wed, 21 Oct 2026 07:28:00 GMT'],
          },
        ),
      );

      expect(error.retryAfterSeconds, isNull);
    });

    test('is null when absent', () {
      final error = apiErrorFromDioException(
        _badResponse(400, data: {'code': 'INVALID_PHONE'}),
      );

      expect(error.retryAfterSeconds, isNull);
    });
  });

  group('extra fields', () {
    test('attemptsRemaining (OTP_INVALID)', () {
      final error = apiErrorFromDioException(
        _badResponse(
          400,
          data: {'code': 'OTP_INVALID', 'attemptsRemaining': 3},
        ),
      );

      expect(error.attemptsRemaining, 3);
    });

    test('attemptsRemaining of 0 is kept', () {
      final error = apiErrorFromDioException(
        _badResponse(
          400,
          data: {'code': 'OTP_INVALID', 'attemptsRemaining': 0},
        ),
      );

      expect(error.attemptsRemaining, 0);
    });

    test('manualReviewAvailable (VERIFICATION_RETRY_LIMIT)', () {
      final error = apiErrorFromDioException(
        _badResponse(
          429,
          data: {
            'code': 'VERIFICATION_RETRY_LIMIT',
            'manualReviewAvailable': true,
            'retryAfterSeconds': 5000,
          },
        ),
      );

      expect(error.manualReviewAvailable, isTrue);
      expect(error.retryAfterSeconds, 5000);
    });

    test('wrongly typed extra fields are ignored', () {
      final error = apiErrorFromDioException(
        _badResponse(
          400,
          data: {
            'code': 'OTP_INVALID',
            'attemptsRemaining': '3',
            'manualReviewAvailable': 'yes',
          },
        ),
      );

      expect(error.code, 'OTP_INVALID');
      expect(error.attemptsRemaining, isNull);
      expect(error.manualReviewAvailable, isNull);
    });
  });

  group('no response', () {
    const timeout = Duration(seconds: 20);
    final networkFailures = {
      'connection timeout': DioException.connectionTimeout(
        timeout: timeout,
        requestOptions: _options,
      ),
      'send timeout': DioException.sendTimeout(
        timeout: timeout,
        requestOptions: _options,
      ),
      'receive timeout': DioException.receiveTimeout(
        timeout: timeout,
        requestOptions: _options,
      ),
      'transform timeout': DioException.transformTimeout(
        timeout: timeout,
        requestOptions: _options,
      ),
      'connection error': DioException.connectionError(
        requestOptions: _options,
        reason: 'Connection refused',
      ),
      'bad certificate': DioException.badCertificate(requestOptions: _options),
    };

    for (final MapEntry(key: name, value: exception)
        in networkFailures.entries) {
      test('$name → NETWORK_ERROR', () {
        final error = apiErrorFromDioException(exception);

        expect(error.code, ApiErrorCode.networkError);
        expect(error.isNetworkError, isTrue);
        expect(error.statusCode, isNull);
      });
    }

    test('a cancelled request → UNKNOWN_ERROR', () {
      final error = apiErrorFromDioException(
        DioException.requestCancelled(requestOptions: _options, reason: null),
      );

      expect(error.code, ApiErrorCode.unknownError);
    });

    test('an unknown failure → UNKNOWN_ERROR', () {
      final error = apiErrorFromDioException(
        DioException(requestOptions: _options, error: StateError('boom')),
      );

      expect(error.code, ApiErrorCode.unknownError);
    });
  });
}
