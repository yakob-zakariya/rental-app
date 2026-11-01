import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in misc.dart in Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/app/router.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/features/verification/presentation/verification_flow.dart';

import '../../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockVerificationRepository extends Mock
    implements VerificationRepository {}

class MockVerificationFlow extends Mock implements VerificationFlow {}

const testTokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

VerificationSummary summaryOf(
  VerificationStatus status, {
  bool canRetry = false,
  bool canRequestManualReview = false,
  String? reasonCode,
}) => VerificationSummary(
  status: status,
  canRetry: canRetry,
  retriesLeftToday: canRetry ? 2 : 0,
  canRequestManualReview: canRequestManualReview,
  reasonCode: reasonCode,
);

/// The app, signed in, on Home showing [homeStatus] (Home's status comes from
/// the provider override, so [repository] calls are only the screen's own).
Future<void> pumpSignedIn(
  WidgetTester tester, {
  required MockVerificationRepository repository,
  required MockVerificationFlow flow,
  VerificationSummary? homeStatus,
  List<Override> overrides = const [],
}) async {
  final auth = MockAuthRepository();
  when(() => auth.checkSession()).thenAnswer((_) async {});
  await tester.pumpRentalApp(
    brightness: brightnessVariant.currentValue ?? Brightness.light,
    storedTokens: testTokens,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      verificationRepositoryProvider.overrideWithValue(repository),
      verificationFlowProvider.overrideWithValue(flow),
      verificationStatusProvider.overrideWith(
        (ref) async =>
            homeStatus ??
            summaryOf(VerificationStatus.notVerified, canRetry: true),
      ),
      ...overrides,
    ],
  );
}

/// Pushes [location] from Home, as a button would.
Future<void> pushFromHome(WidgetTester tester, String location) async {
  // push() completes only when the pushed screen closes: don't wait for it.
  unawaited(
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .push(location),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // the page transition
}
