import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/api/api_client.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/auth_interceptor.dart';
import 'package:rental_app/core/api/dio_factory.dart';
import 'package:rental_app/core/api/session_events.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';

import '../../helpers/fake_http_adapter.dart';

const _old = AuthTokens(accessToken: 'access-old', refreshToken: 'refresh-old');
const _new = AuthTokens(accessToken: 'access-new', refreshToken: 'refresh-new');

/// The pieces of one test: the real Dio + interceptor + TokenStorage, on top
/// of a fake network and the package's in-memory secure storage.
class Harness {
  Harness() {
    final config = AppConfig.parse('http://localhost:3000');
    dio = createDio(config)..httpClientAdapter = network;
    final refreshDio = createDio(config)..httpClientAdapter = network;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshDio: refreshDio,
        tokens: tokens,
        onSessionEnded: events.add,
      ),
    );
    api = ApiClient(dio);
  }

  final network = FakeHttpAdapter();
  final tokens = TokenStorage(const FlutterSecureStorage());
  final events = <SessionEnd>[];
  late final Dio dio;
  late final ApiClient api;

  List<RequestOptions> get refreshCalls =>
      network.requests.where((r) => r.path == '/auth/refresh').toList();

  /// The access token a request was sent with (null = no header).
  static String? bearer(RequestOptions r) =>
      (r.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
}

/// The API's answers: protected routes accept only [validToken]; an older
/// token gets 401 ACCESS_TOKEN_EXPIRED. The refresh is answered by [refresh].
Future<ResponseBody> Function(RequestOptions) api({
  required String validToken,
  required Future<ResponseBody> Function(RequestOptions) refresh,
}) {
  return (options) async {
    if (options.path == '/auth/refresh') return refresh(options);
    if (Harness.bearer(options) == validToken) {
      return FakeHttpAdapter.json(200, {'path': options.path});
    }
    return FakeHttpAdapter.json(401, {'code': 'ACCESS_TOKEN_EXPIRED'});
  };
}

Future<ResponseBody> Function(RequestOptions) refreshReturns(
  AuthTokens tokens, {
  Duration delay = Duration.zero,
}) {
  return (_) async {
    await Future<void>.delayed(delay);
    return FakeHttpAdapter.json(200, {
      'accessToken': tokens.accessToken,
      'refreshToken': tokens.refreshToken,
      'accessTokenExpiresIn': 900,
    });
  };
}

Future<ResponseBody> Function(RequestOptions) refreshFailsWith(
  int status,
  String code,
) {
  return (_) async => FakeHttpAdapter.json(status, {'code': code});
}

Matcher apiErrorWithCode(String code) =>
    isA<ApiError>().having((e) => e.code, 'code', code);

void main() {
  late Harness h;

  setUp(() async {
    // In-memory secure storage (provided by flutter_secure_storage for tests).
    FlutterSecureStorage.setMockInitialValues({});
    h = Harness();
    await h.tokens.write(_old);
  });

  group('Bearer header', () {
    test('is added to protected routes', () async {
      h.network.handler = api(
        validToken: _old.accessToken,
        refresh: refreshReturns(_new),
      );

      await h.api.get('/me');

      expect(Harness.bearer(h.network.requests.single), _old.accessToken);
    });

    for (final path in AuthInterceptor.publicPaths) {
      test('is not added to the public route $path', () async {
        h.network.handler = (_) async => FakeHttpAdapter.json(200, {});

        await h.api.post(path, body: {});

        expect(h.network.requests.single.headers['Authorization'], isNull);
      });
    }

    test('is left out when signed out (no tokens)', () async {
      await h.tokens.clear();
      h.network.handler = (_) async =>
          FakeHttpAdapter.json(401, {'code': 'UNAUTHENTICATED'});

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.unauthenticated)),
      );
      expect(h.network.requests.single.headers['Authorization'], isNull);
    });
  });

  group('refresh on ACCESS_TOKEN_EXPIRED', () {
    test('3 parallel requests trigger exactly one refresh, and all three '
        'succeed afterwards', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        // Slow, so all three requests are waiting while it runs.
        refresh: refreshReturns(_new, delay: const Duration(milliseconds: 50)),
      );

      final results = await Future.wait([
        h.api.get('/me'),
        h.api.get('/verification/status'),
        h.api.get('/me'),
      ]);

      expect(h.refreshCalls, hasLength(1));
      expect(results.map((r) => r['path']), [
        '/me',
        '/verification/status',
        '/me',
      ]);
      // 3 failed + 1 refresh + 3 retries with the new token.
      final retries = h.network.requests.where(
        (r) => Harness.bearer(r) == _new.accessToken,
      );
      expect(retries, hasLength(3));
      expect(h.events, isEmpty);
    });

    test('sends the refresh token and stores both new tokens', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: refreshReturns(_new),
      );

      await h.api.get('/me');

      final refresh = h.refreshCalls.single;
      expect(refresh.data, {'refreshToken': _old.refreshToken});
      expect(refresh.headers['Authorization'], isNull);
      final stored = await h.tokens.read();
      expect(stored?.accessToken, _new.accessToken);
      expect(stored?.refreshToken, _new.refreshToken);
    });

    test('retries only once: a second ACCESS_TOKEN_EXPIRED is returned, '
        'without another refresh or a sign-out', () async {
      h.network.handler = api(
        validToken: 'never-valid',
        refresh: refreshReturns(_new),
      );

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.accessTokenExpired)),
      );
      expect(h.refreshCalls, hasLength(1));
      expect(h.network.requests.where((r) => r.path == '/me'), hasLength(2));
      expect(h.events, isEmpty);
      expect((await h.tokens.read())?.accessToken, _new.accessToken);
    });

    test('a request sent with an old token after a refresh finished is '
        'retried without a second refresh', () async {
      // A request goes out with the old token...
      final gate = Completer<void>();
      var firstMe = true;
      h.network.handler = (options) async {
        if (options.path == '/auth/refresh') {
          return refreshReturns(_new)(options);
        }
        if (Harness.bearer(options) == _new.accessToken) {
          return FakeHttpAdapter.json(200, {'path': options.path});
        }
        if (options.path == '/slow' && firstMe) {
          firstMe = false;
          await gate.future; // ...and its 401 arrives late.
        }
        return FakeHttpAdapter.json(401, {'code': 'ACCESS_TOKEN_EXPIRED'});
      };

      final slow = h.api.get('/slow');
      await Future<void>.delayed(Duration.zero);
      // Meanwhile another request refreshes the tokens.
      await h.api.get('/me');
      expect(h.refreshCalls, hasLength(1));

      gate.complete();
      expect((await slow)['path'], '/slow');
      expect(h.refreshCalls, hasLength(1));
    });
  });

  group('refresh failures', () {
    test('a refresh that times out keeps both tokens and the user signed '
        'in; the requests fail with NETWORK_ERROR', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: (options) async => throw DioException.receiveTimeout(
          timeout: apiTimeout,
          requestOptions: options,
        ),
      );

      final results = await Future.wait([
        h.api.get('/me').then<Object?>((r) => r, onError: (Object e) => e),
        h.api.get('/me').then<Object?>((r) => r, onError: (Object e) => e),
      ]);

      for (final result in results) {
        expect(result, apiErrorWithCode(ApiErrorCode.networkError));
      }
      expect(h.refreshCalls, hasLength(1));
      final stored = await h.tokens.read();
      expect(stored?.accessToken, _old.accessToken);
      expect(stored?.refreshToken, _old.refreshToken);
      expect(h.events, isEmpty);
    });

    test('no connection during the refresh keeps the tokens', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'Network is unreachable',
        ),
      );

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.networkError)),
      );
      expect((await h.tokens.read())?.refreshToken, _old.refreshToken);
      expect(h.events, isEmpty);
    });

    for (final (status, code) in [
      (500, 'UNKNOWN_ERROR'),
      (503, 'SERVICE_UNAVAILABLE'),
      (429, 'RATE_LIMITED'),
    ]) {
      test(
        'a $status refresh keeps the tokens and the user signed in',
        () async {
          h.network.handler = api(
            validToken: _new.accessToken,
            refresh: refreshFailsWith(status, code),
          );

          await expectLater(h.api.get('/me'), throwsA(isA<ApiError>()));
          expect((await h.tokens.read())?.refreshToken, _old.refreshToken);
          expect(h.events, isEmpty);
        },
      );
    }

    test('a 200 refresh without a token pair keeps the tokens', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: (_) async => FakeHttpAdapter.json(200, {'unexpected': true}),
      );

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.unknownError)),
      );
      expect((await h.tokens.read())?.refreshToken, _old.refreshToken);
      expect(h.events, isEmpty);
    });

    test('INVALID_REFRESH_TOKEN clears the tokens and signs out', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: refreshFailsWith(401, 'INVALID_REFRESH_TOKEN'),
      );

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.invalidRefreshToken)),
      );
      expect(await h.tokens.read(), isNull);
      expect(h.events, [SessionEnd.signedOut]);
    });

    test('ACCOUNT_UNAVAILABLE on the refresh clears the tokens and shows '
        'the account-unavailable screen', () async {
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: refreshFailsWith(403, 'ACCOUNT_UNAVAILABLE'),
      );

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.accountUnavailable)),
      );
      expect(await h.tokens.read(), isNull);
      expect(h.events, [SessionEnd.accountUnavailable]);
    });

    test('signing out while a refresh is in flight: the new tokens are not '
        'stored', () async {
      final refreshStarted = Completer<void>();
      final finishRefresh = Completer<void>();
      h.network.handler = api(
        validToken: _new.accessToken,
        refresh: (options) async {
          refreshStarted.complete();
          await finishRefresh.future;
          return refreshReturns(_new)(options);
        },
      );

      final request = h.api
          .get('/me')
          .then<Object?>((r) => r, onError: (Object e) => e);
      await refreshStarted.future;
      await h.tokens.clear(); // the user signs out
      finishRefresh.complete();

      expect(await request, apiErrorWithCode(ApiErrorCode.accessTokenExpired));
      expect(await h.tokens.read(), isNull);
    });
  });

  group('other auth errors on protected routes', () {
    test('UNAUTHENTICATED clears the tokens and signs out', () async {
      h.network.handler = (_) async =>
          FakeHttpAdapter.json(401, {'code': 'UNAUTHENTICATED'});

      await expectLater(
        h.api.get('/me'),
        throwsA(apiErrorWithCode(ApiErrorCode.unauthenticated)),
      );
      expect(await h.tokens.read(), isNull);
      expect(h.events, [SessionEnd.signedOut]);
      expect(h.refreshCalls, isEmpty);
    });

    test('ACCOUNT_UNAVAILABLE clears the tokens and shows the neutral '
        'screen', () async {
      h.network.handler = (_) async =>
          FakeHttpAdapter.json(403, {'code': 'ACCOUNT_UNAVAILABLE'});

      await expectLater(
        h.api.get('/verification/status'),
        throwsA(apiErrorWithCode(ApiErrorCode.accountUnavailable)),
      );
      expect(await h.tokens.read(), isNull);
      expect(h.events, [SessionEnd.accountUnavailable]);
    });

    test('other errors pass through and keep the tokens', () async {
      h.network.handler = (_) async =>
          FakeHttpAdapter.json(409, {'code': 'ALREADY_VERIFIED'});

      await expectLater(
        h.api.post('/verification/sessions'),
        throwsA(apiErrorWithCode(ApiErrorCode.alreadyVerified)),
      );
      expect((await h.tokens.read())?.accessToken, _old.accessToken);
      expect(h.events, isEmpty);
    });

    test('errors on public routes are left to the screen (e.g. '
        'ACCOUNT_UNAVAILABLE on OTP verify)', () async {
      h.network.handler = (_) async =>
          FakeHttpAdapter.json(403, {'code': 'ACCOUNT_UNAVAILABLE'});

      await expectLater(
        h.api.post('/auth/otp/verify', body: {'code': '123456'}),
        throwsA(apiErrorWithCode(ApiErrorCode.accountUnavailable)),
      );
      expect(h.events, isEmpty);
    });
  });

  test('stored tokens are a single JSON value (sanity check)', () async {
    final raw = await const FlutterSecureStorage().read(
      key: TokenStorage.storageKey,
    );
    expect(jsonDecode(raw!), {
      'accessToken': _old.accessToken,
      'refreshToken': _old.refreshToken,
    });
  });
}
