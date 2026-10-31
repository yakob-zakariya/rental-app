import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/session_events.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/auth_repository.dart';

/// Where the user is in the sign-in lifecycle. The router (app/router.dart)
/// shows the matching screens.
enum AuthStatus {
  /// Startup: reading the tokens and checking them with `GET /me` (splash).
  checking,
  signedOut,
  signedIn,

  /// The neutral "contact support" screen (hard rule 8).
  accountUnavailable,
}

/// Why the startup check couldn't finish (the splash shows "Retry").
enum StartupError {
  /// No connection or a timeout.
  network,

  /// Anything else (429, 5xx, an unknown error).
  other,
}

@immutable
class AuthState {
  const AuthState(this.status, {this.startupError});

  final AuthStatus status;

  /// Set only while [status] is [AuthStatus.checking] and the check failed.
  final StartupError? startupError;

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.status == status &&
      other.startupError == startupError;

  @override
  int get hashCode => Object.hash(status, startupError);

  @override
  String toString() => 'AuthState($status, startupError: $startupError)';
}

const _checking = AuthState(AuthStatus.checking);
const _signedOut = AuthState(AuthStatus.signedOut);
const _signedIn = AuthState(AuthStatus.signedIn);
const _accountUnavailable = AuthState(AuthStatus.accountUnavailable);

/// The sign-in state, and the actions that change it.
///
/// A `Notifier` holds state and has methods to change it — like a NestJS
/// service with state. Widgets that `ref.watch(authControllerProvider)` are
/// redrawn when [state] changes; actions go through
/// `ref.read(authControllerProvider.notifier)`.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // The API can end the session at any time (A5's auth interceptor).
    final events = ref
        .read(sessionEventsProvider)
        .stream
        .listen(_onSessionEnded);
    ref.onDispose(events.cancel);

    // State can't change while build() runs, so the check starts right after.
    Future.microtask(_checkStartup);
    return _checking;
  }

  /// Spec 3.1: no tokens → signed out; tokens → `GET /me` (an expired access
  /// token is refreshed on the way by the interceptor).
  Future<void> _checkStartup() async {
    final tokens = await ref.read(tokenStorageProvider).read();
    if (!ref.mounted) return;
    if (tokens == null) {
      state = _signedOut;
      return;
    }

    try {
      await ref.read(authRepositoryProvider).checkSession();
    } on ApiError catch (error) {
      if (!ref.mounted || state.status != AuthStatus.checking) return;
      state = switch (error) {
        ApiError(code: ApiErrorCode.accountUnavailable) => _accountUnavailable,
        // A fresh token rejected again is a backend problem: don't sign out.
        ApiError(code: ApiErrorCode.accessTokenExpired) => const AuthState(
          AuthStatus.checking,
          startupError: StartupError.other,
        ),
        // UNAUTHENTICATED, INVALID_REFRESH_TOKEN: the tokens are gone.
        ApiError(statusCode: 401) => _signedOut,
        // Never sign out for these: tokens are kept, the splash offers Retry.
        ApiError(code: ApiErrorCode.networkError) => const AuthState(
          AuthStatus.checking,
          startupError: StartupError.network,
        ),
        _ => const AuthState(
          AuthStatus.checking,
          startupError: StartupError.other,
        ),
      };
      return;
    }
    // A session event may already have moved us on.
    if (ref.mounted && state.status == AuthStatus.checking) state = _signedIn;
  }

  /// "Retry" on the splash.
  Future<void> retryStartup() {
    state = _checking;
    return _checkStartup();
  }

  /// The code screen stored the tokens.
  void signedIn() => state = _signedIn;

  /// ACCOUNT_UNAVAILABLE at sign-in (no tokens were stored).
  void showAccountUnavailable() => state = _accountUnavailable;

  /// Sign out at once; tell the API in the background (failures ignored).
  Future<void> signOut() async {
    final storage = ref.read(tokenStorageProvider);
    // Read the refresh token BEFORE clearing: logout needs it afterwards.
    final tokens = await storage.read();
    await _clearTokens();
    if (!ref.mounted) return;
    state = _signedOut;

    if (tokens != null) {
      unawaited(
        ref
            .read(authRepositoryProvider)
            .logout(tokens.refreshToken)
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  /// "Back to sign in" on the account-unavailable screen.
  Future<void> backToSignIn() async {
    await _clearTokens(); // already gone; just in case
    if (ref.mounted) state = _signedOut;
  }

  void _onSessionEnded(SessionEnd reason) {
    switch (reason) {
      case SessionEnd.accountUnavailable:
        state = _accountUnavailable;
      case SessionEnd.signedOut:
        // Once the account is unavailable, later 401s (requests now sent
        // without a token) must not replace the neutral screen.
        if (state.status != AuthStatus.accountUnavailable) state = _signedOut;
    }
  }

  Future<void> _clearTokens() async {
    try {
      await ref.read(tokenStorageProvider).clear();
    } on Exception {
      // Nothing more to do; the user is shown as signed out either way.
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
