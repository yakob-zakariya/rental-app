import 'package:didit_sdk/sdk_flutter.dart' as didit;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This is the only file that imports didit_sdk (with the `didit.` prefix: the
// SDK has its own `VerificationStatus`, which would clash with ours).

/// How the Didit flow ended, as far as the app cares. The SDK's own verdict
/// (`session.status`) is deliberately dropped: the backend decides (hard
/// rule 5).
enum SdkOutcome { completed, cancelled, failed }

/// Opens Didit's native verification flow. An interface, so tests can use a
/// fake (the real SDK only runs on a phone).
abstract interface class VerificationSdk {
  Future<SdkOutcome> start(String sessionToken, {required String languageCode});
}

/// The real thing: Didit's Flutter SDK.
class DiditVerificationSdk implements VerificationSdk {
  const DiditVerificationSdk();

  @override
  Future<SdkOutcome> start(
    String sessionToken, {
    required String languageCode,
  }) async {
    try {
      final result = await didit.DiditSdk.startVerification(
        sessionToken,
        config: didit.DiditConfig(
          languageCode: languageCode,
          // Hard rule 2: the SDK must not log anything.
          loggingEnabled: false,
          // Close at once when done: Didit's own final screen could say
          // "approved" before our backend has applied its checks.
          closeOnComplete: true,
        ),
      );
      return sdkOutcomeOf(result);
    } on Object {
      // A platform error (e.g. no camera): treat like a failed flow. Nothing
      // about it is shown or logged.
      return SdkOutcome.failed;
    }
  }
}

/// Maps Didit's result to ours; `session.status` and `error` are ignored.
SdkOutcome sdkOutcomeOf(didit.VerificationResult result) => switch (result) {
  didit.VerificationCompleted() => SdkOutcome.completed,
  didit.VerificationCancelled() => SdkOutcome.cancelled,
  didit.VerificationFailed() => SdkOutcome.failed,
};

/// The languages Didit's verification UI supports (docs.didit.me
/// "Supported languages" and the didit_sdk 4.9.1 README, checked
/// 2026-11-01). Neither Amharic (`am`) nor Afaan Oromoo (`om`) is among them.
const diditSupportedLanguages = {
  'sq', 'ar', 'hy', 'bn', 'bs', 'bg', 'ca', 'zh', 'zh-CN', 'zh-TW', 'hr', //
  'cs', 'da', 'nl', 'en', 'et', 'fi', 'fr', 'ka', 'de', 'el', 'he', 'hi', //
  'hu', 'id', 'it', 'ja', 'kk', 'ko', 'ky', 'lv', 'lt', 'mk', 'ms', 'mn', //
  'cnr', 'no', 'fa', 'pl', 'pt', 'pt-BR', 'ro', 'ru', 'sr', 'sk', 'sl', //
  'so', 'es', 'sv', 'th', 'tr', 'uk', 'uz', 'vi', //
};

/// The user's `preferredLanguage` when Didit supports it, else English.
/// (Today `am` and `om` both fall back to English.)
String diditLanguageFor(String? preferredLanguage) =>
    diditSupportedLanguages.contains(preferredLanguage)
    ? preferredLanguage!
    : 'en';

final verificationSdkProvider = Provider<VerificationSdk>(
  (ref) => const DiditVerificationSdk(),
);
