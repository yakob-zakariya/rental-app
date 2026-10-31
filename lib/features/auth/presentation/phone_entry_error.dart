import '../../../core/api/api_error.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The message the phone entry screen shows for [error] (switching on the
/// code, hard rule 3).
String phoneEntryErrorMessage(ApiError error, AppLocalizations l10n) {
  return switch (error.code) {
    ApiErrorCode.invalidPhone => l10n.errorInvalidPhone,
    ApiErrorCode.otpRateLimited || ApiErrorCode.rateLimited =>
      tooManyAttemptsMessage(error.retryAfterSeconds, l10n),
    ApiErrorCode.smsSendFailed => l10n.errorSmsSendFailed,
    ApiErrorCode.networkError => l10n.errorNetwork,
    // VALIDATION_FAILED, UNKNOWN_ERROR and codes we don't know yet.
    _ => l10n.errorGeneric,
  };
}

/// "Too many attempts. Try again in N minutes", with N rounded **up** (so
/// 30 seconds is "1 minute", never "0 minutes"), or "…later" without a time.
String tooManyAttemptsMessage(int? retryAfterSeconds, AppLocalizations l10n) {
  if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
    return l10n.errorTooManyAttemptsLater;
  }
  return l10n.errorTooManyAttemptsMinutes((retryAfterSeconds / 60).ceil());
}
