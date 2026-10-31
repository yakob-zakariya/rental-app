import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/home/presentation/home_screen.dart';

/// Route paths, so screens never spell them out by hand.
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const otp = '/sign-in/code';
  static const home = '/home';
}

/// The app's router. A provider so that A8 can add a redirect that reads the
/// sign-in state from Riverpod.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.signIn,
    routes: [
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
