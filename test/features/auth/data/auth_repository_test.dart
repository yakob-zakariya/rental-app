import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_client.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/dio_factory.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter network;
  late AuthRepository repository;

  setUp(() {
    network = FakeHttpAdapter();
    final dio = createDio(AppConfig.parse('http://localhost:3000'))
      ..httpClientAdapter = network;
    repository = AuthRepository(ApiClient(dio));
  });

  group('requestOtp', () {
    test(
      'posts the phone as typed (trimmed) and returns expiresInSeconds',
      () async {
        network.reply(200, json: {'expiresInSeconds': 300});

        final expires = await repository.requestOtp('  0911 234 567 ');

        expect(expires, 300);
        final request = network.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/auth/otp/request');
        expect(request.data, {'phone': '0911 234 567'});
      },
    );

    for (final body in [
      <String, Object?>{},
      {'expiresInSeconds': '300'},
      {'expiresInSeconds': 0},
    ]) {
      test(
        'a 200 without a valid expiresInSeconds ($body) → UNKNOWN_ERROR',
        () async {
          network.reply(200, json: body);

          await expectLater(
            repository.requestOtp('0911234567'),
            throwsA(
              isA<ApiError>().having(
                (e) => e.code,
                'code',
                ApiErrorCode.unknownError,
              ),
            ),
          );
        },
      );
    }

    test('passes API errors through', () async {
      network.reply(400, json: {'code': 'INVALID_PHONE'});

      await expectLater(
        repository.requestOtp('123'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'INVALID_PHONE')),
      );
    });
  });

  group('verifyOtp', () {
    test('posts phone, code and deviceName, and returns the tokens', () async {
      network.reply(
        200,
        json: {
          'accessToken': 'eyJaccess',
          'refreshToken': 'eyJrefresh',
          'accessTokenExpiresIn': 900,
        },
      );

      final tokens = await repository.verifyOtp(
        phone: '0911 234 567',
        code: '123456',
        deviceName: 'Samsung SM-M156B',
      );

      expect(tokens.accessToken, 'eyJaccess');
      expect(tokens.refreshToken, 'eyJrefresh');
      final request = network.requests.single;
      expect(request.path, '/auth/otp/verify');
      expect(request.data, {
        'phone': '0911 234 567',
        'code': '123456',
        'deviceName': 'Samsung SM-M156B',
      });
    });

    test('leaves deviceName out when unknown', () async {
      network.reply(200, json: {'accessToken': 'a', 'refreshToken': 'r'});

      await repository.verifyOtp(phone: '0911234567', code: '123456');

      expect(network.requests.single.data, {
        'phone': '0911234567',
        'code': '123456',
      });
    });

    for (final body in [
      <String, Object?>{},
      {'accessToken': 'a'},
      {'accessToken': '', 'refreshToken': 'r'},
      {'accessToken': 1, 'refreshToken': 'r'},
    ]) {
      test('a 200 without a token pair ($body) → UNKNOWN_ERROR', () async {
        network.reply(200, json: body);

        await expectLater(
          repository.verifyOtp(phone: '0911234567', code: '123456'),
          throwsA(
            isA<ApiError>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.unknownError,
            ),
          ),
        );
      });
    }

    test('passes API errors through (with attemptsRemaining)', () async {
      network.reply(400, json: {'code': 'OTP_INVALID', 'attemptsRemaining': 2});

      await expectLater(
        repository.verifyOtp(phone: '0911234567', code: '000000'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'OTP_INVALID')
              .having((e) => e.attemptsRemaining, 'attemptsRemaining', 2),
        ),
      );
    });
  });
}
