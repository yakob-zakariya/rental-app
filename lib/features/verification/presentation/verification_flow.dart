import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../profile/data/profile_repository.dart';
import '../data/verification_repository.dart';
import '../data/verification_sdk.dart';

/// How a verification attempt ended; the screens navigate from this.
sealed class VerificationFlowResult {
  const VerificationFlowResult();
}

/// The Didit flow was completed: show "Checking…" (the backend decides).
final class OpenChecking extends VerificationFlowResult {
  const OpenChecking();
}

/// The user closed the Didit flow: back to home (it can be resumed).
final class BackHome extends VerificationFlowResult {
  const BackHome();
}

/// The Didit flow failed: home, with "Verification couldn't continue".
final class SdkFailed extends VerificationFlowResult {
  const SdkFailed();
}

/// `POST /verification/sessions` was refused; the SDK never opened.
final class StartFailed extends VerificationFlowResult {
  const StartFailed(this.error);

  final ApiError error;
}

/// Starts (or resumes) a session and runs Didit's flow — spec 3.5 steps 2–3.
/// A plain class with no UI, so every path is easy to test.
class VerificationFlow {
  VerificationFlow({
    required this._repository,
    required this._sdk,
    required this._languageCode,
  });

  final VerificationRepository _repository;
  final VerificationSdk _sdk;
  final Future<String> Function() _languageCode;

  Future<VerificationFlowResult> run() async {
    final VerificationSession session;
    try {
      session = await _repository.startSession();
    } on ApiError catch (error) {
      return StartFailed(error);
    }

    final outcome = await _sdk.start(
      session.sessionToken,
      languageCode: await _languageCode(),
    );
    return switch (outcome) {
      SdkOutcome.completed => const OpenChecking(),
      SdkOutcome.cancelled => const BackHome(),
      SdkOutcome.failed => const SdkFailed(),
    };
  }
}

final verificationFlowProvider = Provider<VerificationFlow>((ref) {
  return VerificationFlow(
    repository: ref.watch(verificationRepositoryProvider),
    sdk: ref.watch(verificationSdkProvider),
    // The user's language from /me when Didit supports it, else English.
    languageCode: () async {
      try {
        final me = await ref.read(profileRepositoryProvider).getMe();
        return diditLanguageFor(me.preferredLanguage);
      } on Object {
        return 'en';
      }
    },
  );
});
