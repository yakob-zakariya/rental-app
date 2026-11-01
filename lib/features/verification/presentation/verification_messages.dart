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
