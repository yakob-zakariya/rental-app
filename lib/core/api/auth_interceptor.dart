import 'package:dio/dio.dart';

import '../storage/auth_tokens.dart';
import '../storage/token_storage.dart';
import 'api_error.dart';
import 'api_error_mapper.dart';
import 'session_events.dart';

/// Adds the access token to protected requests and refreshes it when it
/// expires (hard rule 4). Like a NestJS interceptor: every request passes
/// through [onRequest] on the way out, every failure through [onError].
///
/// - `401 ACCESS_TOKEN_EXPIRED` → one shared refresh, then the request is
///   retried once with the new token.
/// - Any other 401 → tokens cleared, [SessionEnd.signedOut].
/// - `403 ACCOUNT_UNAVAILABLE` → tokens cleared, [SessionEnd.accountUnavailable].
/// - A refresh that fails for any other reason (no connection, timeout, 429,
///   5xx) keeps the tokens: the user stays signed in.
class AuthInterceptor extends Interceptor {
  /// Callers pass `dio:`, `refreshDio:`, `tokens:`, `onSessionEnded:`; recent
  /// Dart lets a named parameter fill a private field directly (`this._dio`).
  AuthInterceptor({
    required this._dio,
    required this._refreshDio,
    required this._tokens,
    required this._onSessionEnded,
  });

  /// Routes that never carry (or need) an access token.
  static const publicPaths = {
    '/auth/otp/request',
    '/auth/otp/verify',
    '/auth/refresh',
    '/auth/logout',
    '/health',
  };

  /// Marks a request that was already retried after a refresh.
  static const _retriedKey = 'auth_retried';

  /// The app's main Dio, used to retry requests (through this interceptor).
  final Dio _dio;

  /// A Dio *without* this interceptor, only for `POST /auth/refresh`: the
  /// refresh must never pass through itself.
  final Dio _refreshDio;
  final TokenStorage _tokens;
  final void Function(SessionEnd reason) _onSessionEnded;

  /// The refresh in flight, shared by every request that is waiting for it
  /// (like one shared Promise). `null` when no refresh is running.
  Future<AuthTokens?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      final tokens = await _tokens.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (_isPublic(options) || err.type != DioExceptionType.badResponse) {
      return handler.next(err);
    }

    final error = apiErrorFromDioException(err);

    if (error.code == ApiErrorCode.accessTokenExpired) {
      // Retry once only. A fresh token being rejected again is a backend
      // problem: return the error, don't sign out.
      if (options.extra[_retriedKey] == true) return handler.next(err);
      return _refreshAndRetry(err, handler);
    }

    if (error.statusCode == 401) {
      await _endSession(SessionEnd.signedOut);
    } else if (error.code == ApiErrorCode.accountUnavailable) {
      await _endSession(SessionEnd.accountUnavailable);
    }
    handler.next(err);
  }

  Future<void> _refreshAndRetry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final AuthTokens? tokens;
    try {
      tokens = await _currentOrRefreshed(_bearerOf(err.requestOptions));
    } on DioException catch (refreshError) {
      // The refresh failed: the waiting request fails with the refresh's error
      // (NETWORK_ERROR, INVALID_REFRESH_TOKEN, ...).
      return handler.reject(refreshError);
    }
    // Signed out meanwhile: nothing to retry with.
    if (tokens == null) return handler.next(err);

    final retry = err.requestOptions.copyWith(
      extra: {...err.requestOptions.extra, _retriedKey: true},
    );
    try {
      // Goes through onRequest again, which adds the new access token.
      handler.resolve(await _dio.fetch<Object?>(retry));
    } on DioException catch (retryError) {
      handler.reject(retryError);
    }
  }

  /// The tokens to retry with: the current ones if another request already
  /// refreshed them, else the result of the one shared refresh.
  Future<AuthTokens?> _currentOrRefreshed(String? usedAccessToken) async {
    final running = _refreshing;
    if (running != null) return running;

    final current = await _tokens.read();
    if (current == null) return null;
    // This request went out with an older token, and a refresh has finished
    // since: just retry with the current one.
    if (current.accessToken != usedAccessToken) return current;

    // `??=`: if another request started a refresh while we were reading
    // storage, join it instead of starting a second one.
    return _refreshing ??= _refresh(current).whenComplete(() {
      _refreshing = null;
    });
  }

  /// `POST /auth/refresh`. Returns the new pair (both stored), `null` if the
  /// user signed out meanwhile, or throws the refresh's [DioException].
  Future<AuthTokens?> _refresh(AuthTokens current) async {
    final Response<Object?> response;
    try {
      response = await _refreshDio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
    } on DioException catch (e) {
      final error = apiErrorFromDioException(e);
      if (error.statusCode == 401) {
        await _endSession(SessionEnd.signedOut);
      } else if (error.code == ApiErrorCode.accountUnavailable) {
        await _endSession(SessionEnd.accountUnavailable);
      }
      // Anything else (no connection, timeout, 429, 5xx): keep the tokens.
      rethrow;
    }

    final fresh = _parseTokens(response.data);
    if (fresh == null) {
      // A 200 that isn't a token pair: not in the contract. Keep the tokens.
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Unexpected refresh response',
      );
    }

    // If the user signed out while the refresh was in flight, don't sign
    // them back in.
    final stored = await _tokens.read();
    if (stored?.refreshToken != current.refreshToken) return null;

    // The old refresh token is now revoked: always store both (hard rule 4).
    await _tokens.write(fresh);
    return fresh;
  }

  Future<void> _endSession(SessionEnd reason) async {
    await _tokens.clear();
    _onSessionEnded(reason);
  }

  static bool _isPublic(RequestOptions options) =>
      publicPaths.contains(Uri.parse(options.path).path);

  static String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    return header is String && header.startsWith('Bearer ')
        ? header.substring('Bearer '.length)
        : null;
  }

  static AuthTokens? _parseTokens(Object? data) {
    if (data is! Map) return null;
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String || access.isEmpty) return null;
    if (refresh is! String || refresh.isEmpty) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
