import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/verification/presentation/verification_messages.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('declineReasonMessage', () {
    test('every contract reason code', () {
      expect(
        declineReasonMessage('PHOTO_UNCLEAR', l10n),
        "The photo wasn't clear enough. Retake it in good light.",
      );
      expect(
        declineReasonMessage('DOCUMENT_EXPIRED', l10n),
        'Your document has expired.',
      );
      expect(
        declineReasonMessage('DOCUMENT_NOT_ACCEPTED', l10n),
        'Use your Fayda ID card or a passport.',
      );
      expect(
        declineReasonMessage('UNDERAGE', l10n),
        'You must be 18 or older.',
      );
      expect(
        declineReasonMessage('DOCUMENT_NOT_VERIFIED', l10n),
        "We couldn't verify your document. Please try again.",
      );
    });

    test('unknown or missing → the fallback', () {
      expect(declineReasonMessage('NEW_REASON', l10n), l10n.reasonFallback);
      expect(declineReasonMessage(null, l10n), l10n.reasonFallback);
    });
  });

  group('retryTimeMessage', () {
    // 2026-10-31 10:00 in Addis Ababa.
    final now = DateTime.utc(2026, 10, 31, 7);

    test('today: "after HH:mm" in Addis Ababa time', () {
      withClock(Clock.fixed(now), () {
        expect(
          retryTimeMessage(DateTime.utc(2026, 10, 31, 11, 30), l10n),
          'You can try again after 14:30.',
        );
      });
    });

    test('not today: "tomorrow after HH:mm"', () {
      withClock(Clock.fixed(now), () {
        expect(
          retryTimeMessage(DateTime.utc(2026, 11, 1, 6, 15), l10n),
          'You can try again tomorrow after 09:15.',
        );
      });
    });

    test('unknown time: "later"', () {
      expect(retryTimeMessage(null, l10n), 'You can try again later.');
    });
  });

  group('startErrorMessage', () {
    // 2026-10-31 10:00 in Addis Ababa.
    final now = DateTime.utc(2026, 10, 31, 7);

    String? message(ApiError error) =>
        withClock(Clock.fixed(now), () => startErrorMessage(error, l10n));

    test('status changes need no message (the reloaded card says it)', () {
      for (final code in [
        'ALREADY_VERIFIED',
        'VERIFICATION_IN_REVIEW',
        'VERIFICATION_UNAVAILABLE',
      ]) {
        expect(message(ApiError(code, statusCode: 409)), isNull, reason: code);
      }
    });

    test('VERIFICATION_RETRY_LIMIT uses Home\'s wording: today', () {
      // +4.5 h = 14:30 today in Addis Ababa.
      final error = const ApiError(
        'VERIFICATION_RETRY_LIMIT',
        statusCode: 429,
        retryAfterSeconds: 16200,
      );

      expect(message(error), 'You can try again after 14:30.');
      expect(
        message(error),
        withClock(
          Clock.fixed(now),
          () => retryTimeMessage(now.add(const Duration(seconds: 16200)), l10n),
        ),
      );
    });

    test('VERIFICATION_RETRY_LIMIT: tomorrow', () {
      // +23 h = 09:00 tomorrow in Addis Ababa.
      expect(
        message(
          const ApiError(
            'VERIFICATION_RETRY_LIMIT',
            statusCode: 429,
            retryAfterSeconds: 82800,
          ),
        ),
        'You can try again tomorrow after 09:00.',
      );
    });

    test('VERIFICATION_RETRY_LIMIT without a time: "later"', () {
      expect(
        message(const ApiError('VERIFICATION_RETRY_LIMIT', statusCode: 429)),
        'You can try again later.',
      );
    });

    test('VERIFICATION_PROVIDER_UNAVAILABLE', () {
      expect(
        message(
          const ApiError('VERIFICATION_PROVIDER_UNAVAILABLE', statusCode: 503),
        ),
        l10n.verifyProviderUnavailable,
      );
    });

    test('network and others', () {
      expect(
        message(const ApiError(ApiErrorCode.networkError)),
        l10n.errorNetwork,
      );
      expect(message(const ApiError('SOMETHING_NEW')), l10n.errorGeneric);
    });
  });

  group('manualReviewErrorMessage', () {
    test('status changes need no message', () {
      for (final code in [
        'MANUAL_REVIEW_NOT_AVAILABLE',
        'VERIFICATION_IN_REVIEW',
        'ALREADY_VERIFIED',
        'VERIFICATION_UNAVAILABLE',
      ]) {
        expect(
          manualReviewErrorMessage(ApiError(code, statusCode: 409), l10n),
          isNull,
          reason: code,
        );
      }
    });

    test('network and others', () {
      expect(
        manualReviewErrorMessage(
          const ApiError(ApiErrorCode.networkError),
          l10n,
        ),
        l10n.errorNetwork,
      );
      expect(
        manualReviewErrorMessage(const ApiError('SOMETHING_NEW'), l10n),
        l10n.errorGeneric,
      );
    });
  });
}
