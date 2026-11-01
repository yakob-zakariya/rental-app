import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_client.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/dio_factory.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/features/profile/data/profile_repository.dart';
import 'package:rental_app/features/profile/data/user_profile.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';

import '../../../helpers/fake_http_adapter.dart';

Map<String, Object?> meJson([Map<String, Object?> changes = const {}]) => {
  'id': '9a1f0905-0000-0000-0000-000000000000',
  'phone': '+251911234567',
  'fullName': 'Abebe Kebede',
  'dateOfBirth': '1995-03-01',
  'preferredLanguage': 'am',
  'verificationStatus': 'approved',
  'verifiedAt': '2026-10-31T09:12:33.123Z',
  'createdAt': '2026-10-30T08:00:00.000Z',
  ...changes,
};

void main() {
  group('UserProfile.fromJson', () {
    test('reads every field', () {
      final me = UserProfile.fromJson(meJson());

      expect(me.id, startsWith('9a1f0905'));
      expect(me.phone, '+251911234567');
      expect(me.fullName, 'Abebe Kebede');
      expect(me.preferredLanguage, 'am');
      expect(me.verificationStatus, VerificationStatus.approved);
      expect(me.verifiedAt, DateTime.utc(2026, 10, 31, 9, 12, 33, 123));
      expect(me.createdAt.isUtc, isTrue);
    });

    test('keeps the date of birth exactly as received (a string)', () {
      expect(UserProfile.fromJson(meJson()).dateOfBirth, '1995-03-01');
    });

    test('a new user: name, date of birth and verifiedAt are null', () {
      final me = UserProfile.fromJson(
        meJson({
          'fullName': null,
          'dateOfBirth': null,
          'verifiedAt': null,
          'verificationStatus': 'not_verified',
        }),
      );

      expect(me.fullName, isNull);
      expect(me.dateOfBirth, isNull);
      expect(me.verifiedAt, isNull);
    });

    for (final (name, changes) in [
      ('id missing', {'id': null}),
      ('createdAt missing', {'createdAt': null}),
      ('fullName as a number', {'fullName': 1}),
      ('verifiedAt not a date', {'verifiedAt': 'yesterday'}),
    ]) {
      test('rejects $name', () {
        expect(
          () => UserProfile.fromJson(meJson(changes)),
          throwsFormatException,
        );
      });
    }

    test('toString never contains identity data', () {
      final text = UserProfile.fromJson(meJson()).toString();
      expect(text, isNot(contains('Abebe')));
      expect(text, isNot(contains('1995')));
      expect(text, isNot(contains('+2519')));
    });
  });

  group('ProfileRepository.getMe', () {
    late FakeHttpAdapter network;
    late ProfileRepository repository;

    setUp(() {
      network = FakeHttpAdapter();
      final dio = createDio(AppConfig.parse('http://localhost:3000'))
        ..httpClientAdapter = network;
      repository = ProfileRepository(ApiClient(dio));
    });

    test('GETs /me', () async {
      network.reply(200, json: meJson());

      final me = await repository.getMe();

      expect(network.requests.single.path, '/me');
      expect(me.fullName, 'Abebe Kebede');
    });

    test('a wrongly shaped body → UNKNOWN_ERROR', () async {
      network.reply(200, json: {'id': 'x'});

      await expectLater(
        repository.getMe(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.unknownError,
          ),
        ),
      );
    });

    test('updateLanguage PATCHes only preferredLanguage and returns the '
        'updated profile', () async {
      network.reply(200, json: meJson({'preferredLanguage': 'en'}));

      final me = await repository.updateLanguage('en');

      final request = network.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/me');
      expect(request.data, {'preferredLanguage': 'en'});
      expect(me.preferredLanguage, 'en');
    });

    test('updateLanguage passes API errors through', () async {
      network.reply(400, json: {'code': 'VALIDATION_FAILED'});

      await expectLater(
        repository.updateLanguage('xx'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'VALIDATION_FAILED'),
        ),
      );
    });
  });
}
