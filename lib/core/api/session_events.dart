import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why the API ended the session.
enum SessionEnd {
  /// The tokens are no longer valid (`INVALID_REFRESH_TOKEN`, `UNAUTHENTICATED`):
  /// back to sign-in.
  signedOut,

  /// `ACCOUNT_UNAVAILABLE`: the neutral "contact support" screen (hard rule 8).
  accountUnavailable,
}

/// An event bus (like an EventEmitter or RxJS Subject): the auth interceptor
/// reports here when the API ends the session; the sign-in state (A8)
/// listens and switches screens. The API layer never knows about screens.
final sessionEventsProvider = Provider<StreamController<SessionEnd>>((ref) {
  final controller = StreamController<SessionEnd>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});
