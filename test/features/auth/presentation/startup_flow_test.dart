import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/api/session_events.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Home loads the verification status; these tests only need a quiet answer.
class FakeVerificationRepository extends Fake
    implements VerificationRepository {
  @override
  Future<VerificationSummary> getStatus() async => const VerificationSummary(
    status: VerificationStatus.notVerified,
    canRetry: true,
    retriesLeftToday: 3,
    canRequestManualReview: false,
  );
}

const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

/// Startup routing (spec 3.1) and the account-unavailable screen (spec 3.8),
/// through the whole app: router, controller and screens together.
void main() {
  final l10n = AppLocalizationsEn();
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  Future<void> pump(
    WidgetTester tester, {
    AuthTokens? storedTokens,
    bool settle = true,
  }) => tester.pumpRentalApp(
    brightness: brightnessVariant.currentValue!,
    storedTokens: storedTokens,
    settle: settle,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      verificationRepositoryProvider.overrideWithValue(
        FakeVerificationRepository(),
      ),
    ],
  );

  testWidgets('without tokens: phone entry', (tester) async {
    await pump(tester);

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    verifyNever(() => auth.checkSession());
  }, variant: brightnessVariant);

  testWidgets('with tokens: the splash while checking, then home (still '
      'signed in after reopening the app)', (tester) async {
    final check = Completer<void>();
    when(() => auth.checkSession()).thenAnswer((_) => check.future);
    await pump(tester, storedTokens: _tokens, settle: false);
    await tester.pump();

    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.splashLoading), findsOneWidget);

    check.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeTitle), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('offline at startup: "Can\'t connect" and Retry, never '
      'signed out', (tester) async {
    when(
      () => auth.checkSession(),
    ).thenAnswer((_) async => throw const ApiError(ApiErrorCode.networkError));
    await pump(tester, storedTokens: _tokens);

    expect(find.text(l10n.splashCantConnect), findsOneWidget);
    expect(find.text(l10n.phoneEntryHeadline), findsNothing);
    await expectAccessible(tester);

    when(() => auth.checkSession()).thenAnswer((_) async {});
    await tester.tap(find.widgetWithText(FilledButton, l10n.splashRetry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.homeTitle), findsOneWidget);
  }, variant: brightnessVariant);

  testWidgets('another startup error: the generic text and Retry', (
    tester,
  ) async {
    when(() => auth.checkSession()).thenAnswer(
      (_) async =>
          throw const ApiError(ApiErrorCode.unknownError, statusCode: 500),
    );
    await pump(tester, storedTokens: _tokens);

    expect(find.text(l10n.errorGeneric), findsOneWidget);
    expect(find.text(l10n.splashRetry), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('expired session at startup: phone entry', (tester) async {
    when(() => auth.checkSession()).thenAnswer(
      (_) async =>
          throw const ApiError('INVALID_REFRESH_TOKEN', statusCode: 401),
    );
    await pump(tester, storedTokens: _tokens);

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
  }, variant: brightnessVariant);

  group('account unavailable', () {
    testWidgets('at startup: only the neutral text and "Back to sign in"', (
      tester,
    ) async {
      when(() => auth.checkSession()).thenAnswer(
        (_) async =>
            throw const ApiError('ACCOUNT_UNAVAILABLE', statusCode: 403),
      );
      await pump(tester, storedTokens: _tokens);

      expect(find.text(l10n.accountUnavailableMessage), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      await expectAccessible(tester);

      await tester.tap(find.text(l10n.accountUnavailableBackToSignIn));
      await tester.pumpAndSettle();
      expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    }, variant: brightnessVariant);

    testWidgets('during use (a request gets ACCOUNT_UNAVAILABLE): the '
        'neutral screen at once', (tester) async {
      when(() => auth.checkSession()).thenAnswer((_) async {});
      await pump(tester, storedTokens: _tokens);
      expect(find.text(l10n.homeTitle), findsOneWidget);

      // What the auth interceptor does when any request is refused.
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
          .read(sessionEventsProvider)
          .add(SessionEnd.accountUnavailable);
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountUnavailableMessage), findsOneWidget);
    }, variant: brightnessVariant);
  });

  testWidgets('session ended during use (signedOut event): phone entry', (
    tester,
  ) async {
    when(() => auth.checkSession()).thenAnswer((_) async {});
    await pump(tester, storedTokens: _tokens);

    ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
        .read(sessionEventsProvider)
        .add(SessionEnd.signedOut);
    await tester.pumpAndSettle();

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
  }, variant: brightnessVariant);
}
