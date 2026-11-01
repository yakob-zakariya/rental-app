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
  });
}
