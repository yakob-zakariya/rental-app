import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_client.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/dio_factory.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';

import '../../../helpers/fake_http_adapter.dart';

Map<String, Object?> statusJson([Map<String, Object?> changes = const {}]) => {
  'status': 'declined',
  'canRetry': false,
  'retriesLeftToday': 0,
  'canRequestManualReview': true,
  'retryAvailableAt': '2026-10-31T11:30:00.000Z',
  'reasonCode': 'PHOTO_UNCLEAR',
  ...changes,
};

void main() {
  group('VerificationStatus.fromApi', () {
    test('maps every contract status', () {
      expect(
        [
          'not_verified',
          'pending',
          'approved',
          'declined',
          'manual_review',
          'blocked',
        ].map(VerificationStatus.fromApi),
        [
          VerificationStatus.notVerified,
          VerificationStatus.pending,
          VerificationStatus.approved,
          VerificationStatus.declined,
          VerificationStatus.manualReview,
          VerificationStatus.blocked,
        ],
      );
    });

    test('an unknown status → unknown (never a crash)', () {
      expect(VerificationStatus.fromApi('frozen'), VerificationStatus.unknown);
      expect(VerificationStatus.fromApi(''), VerificationStatus.unknown);
    });
  });

  group('VerificationSummary.fromJson', () {
    test('reads every field; the timestamp as UTC', () {
      final s = VerificationSummary.fromJson(statusJson());

      expect(s.status, VerificationStatus.declined);
      expect(s.canRetry, isFalse);
      expect(s.retriesLeftToday, 0);
      expect(s.canRequestManualReview, isTrue);
      expect(s.retryAvailableAt, DateTime.utc(2026, 10, 31, 11, 30));
      expect(s.retryAvailableAt!.isUtc, isTrue);
      expect(s.reasonCode, 'PHOTO_UNCLEAR');
    });

    test('retryAvailableAt and reasonCode may be null or missing', () {
      final s = VerificationSummary.fromJson({
        'status': 'not_verified',
        'canRetry': true,
        'retriesLeftToday': 3,
        'canRequestManualReview': false,
        'retryAvailableAt': null,
      });

      expect(s.retryAvailableAt, isNull);
      expect(s.reasonCode, isNull);
    });

    test('keeps an unknown reasonCode as text', () {
      expect(
        VerificationSummary.fromJson(statusJson({'reasonCode': 'NEW_REASON'}))
            .reasonCode,
        'NEW_REASON',
      );
    });

    for (final (name, changes) in [
      ('status missing', {'status': null}),
      ('canRetry as a string', {'canRetry': 'yes'}),
      ('retriesLeftToday missing', {'retriesLeftToday': null}),
      ('retryAvailableAt not a date', {'retryAvailableAt': 'soon'}),
      (
        'retryAvailableAt without a time zone',
        {'retryAvailableAt': '2026-10-31T11:30:00'},
      ),
      ('reasonCode as a number', {'reasonCode': 3}),
    ]) {
      test('rejects $name', () {
        expect(
          () => VerificationSummary.fromJson(statusJson(changes)),
          throwsFormatException,
        );
      });
    }
  });

  group('VerificationRepository.getStatus', () {
    late FakeHttpAdapter network;
    late VerificationRepository repository;

    setUp(() {
      network = FakeHttpAdapter();
      final dio = createDio(AppConfig.parse('http://localhost:3000'))
        ..httpClientAdapter = network;
      repository = VerificationRepository(ApiClient(dio));
    });

    test('GETs /verification/status', () async {
      network.reply(200, json: statusJson());

      final s = await repository.getStatus();

      expect(network.requests.single.path, '/verification/status');
      expect(s.status, VerificationStatus.declined);
    });

    test('a wrongly shaped body → UNKNOWN_ERROR', () async {
      network.reply(200, json: {'status': 'approved'});

      await expectLater(
        repository.getStatus(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.unknownError,
          ),
        ),
      );
    });

    test('passes API errors through', () async {
      network.reply(403, json: {'code': 'ACCOUNT_UNAVAILABLE'});

      await expectLater(
        repository.getStatus(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'ACCOUNT_UNAVAILABLE'),
        ),
      );
    });

    test('startSession POSTs /verification/sessions without a body', () async {
      network.reply(
        201,
        json: {
          'verificationUrl': 'https://verify.didit.me/session/abc',
          'sessionToken': 'secret-session-token',
        },
      );

      final session = await repository.startSession();

      final request = network.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/verification/sessions');
      expect(request.data, isNull);
      expect(session.sessionToken, 'secret-session-token');
      // The token is a secret: never printed.
      expect(session.toString(), isNot(contains('secret')));
    });

    test('startSession: a body without a token → UNKNOWN_ERROR', () async {
      network.reply(
        201,
        json: {'verificationUrl': 'https://verify.didit.me/x'},
      );

      await expectLater(
        repository.startSession(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.unknownError,
          ),
        ),
      );
    });

    test('startSession passes VERIFICATION_RETRY_LIMIT through with its '
        'fields', () async {
      network.reply(
        429,
        json: {
          'code': 'VERIFICATION_RETRY_LIMIT',
          'manualReviewAvailable': true,
          'retryAfterSeconds': 5000,
        },
      );

      await expectLater(
        repository.startSession(),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'VERIFICATION_RETRY_LIMIT')
              .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 5000)
              .having((e) => e.manualReviewAvailable, 'manual', isTrue),
        ),
      );
    });

    test('requestManualReview POSTs and returns the new status', () async {
      network.reply(
        200,
        json: statusJson({
          'status': 'manual_review',
          'canRequestManualReview': false,
          'retryAvailableAt': null,
          'reasonCode': null,
        }),
      );

      final s = await repository.requestManualReview();

      final request = network.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/verification/manual-review-request');
      expect(request.data, isNull);
      expect(s.status, VerificationStatus.manualReview);
    });
  });
}
