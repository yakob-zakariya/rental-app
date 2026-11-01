import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/no_retry.dart';
import 'user_profile.dart';

/// The signed-in user's profile (`docs/api-for-mobile.md`, "The signed-in
/// user"). A11 adds the language preference.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// `GET /me`.
  Future<UserProfile> getMe() async {
    final body = await _api.get('/me');
    try {
      return UserProfile.fromJson(body);
    } on FormatException {
      throw const ApiError(ApiErrorCode.unknownError, statusCode: 200);
    }
  }

  /// `PATCH /me { preferredLanguage }` — the only editable field (`am`, `om`
  /// or `en`). Returns the updated profile.
  Future<UserProfile> updateLanguage(String languageCode) async {
    final body = await _api.patch(
      '/me',
      body: {'preferredLanguage': languageCode},
    );
    try {
      return UserProfile.fromJson(body);
    } on FormatException {
      throw const ApiError(ApiErrorCode.unknownError, statusCode: 200);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user's profile (forgotten when no screen uses it).
final meProvider = FutureProvider.autoDispose<UserProfile>(
  (ref) => ref.watch(profileRepositoryProvider).getMe(),
  retry: noAutomaticRetry,
);
