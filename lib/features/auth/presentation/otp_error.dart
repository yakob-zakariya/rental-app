import '../../../core/api/api_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'phone_entry_error.dart';

/// The message the code screen shows for [error] (hard rule 3).
String otpErrorMessage(ApiError error, AppLocalizations l10n) {
  return switch (error.code) {
    ApiErrorCode.otpInvalid => switch (error.attemptsRemaining) {
      final int attempts => l10n.otpWrongCodeAttemptsLeft(attempts),
      null => l10n.otpWrongCode,
    },
    ApiErrorCode.otpExpired => l10n.otpExpiredOrUsed,
    ApiErrorCode.otpAttemptsExceeded => l10n.otpAttemptsExceeded,
    // Neutral, never a reason (hard rule 8).
    ApiErrorCode.accountUnavailable => l10n.accountUnavailableMessage,
    // The same messages as on phone entry (also used for "Send a new code").
    _ => phoneEntryErrorMessage(error, l10n),
  };
}

/// Errors after which this code can't work any more: offer a new one at once.
bool otpErrorNeedsNewCode(ApiError error) =>
    error.code == ApiErrorCode.otpExpired ||
    error.code == ApiErrorCode.otpAttemptsExceeded;
