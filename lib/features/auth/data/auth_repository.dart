import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/storage/auth_tokens.dart';

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

  /// `POST /auth/otp/verify`: checks the SMS code. The first successful
  /// verify creates the account. Returns the token pair (not yet stored).
  ///
  /// [phone] must be the same text as for [requestOtp]. [deviceName] is
  /// optional and left out when unknown.
  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    String? deviceName,
  }) async {
    final body = await _api.post(
      '/auth/otp/verify',
      body: {
        'phone': phone.trim(),
        'code': code,
        // `?` adds the entry only when deviceName isn't null.
        'deviceName': ?deviceName,
      },
    );
    final access = body['accessToken'];
    final refresh = body['refreshToken'];
    if (access is String &&
        access.isNotEmpty &&
        refresh is String &&
        refresh.isNotEmpty) {
      return AuthTokens(accessToken: access, refreshToken: refresh);
    }
    throw const ApiError(ApiErrorCode.unknownError, statusCode: 200);
  }

  /// `GET /me`, used at startup to check the stored tokens (the profile
  /// itself is used from A9 on). Throws an [ApiError] when they don't work.
  Future<void> checkSession() => _api.get('/me');

  /// `POST /auth/logout` (public, always 204): revokes [refreshToken] on the
  /// server.
  Future<void> logout(String refreshToken) =>
      _api.post('/auth/logout', body: {'refreshToken': refreshToken});
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
