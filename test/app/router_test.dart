import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/router.dart';
import 'package:rental_app/features/auth/presentation/auth_controller.dart';

void main() {
  const checking = AuthState(AuthStatus.checking);
  const offline = AuthState(
    AuthStatus.checking,
    startupError: StartupError.network,
  );
  const signedOut = AuthState(AuthStatus.signedOut);
  const signedIn = AuthState(AuthStatus.signedIn);
  const unavailable = AuthState(AuthStatus.accountUnavailable);

  const all = [
    AppRoutes.splash,
    AppRoutes.signIn,
    AppRoutes.otp,
    AppRoutes.home,
    AppRoutes.accountUnavailable,
  ];

  /// Where each state may be; everything else is redirected to `home`.
  void expectOnly(AuthState state, Set<String> allowed, String home) {
    for (final location in all) {
      expect(
        authRedirect(state, location),
        allowed.contains(location) ? isNull : home,
        reason: '$state at $location',
      );
    }
  }

  test('checking: only the splash (with or without Retry)', () {
    expectOnly(checking, {AppRoutes.splash}, AppRoutes.splash);
    expectOnly(offline, {AppRoutes.splash}, AppRoutes.splash);
  });

  test('signed out: only phone entry and the code screen', () {
    expectOnly(signedOut, {AppRoutes.signIn, AppRoutes.otp}, AppRoutes.signIn);
  });

  test('signed in: home (and later screens), never sign-in or splash', () {
    expectOnly(signedIn, {AppRoutes.home}, AppRoutes.home);
    expect(authRedirect(signedIn, '/profile'), isNull);
  });

  test('account unavailable: only the neutral screen', () {
    expectOnly(unavailable, {
      AppRoutes.accountUnavailable,
    }, AppRoutes.accountUnavailable);
  });
}
