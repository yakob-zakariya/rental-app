import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/auth/presentation/phone_entry_error.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  String message(String code, {int? retryAfterSeconds}) =>
      phoneEntryErrorMessage(
        ApiError(code, retryAfterSeconds: retryAfterSeconds),
        l10n,
      );

  test('INVALID_PHONE', () {
    expect(message('INVALID_PHONE'), 'Enter an Ethiopian mobile number.');
  });

  for (final code in ['OTP_RATE_LIMITED', 'RATE_LIMITED']) {
    group(code, () {
      test('shows whole minutes, rounded up', () {
        expect(
          message(code, retryAfterSeconds: 420),
          'Too many attempts. Try again in 7 minutes.',
        );
        expect(
          message(code, retryAfterSeconds: 61),
          'Too many attempts. Try again in 2 minutes.',
        );
      });

      test('uses the singular for one minute (never "0 minutes")', () {
        expect(
          message(code, retryAfterSeconds: 30),
          'Too many attempts. Try again in 1 minute.',
        );
        expect(
          message(code, retryAfterSeconds: 60),
          'Too many attempts. Try again in 1 minute.',
        );
      });

      test('says "later" without a time', () {
        expect(message(code), 'Too many attempts. Please try again later.');
      });
    });
  }

  test('SMS_SEND_FAILED', () {
    expect(
      message('SMS_SEND_FAILED'),
      "We couldn't send the SMS. Please try again.",
    );
  });

  test('NETWORK_ERROR', () {
    expect(
      message(ApiErrorCode.networkError),
      'No connection. Check your internet and try again.',
    );
  });

  for (final code in [
    'VALIDATION_FAILED',
    ApiErrorCode.unknownError,
    'SOMETHING_NEW',
  ]) {
    test('$code → the generic message', () {
      expect(message(code), 'Something went wrong. Please try again.');
    });
  }
}
