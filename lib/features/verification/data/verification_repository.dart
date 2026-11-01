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
