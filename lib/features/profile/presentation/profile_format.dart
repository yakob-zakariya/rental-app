import '../../../l10n/generated/app_localizations.dart';
import '../../verification/data/verification_status.dart';

/// `+251911234567` → `+251 911 234 567` (3-3-3 after the country code, the
/// way Ethiopians write `09XX XXX XXX`). Display only; anything that isn't an
/// Ethiopian E.164 number is shown as received.
String formatPhoneForDisplay(String e164) {
  final match = RegExp(r'^\+251(\d{3})(\d{3})(\d{3})$').firstMatch(e164);
  if (match == null) return e164;
  return '+251 ${match[1]} ${match[2]} ${match[3]}';
}

/// The verification status in words. Blocked stays neutral (hard rule 8).
String verificationStatusLabel(
  VerificationStatus status,
  AppLocalizations l10n,
) {
  return switch (status) {
    VerificationStatus.notVerified => l10n.statusNotVerified,
    VerificationStatus.pending => l10n.statusPending,
    VerificationStatus.approved => l10n.statusApproved,
    VerificationStatus.declined => l10n.statusDeclined,
    VerificationStatus.manualReview => l10n.statusManualReview,
    VerificationStatus.blocked => l10n.verifyBlockedBody,
    VerificationStatus.unknown => l10n.verifyUnknownBody,
  };
}

/// The languages a user can choose (`PATCH /me`), each in its own name.
List<(String code, String label)> languageChoices(AppLocalizations l10n) => [
  ('am', l10n.languageAmharic),
  ('om', l10n.languageOromo),
  ('en', l10n.languageEnglish),
];
