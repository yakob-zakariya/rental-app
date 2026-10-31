import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/api_providers.dart';

/// Sign-in API calls (`docs/api-for-mobile.md`, "Sign-in"). Every failure is
/// an [ApiError].
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// `POST /auth/otp/request`: asks the API to send a 6-digit code by SMS.
  ///
  /// [phone] is sent as the user typed it (trimmed): the API normalises and
  /// validates it. Returns how many seconds the code stays valid.
  Future<int> requestOtp(String phone) async {
    final body = await _api.post(
      '/auth/otp/request',
      body: {'phone': phone.trim()},
    );
    final expiresInSeconds = body['expiresInSeconds'];
    if (expiresInSeconds is int && expiresInSeconds > 0) {
      return expiresInSeconds;
    }
    // A 200 without the field: not what the contract says.
    throw const ApiError(ApiErrorCode.unknownError, statusCode: 200);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
