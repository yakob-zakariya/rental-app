import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/account_unavailable_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/home/presentation/home_screen.dart';

/// Route paths, so screens never spell them out by hand.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const otp = '/sign-in/code';
  static const home = '/home';
  static const accountUnavailable = '/account-unavailable';
}

/// Where the sign-in state allows the user to be. Returns the location to
/// redirect to, or `null` to stay. A pure function, so it's easy to test.
String? authRedirect(AuthState auth, String location) {
  final bool allowed = switch (auth.status) {
    AuthStatus.checking => location == AppRoutes.splash,
    // /sign-in and /sign-in/code.
    AuthStatus.signedOut => location.startsWith(AppRoutes.signIn),
    AuthStatus.signedIn =>
      location != AppRoutes.splash &&
          !location.startsWith(AppRoutes.signIn) &&
          location != AppRoutes.accountUnavailable,
    AuthStatus.accountUnavailable => location == AppRoutes.accountUnavailable,
  };
  if (allowed) return null;
  return switch (auth.status) {
    AuthStatus.checking => AppRoutes.splash,
    AuthStatus.signedOut => AppRoutes.signIn,
    AuthStatus.signedIn => AppRoutes.home,
    AuthStatus.accountUnavailable => AppRoutes.accountUnavailable,
  };
}

/// The app's router, created once.
///
/// Screens don't navigate after signing in or out: they change the sign-in
/// state, and the router follows. `ref.listen` (not `ref.watch`, which would
/// rebuild the router and lose the screen history) copies each new state
/// into a `ValueNotifier`; go_router re-runs `redirect` whenever it changes.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) =>
        authRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            path: 'code',
            // The phone number travels in `extra`; without it (e.g. after the
            // app restarted on this screen) start over at phone entry.
            redirect: (context, state) =>
                state.extra is OtpScreenArgs ? null : AppRoutes.signIn,
            builder: (context, state) =>
                OtpScreen(args: state.extra! as OtpScreenArgs),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountUnavailable,
        builder: (context, state) => const AccountUnavailableScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});
