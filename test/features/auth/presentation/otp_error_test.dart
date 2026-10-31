import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/auth/presentation/otp_error.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  String message(String code, {int? attemptsRemaining, int? retryAfter}) =>
      otpErrorMessage(
        ApiError(
          code,
          attemptsRemaining: attemptsRemaining,
          retryAfterSeconds: retryAfter,
        ),
        l10n,
      );

  group('OTP_INVALID', () {
    test('shows the attempts left (plural)', () {
      expect(
        message('OTP_INVALID', attemptsRemaining: 3),
        'Wrong code. 3 attempts left.',
      );
      expect(
        message('OTP_INVALID', attemptsRemaining: 1),
        'Wrong code. 1 attempt left.',
      );
      expect(
        message('OTP_INVALID', attemptsRemaining: 0),
        'Wrong code. No attempts left.',
      );
    });

    test('without attemptsRemaining', () {
      expect(message('OTP_INVALID'), 'Wrong code. Please try again.');
    });
  });

  test('OTP_EXPIRED', () {
    expect(
      message('OTP_EXPIRED'),
      'This code has expired or was already used.',
    );
  });

  test('OTP_ATTEMPTS_EXCEEDED', () {
    expect(message('OTP_ATTEMPTS_EXCEEDED'), 'Too many wrong attempts.');
  });

  test('ACCOUNT_UNAVAILABLE is neutral (no reason)', () {
    expect(
      message('ACCOUNT_UNAVAILABLE'),
      'This account is unavailable. Please contact support.',
    );
  });

  test('falls back to the phone entry messages', () {
    expect(
      message('RATE_LIMITED', retryAfter: 120),
      'Too many attempts. Try again in 2 minutes.',
    );
    expect(
      message(ApiErrorCode.networkError),
      'No connection. Check your internet and try again.',
    );
    expect(message('SOMETHING_NEW'), 'Something went wrong. Please try again.');
  });

  test('only OTP_EXPIRED and OTP_ATTEMPTS_EXCEEDED need a new code', () {
    expect(otpErrorNeedsNewCode(const ApiError('OTP_EXPIRED')), isTrue);
    expect(
      otpErrorNeedsNewCode(const ApiError('OTP_ATTEMPTS_EXCEEDED')),
      isTrue,
    );
    expect(otpErrorNeedsNewCode(const ApiError('OTP_INVALID')), isFalse);
    expect(
      otpErrorNeedsNewCode(const ApiError(ApiErrorCode.networkError)),
      isFalse,
    );
  });
}
