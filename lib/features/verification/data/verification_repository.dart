import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/no_retry.dart';
import 'verification_status.dart';

/// Identity verification API calls (`docs/api-for-mobile.md`).
class VerificationRepository {
  VerificationRepository(this._api);

  final ApiClient _api;

  /// `GET /verification/status`.
  Future<VerificationSummary> getStatus() async {
    final body = await _api.get('/verification/status');
    try {
      return VerificationSummary.fromJson(body);
    } on FormatException {
      throw const ApiError(ApiErrorCode.unknownError, statusCode: 200);
    }
  }

  /// `POST /verification/sessions` (no body): starts a session, or returns
  /// the open one (a resume doesn't use a retry).
  Future<VerificationSession> startSession() async {
    final body = await _api.post('/verification/sessions');
    final url = body['verificationUrl'];
    final token = body['sessionToken'];
    if (url is String && token is String && token.isNotEmpty) {
      return VerificationSession(verificationUrl: url, sessionToken: token);
    }
    throw const ApiError(ApiErrorCode.unknownError, statusCode: 201);
  }

  /// `POST /verification/manual-review-request` (no body). Returns the new
  /// status (`manual_review`).
  Future<VerificationSummary> requestManualReview() async {
    final body = await _api.post('/verification/manual-review-request');
    try {
      return VerificationSummary.fromJson(body);
    } on FormatException {
      throw const ApiError(ApiErrorCode.unknownError, statusCode: 200);
    }
  }
}

/// A Didit session from our backend. The [sessionToken] is a secret: never
/// logged (hard rule 2), and [toString] hides it.
class VerificationSession {
  const VerificationSession({
    required this.verificationUrl,
    required this.sessionToken,
  });

  /// The hosted flow (a later browser fallback; not used in Phase 1).
  final String verificationUrl;
  final String sessionToken;

  @override
  String toString() => 'VerificationSession(***)';
}

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepository(ref.watch(apiClientProvider)),
);

/// The current verification status, loaded when a screen watches it.
///
/// A `FutureProvider`'s value is an `AsyncValue`: loading, data or error.
/// `autoDispose`: forgotten when no screen uses it (e.g. after sign-out), so
/// the next account never sees the previous one's status.
final verificationStatusProvider =
    FutureProvider.autoDispose<VerificationSummary>(
      (ref) => ref.watch(verificationRepositoryProvider).getStatus(),
      retry: noAutomaticRetry,
    );
