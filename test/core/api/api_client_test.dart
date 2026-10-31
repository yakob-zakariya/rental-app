import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_client.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/dio_factory.dart';
import 'package:rental_app/core/config/app_config.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  /// An ApiClient on a real Dio (as the app builds it) with a fake network.
  ApiClient clientFor(String baseUrl) {
    final dio = createDio(AppConfig.parse(baseUrl));
    dio.httpClientAdapter = adapter;
    return ApiClient(dio);
  }

  setUp(() => adapter = FakeHttpAdapter());

  test('returns the JSON object of a successful response', () async {
    adapter.reply(200, json: {'expiresInSeconds': 300});
    final client = clientFor('http://localhost:3000');

    final body = await client.post(
      '/auth/otp/request',
      body: {'phone': '0911 234 567'},
    );

    expect(body, {'expiresInSeconds': 300});
  });

  test('returns an empty map for 204 No Content', () async {
    adapter.reply(204);
    final client = clientFor('http://localhost:3000');

    expect(
      await client.post('/auth/logout', body: {'refreshToken': 'x'}),
      <String, Object?>{},
    );
  });

  test('sends requests to the base URL as JSON', () async {
    adapter.reply(200, json: {'id': '1'});
    final client = clientFor('http://localhost:3000');

    await client.patch('/me', body: {'preferredLanguage': 'en'});

    final request = adapter.requests.single;
    expect(request.uri.toString(), 'http://localhost:3000/me');
    expect(request.method, 'PATCH');
    expect(request.contentType, Headers.jsonContentType);
    expect(request.headers[Headers.acceptHeader], Headers.jsonContentType);
    expect(request.data, {'preferredLanguage': 'en'});
    expect(request.connectTimeout, apiTimeout);
    expect(request.receiveTimeout, apiTimeout);
  });

  test('turns an error body with a code into an ApiError', () async {
    adapter.reply(400, json: {'code': 'OTP_INVALID', 'attemptsRemaining': 3});
    final client = clientFor('http://localhost:3000');

    await expectLater(
      client.post('/auth/otp/verify', body: {'code': '000000'}),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.attemptsRemaining, 'attemptsRemaining', 3),
      ),
    );
  });

  test('reads Retry-After from a 429', () async {
    adapter.reply(
      429,
      json: {'code': 'RATE_LIMITED'},
      headers: {
        'retry-after': ['120'],
      },
    );
    final client = clientFor('http://localhost:3000');

    await expectLater(
      client.post('/auth/otp/request', body: {'phone': '0911234567'}),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.rateLimited)
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 120),
      ),
    );
  });

  test('turns a timeout into NETWORK_ERROR', () async {
    adapter.fail(
      (options) => DioException.receiveTimeout(
        timeout: apiTimeout,
        requestOptions: options,
      ),
    );
    final client = clientFor('http://localhost:3000');

    await expectLater(
      client.get('/me'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.networkError)
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });

  test('turns an HTML error page into UNKNOWN_ERROR', () async {
    adapter.reply(
      502,
      text: '<html>Bad gateway</html>',
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
    final client = clientFor('http://localhost:3000');

    await expectLater(
      client.get('/me'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.unknownError)
            .having((e) => e.statusCode, 'statusCode', 502),
      ),
    );
  });

  group('ngrok header', () {
    for (final url in [
      'https://abc.ngrok-free.dev',
      'https://abc.ngrok-free.app',
      'https://ABC.NGROK-FREE.DEV',
    ]) {
      test('is sent for $url', () async {
        adapter.reply(200, json: {});
        await clientFor(url).get('/health');

        expect(
          adapter.requests.single.headers['ngrok-skip-browser-warning'],
          'true',
        );
      });
    }

    for (final url in [
      'http://localhost:3000',
      'https://api.example.com',
      'https://ngrok-free.dev.example.com',
    ]) {
      test('is not sent for $url', () async {
        adapter.reply(200, json: {});
        await clientFor(url).get('/health');

        expect(
          adapter.requests.single.headers.containsKey(
            'ngrok-skip-browser-warning',
          ),
          isFalse,
        );
      });
    }
  });
}
