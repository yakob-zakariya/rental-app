import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/api/api_client.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/dio_factory.dart';
import 'package:rental_app/core/api/session_events.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/core/storage/storage_providers.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/features/auth/presentation/auth_controller.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

void main() {
  late MockAuthRepository auth;
  late TokenStorage storage;

  setUp(() {
    auth = MockAuthRepository();
    storage = TokenStorage(const FlutterSecureStorage());
  });

  /// Riverpod without any UI: a container holding the providers.
  ProviderContainer makeContainer({AuthRepository? repository}) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository ?? auth),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Starts the controller and waits for the startup check to finish.
  Future<AuthState> start(ProviderContainer container) async {
    container.read(authControllerProvider);
    await pumpEventQueue();
    return container.read(authControllerProvider);
  }

  AuthController controllerOf(ProviderContainer c) =>
      c.read(authControllerProvider.notifier);

  group('startup', () {
    test('starts in checking', () {
      useInMemorySecureStorage();
      final container = makeContainer();

      expect(
        container.read(authControllerProvider),
        const AuthState(AuthStatus.checking),
      );
    });

    test('no tokens → signed out, without calling the API', () async {
      useInMemorySecureStorage();

      final state = await start(makeContainer());

      expect(state.status, AuthStatus.signedOut);
      verifyNever(() => auth.checkSession());
    });

    test('tokens and GET /me OK → signed in', () async {
      useInMemorySecureStorage(tokens: _tokens);
      when(() => auth.checkSession()).thenAnswer((_) async {});

      final state = await start(makeContainer());

      expect(state.status, AuthStatus.signedIn);
      verify(() => auth.checkSession()).called(1);
    });

    test('ACCOUNT_UNAVAILABLE → account unavailable', () async {
      useInMemorySecureStorage(tokens: _tokens);
      when(() => auth.checkSession()).thenAnswer(
        (_) async =>
            throw const ApiError('ACCOUNT_UNAVAILABLE', statusCode: 403),
      );

      final state = await start(makeContainer());

      expect(state.status, AuthStatus.accountUnavailable);
    });

    for (final code in ['UNAUTHENTICATED', 'INVALID_REFRESH_TOKEN']) {
      test('$code → signed out', () async {
        useInMemorySecureStorage(tokens: _tokens);
        when(() => auth.checkSession())
            .thenAnswer((_) async => throw ApiError(code, statusCode: 401));

        final state = await start(makeContainer());

        expect(state.status, AuthStatus.signedOut);
      });
    }

    test('NETWORK_ERROR → Retry on the splash; tokens kept', () async {
      useInMemorySecureStorage(tokens: _tokens);
      when(() => auth.checkSession()).thenAnswer(
        (_) async => throw const ApiError(ApiErrorCode.networkError),
      );

      final state = await start(makeContainer());

      expect(
        state,
        const AuthState(
          AuthStatus.checking,
          startupError: StartupError.network,
        ),
      );
      expect((await storage.read())?.refreshToken, _tokens.refreshToken);
    });

    for (final (name, error) in [
      ('a 500', const ApiError(ApiErrorCode.unknownError, statusCode: 500)),
      ('a 429', const ApiError('RATE_LIMITED', statusCode: 429)),
      (
        'ACCESS_TOKEN_EXPIRED after the retry',
        const ApiError('ACCESS_TOKEN_EXPIRED', statusCode: 401),
      ),
    ]) {
      test('$name → Retry with the generic text; tokens kept', () async {
        useInMemorySecureStorage(tokens: _tokens);
        when(() => auth.checkSession()).thenAnswer((_) async => throw error);

        final state = await start(makeContainer());

        expect(
          state,
          const AuthState(
            AuthStatus.checking,
            startupError: StartupError.other,
          ),
        );
        expect((await storage.read())?.refreshToken, _tokens.refreshToken);
      });
    }

    test('Retry runs the check again', () async {
      useInMemorySecureStorage(tokens: _tokens);
      when(() => auth.checkSession()).thenAnswer(
        (_) async => throw const ApiError(ApiErrorCode.networkError),
      );
      final container = makeContainer();
      await start(container);

      when(() => auth.checkSession()).thenAnswer((_) async {});
      final retry = controllerOf(container).retryStartup();
      // Back to the spinner while it checks.
      expect(
        container.read(authControllerProvider),
        const AuthState(AuthStatus.checking),
      );
      await retry;

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedIn,
      );
    });
  });

  group('session events (from the auth interceptor)', () {
    Future<ProviderContainer> signedInContainer() async {
      useInMemorySecureStorage(tokens: _tokens);
      when(() => auth.checkSession()).thenAnswer((_) async {});
      final container = makeContainer();
      await start(container);
      return container;
    }

    test('signedOut → signed out', () async {
      final container = await signedInContainer();

      container.read(sessionEventsProvider).add(SessionEnd.signedOut);
      await pumpEventQueue();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    });

    test('accountUnavailable → account unavailable, and a later signedOut '
        'does not replace it', () async {
      final container = await signedInContainer();
      final events = container.read(sessionEventsProvider);

      events.add(SessionEnd.accountUnavailable);
      await pumpEventQueue();
      // e.g. a parallel request, now sent without a token, gets 401.
      events.add(SessionEnd.signedOut);
      await pumpEventQueue();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.accountUnavailable,
      );
    });
  });

  group('actions', () {
    test('signedIn()', () async {
      useInMemorySecureStorage();
      final container = makeContainer();
      await start(container);

      controllerOf(container).signedIn();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedIn,
      );
    });

    test('showAccountUnavailable() and backToSignIn()', () async {
      useInMemorySecureStorage();
      final container = makeContainer();
      await start(container);

      controllerOf(container).showAccountUnavailable();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.accountUnavailable,
      );

      await controllerOf(container).backToSignIn();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    });

    test('signOut() clears the tokens and signs out at once, even if '
        'logout fails', () async {
      useInMemorySecureStorage(tokens: _tokens);
      when(() => auth.checkSession()).thenAnswer((_) async {});
      final logoutResponse = Completer<void>();
      when(() => auth.logout(any())).thenAnswer((_) => logoutResponse.future);
      final container = makeContainer();
      await start(container);

      await controllerOf(container).signOut();

      // Done before logout has even answered.
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await storage.read(), isNull);

      logoutResponse.completeError(const ApiError(ApiErrorCode.networkError));
      await pumpEventQueue(); // the failure is ignored (no unhandled error)
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    });

    test('the logout request carries the old refresh token, although '
        'storage is already empty when it is sent', () async {
      useInMemorySecureStorage(tokens: _tokens);
      // The real repository on a fake network, to see the actual request.
      final network = FakeHttpAdapter();
      final dio = createDio(AppConfig.parse('http://localhost:3000'))
        ..httpClientAdapter = network;
      AuthTokens? storedWhenLogoutSent = _tokens;
      network.handler = (RequestOptions options) async {
        if (options.path == '/auth/logout') {
          storedWhenLogoutSent = await storage.read();
          return ResponseBody.fromString('', 204);
        }
        return FakeHttpAdapter.json(200, {'id': 'user-1'}); // GET /me
      };
      final container = makeContainer(
        repository: AuthRepository(ApiClient(dio)),
      );
      await start(container);

      await controllerOf(container).signOut();
      await pumpEventQueue();

      final logout = network.requests.singleWhere(
        (r) => r.path == '/auth/logout',
      );
      expect(logout.data, {'refreshToken': _tokens.refreshToken});
      expect(storedWhenLogoutSent, isNull);
    });

    test('signOut() when nothing is stored sends no logout', () async {
      useInMemorySecureStorage();
      final container = makeContainer();
      await start(container);

      await controllerOf(container).signOut();
      await pumpEventQueue();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      verifyNever(() => auth.logout(any()));
    });
  });
}
