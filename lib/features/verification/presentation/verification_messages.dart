import 'package:clock/clock.dart';

import '../../../core/api/api_error.dart';
import '../../../core/time/addis_time.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The message for a decline `reasonCode`; unknown codes get fallback text.
String declineReasonMessage(String? reasonCode, AppLocalizations l10n) {
  return switch (reasonCode) {
    'PHOTO_UNCLEAR' => l10n.reasonPhotoUnclear,
    'DOCUMENT_EXPIRED' => l10n.reasonDocumentExpired,
    'DOCUMENT_NOT_ACCEPTED' => l10n.reasonDocumentNotAccepted,
    'UNDERAGE' => l10n.reasonUnderage,
    'DOCUMENT_NOT_VERIFIED' => l10n.reasonDocumentNotVerified,
    _ => l10n.reasonFallback,
  };
}

/// "You can try again after 14:30." / "…tomorrow after 09:15." in Addis
/// Ababa time, or "You can try again later." when the time isn't known.
String retryTimeMessage(DateTime? retryAvailableAt, AppLocalizations l10n) {
  if (retryAvailableAt == null) return l10n.verifyTryAgainLater;
  final time = formatAddisTime(retryAvailableAt);
  return isTodayInAddis(retryAvailableAt)
      ? l10n.verifyRetryAfter(time)
      : l10n.verifyRetryTomorrowAfter(time);
}

/// The message for a refused `POST /verification/sessions`, or `null` when
/// the status itself changed (approved, in review, blocked): then the
/// reloaded status card shows it.
String? startErrorMessage(ApiError error, AppLocalizations l10n) {
  return switch (error.code) {
    ApiErrorCode.alreadyVerified ||
    ApiErrorCode.verificationInReview ||
    ApiErrorCode.verificationUnavailable => null,
    // The same wording as Home's card ("after HH:mm" / "tomorrow after").
    ApiErrorCode.verificationRetryLimit => retryTimeMessage(
      switch (error.retryAfterSeconds) {
        final seconds? => clock.now().add(Duration(seconds: seconds)),
        null => null,
      },
      l10n,
    ),
    ApiErrorCode.verificationProviderUnavailable =>
      l10n.verifyProviderUnavailable,
    ApiErrorCode.networkError => l10n.errorNetwork,
    _ => l10n.errorGeneric,
  };
}

/// The message for a refused manual review request, or `null` when the
/// status changed (the reloaded card shows it).
String? manualReviewErrorMessage(ApiError error, AppLocalizations l10n) {
  return switch (error.code) {
    ApiErrorCode.manualReviewNotAvailable ||
    ApiErrorCode.verificationInReview ||
    ApiErrorCode.alreadyVerified ||
    ApiErrorCode.verificationUnavailable => null,
    ApiErrorCode.networkError => l10n.errorNetwork,
    _ => l10n.errorGeneric,
  };
}
