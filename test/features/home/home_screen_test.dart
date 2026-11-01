import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/features/profile/data/profile_repository.dart';
import 'package:rental_app/features/profile/data/user_profile.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/features/verification/presentation/verification_flow.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockVerificationRepository extends Mock
    implements VerificationRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockVerificationFlow extends Mock implements VerificationFlow {}

const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

const _notVerified = VerificationSummary(
  status: VerificationStatus.notVerified,
  canRetry: true,
  retriesLeftToday: 3,
  canRequestManualReview: false,
);

void main() {
  final l10n = AppLocalizationsEn();
  late MockAuthRepository auth;
  late MockVerificationRepository verification;
  late MockProfileRepository profile;
  late MockVerificationFlow flow;

  setUp(() {
    auth = MockAuthRepository();
    verification = MockVerificationRepository();
    profile = MockProfileRepository();
    flow = MockVerificationFlow();
    when(() => auth.checkSession()).thenAnswer((_) async {});
    when(() => auth.logout(any())).thenAnswer((_) async {});
  });

  Future<void> pumpHome(WidgetTester tester, {bool settle = true}) =>
      tester.pumpRentalApp(
        brightness: brightnessVariant.currentValue ?? Brightness.light,
        storedTokens: _tokens,
        settle: settle,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          verificationRepositoryProvider.overrideWithValue(verification),
          profileRepositoryProvider.overrideWithValue(profile),
          verificationFlowProvider.overrideWithValue(flow),
        ],
      );

  void statusReturns(VerificationSummary summary) =>
      when(() => verification.getStatus()).thenAnswer((_) async => summary);

  testWidgets('loads the status: a loading card, then the status card', (
    tester,
  ) async {
    final response = Completer<VerificationSummary>();
    when(() => verification.getStatus()).thenAnswer((_) => response.future);
    await pumpHome(tester, settle: false);
    // Splash → (session OK) → home.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text(l10n.homeTitle), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.homeLoadingStatus), findsOneWidget);

    response.complete(_notVerified);
    await tester.pumpAndSettle();
    expect(find.text(l10n.verifyNotVerifiedTitle), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('a failed first load shows the full error and Retry', (
    tester,
  ) async {
    when(
      () => verification.getStatus(),
    ).thenAnswer((_) async => throw const ApiError(ApiErrorCode.networkError));
    await pumpHome(tester);

    expect(find.text(l10n.errorNetwork), findsOneWidget);
    await expectAccessible(tester);

    statusReturns(_notVerified);
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.verifyNotVerifiedTitle), findsOneWidget);
  }, variant: brightnessVariant);

  testWidgets('a failed first load with another error: the generic text', (
    tester,
  ) async {
    when(() => verification.getStatus()).thenAnswer(
      (_) async =>
          throw const ApiError(ApiErrorCode.unknownError, statusCode: 500),
    );
    await pumpHome(tester);

    expect(find.text(l10n.errorGeneric), findsOneWidget);
  }, variant: brightnessVariant);

  testWidgets('pull-to-refresh loads the status again', (tester) async {
    statusReturns(_notVerified);
    await pumpHome(tester);
    verify(() => verification.getStatus()).called(1);

    // The server says: approved now.
    statusReturns(
      const VerificationSummary(
        status: VerificationStatus.approved,
        canRetry: false,
        retriesLeftToday: 3,
        canRequestManualReview: false,
      ),
    );
    when(() => profile.getMe()).thenAnswer(
      (_) async => UserProfile(
        id: 'u1',
        phone: '+251911234567',
        fullName: 'Abebe Kebede',
        dateOfBirth: '1995-03-01',
        preferredLanguage: 'am',
        verificationStatus: VerificationStatus.approved,
        createdAt: DateTime.utc(2026),
      ),
    );
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(() => verification.getStatus()).called(1);
    expect(find.text(l10n.verifyApprovedAs('Abebe Kebede')), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('returning to the foreground loads the status again', (
    tester,
  ) async {
    statusReturns(_notVerified);
    await pumpHome(tester);
    verify(() => verification.getStatus()).called(1);

    // The user leaves the app (e.g. to the Didit flow) and comes back,
    // through the same steps Android takes.
    for (final step in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(step);
    }
    await tester.pumpAndSettle();

    verify(() => verification.getStatus()).called(1);
  });

  group('a failed reload keeps the last card and shows a SnackBar', () {
    Future<void> pullToRefresh(WidgetTester tester) async {
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
    }

    testWidgets('pull-to-refresh without a connection', (tester) async {
      statusReturns(_notVerified);
      await pumpHome(tester);

      when(() => verification.getStatus()).thenAnswer(
        (_) async => throw const ApiError(ApiErrorCode.networkError),
      );
      await pullToRefresh(tester);

      expect(find.text(l10n.verifyNotVerifiedTitle), findsOneWidget);
      expect(find.text(l10n.homeRefreshFailedOffline), findsOneWidget);
      // Not the full error state (that's only for the first load).
      expect(find.text(l10n.commonRetry), findsNothing);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('pull-to-refresh with another error: the generic text', (
      tester,
    ) async {
      statusReturns(_notVerified);
      await pumpHome(tester);

      when(() => verification.getStatus()).thenAnswer(
        (_) async =>
            throw const ApiError(ApiErrorCode.unknownError, statusCode: 500),
      );
      await pullToRefresh(tester);

      expect(find.text(l10n.verifyNotVerifiedTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l10n.errorGeneric),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.commonRetry), findsNothing);
    }, variant: brightnessVariant);

    testWidgets('returning to the foreground without a connection', (
      tester,
    ) async {
      statusReturns(_notVerified);
      await pumpHome(tester);

      when(() => verification.getStatus()).thenAnswer(
        (_) async => throw const ApiError(ApiErrorCode.networkError),
      );
      for (final step in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(step);
      }
      await tester.pumpAndSettle();

      expect(find.text(l10n.verifyNotVerifiedTitle), findsOneWidget);
      expect(find.text(l10n.homeRefreshFailedOffline), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsNothing);
    });

    testWidgets('a later successful reload shows the new status', (
      tester,
    ) async {
      statusReturns(_notVerified);
      await pumpHome(tester);
      when(() => verification.getStatus()).thenAnswer(
        (_) async => throw const ApiError(ApiErrorCode.networkError),
      );
      await pullToRefresh(tester);

      statusReturns(
        const VerificationSummary(
          status: VerificationStatus.pending,
          canRetry: true,
          retriesLeftToday: 2,
          canRequestManualReview: false,
        ),
      );
      await pullToRefresh(tester);

      expect(find.text(l10n.verifyPendingTitle), findsOneWidget);
    });
  });

  testWidgets('when retryAvailableAt passes, the status is loaded again', (
    tester,
  ) async {
    statusReturns(
      VerificationSummary(
        status: VerificationStatus.declined,
        canRetry: false,
        retriesLeftToday: 0,
        canRequestManualReview: false,
        retryAvailableAt: clock.now().add(const Duration(hours: 1)),
        reasonCode: 'DOCUMENT_NOT_VERIFIED',
      ),
    );
    await pumpHome(tester);
    expect(find.text(l10n.verifyTryAgainButton), findsNothing);

    // An hour later the API allows a new try.
    statusReturns(
      const VerificationSummary(
        status: VerificationStatus.declined,
        canRetry: true,
        retriesLeftToday: 1,
        canRequestManualReview: false,
        reasonCode: 'DOCUMENT_NOT_VERIFIED',
      ),
    );
    await tester.pump(const Duration(minutes: 59));
    verify(() => verification.getStatus()).called(1); // not yet
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();

    verify(() => verification.getStatus()).called(1);
    expect(find.text(l10n.verifyTryAgainButton), findsOneWidget);
  });

  testWidgets('menu → Sign out: phone entry, tokens cleared, logout sent '
      'with the refresh token', (tester) async {
    statusReturns(_notVerified);
    await pumpHome(tester);

    await tester.tap(find.byTooltip(l10n.homeMenuTooltip));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await tester.tap(find.text(l10n.homeSignOut));
    await tester.pumpAndSettle();

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    expect(await TokenStorage(const FlutterSecureStorage()).read(), isNull);
    verify(() => auth.logout(_tokens.refreshToken)).called(1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeTitle), findsNothing);
  }, variant: brightnessVariant);

  group('card actions', () {
    const pendingResumable = VerificationSummary(
      status: VerificationStatus.pending,
      canRetry: true,
      retriesLeftToday: 2,
      canRequestManualReview: false,
    );
    const declinedReviewable = VerificationSummary(
      status: VerificationStatus.declined,
      canRetry: false,
      retriesLeftToday: 0,
      canRequestManualReview: true,
      reasonCode: 'DOCUMENT_NOT_VERIFIED',
    );

    testWidgets('"Verify my identity" opens the consent screen', (
      tester,
    ) async {
      statusReturns(_notVerified);
      await pumpHome(tester);

      await tester.tap(find.text(l10n.verifyNotVerifiedButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.consentTitle), findsOneWidget);
      verifyNever(() => flow.run());
    });

    testWidgets('"Continue verification" resumes without the consent '
        'screen, with a spinner; completed → Checking', (tester) async {
      statusReturns(pendingResumable);
      final result = Completer<VerificationFlowResult>();
      when(() => flow.run()).thenAnswer((_) => result.future);
      await pumpHome(tester);

      await tester.tap(find.text(l10n.verifyContinueButton));
      await tester.pump();
      expect(find.bySemanticsLabel(l10n.verifyBusy), findsOneWidget);
      expect(find.text(l10n.consentTitle), findsNothing);
      // A second tap does nothing while it runs.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      result.complete(const OpenChecking());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.checkingTitle), findsOneWidget);
      verify(() => flow.run()).called(1);
    }, variant: brightnessVariant);

    testWidgets('"Continue verification" failing in Didit: a SnackBar', (
      tester,
    ) async {
      statusReturns(pendingResumable);
      when(() => flow.run()).thenAnswer((_) async => const SdkFailed());
      await pumpHome(tester);

      await tester.tap(find.text(l10n.verifyContinueButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.verifyFailedMessage), findsOneWidget);
      expect(find.text(l10n.verifyPendingTitle), findsOneWidget);
    });

    testWidgets('"Continue verification" refused (provider down): a '
        'SnackBar', (tester) async {
      statusReturns(pendingResumable);
      when(() => flow.run()).thenAnswer(
        (_) async => const StartFailed(
          ApiError('VERIFICATION_PROVIDER_UNAVAILABLE', statusCode: 503),
        ),
      );
      await pumpHome(tester);

      await tester.tap(find.text(l10n.verifyContinueButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.verifyProviderUnavailable), findsOneWidget);
    });

    testWidgets('manual review: confirm → request sent → status reloaded', (
      tester,
    ) async {
      statusReturns(declinedReviewable);
      final response = Completer<VerificationSummary>();
      when(() => verification.requestManualReview())
          .thenAnswer((_) => response.future);
      await pumpHome(tester);
      verify(() => verification.getStatus()).called(1);

      await tester.tap(find.text(l10n.verifyManualReviewButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.manualReviewDialogTitle), findsOneWidget);
      await expectAccessible(tester);
      await tester.tap(find.text(l10n.manualReviewDialogConfirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel(l10n.verifyBusy), findsOneWidget);

      statusReturns(
        const VerificationSummary(
          status: VerificationStatus.manualReview,
          canRetry: false,
          retriesLeftToday: 0,
          canRequestManualReview: false,
        ),
      );
      response.complete(
        const VerificationSummary(
          status: VerificationStatus.manualReview,
          canRetry: false,
          retriesLeftToday: 0,
          canRequestManualReview: false,
        ),
      );
      await tester.pumpAndSettle();

      verify(() => verification.requestManualReview()).called(1);
      verify(() => verification.getStatus()).called(1); // reloaded
      expect(find.text(l10n.verifyManualReviewTitle), findsOneWidget);
    }, variant: brightnessVariant);

    testWidgets('manual review: Cancel sends nothing', (tester) async {
      statusReturns(declinedReviewable);
      await pumpHome(tester);

      await tester.tap(find.text(l10n.verifyManualReviewButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.manualReviewDialogCancel));
      await tester.pumpAndSettle();

      verifyNever(() => verification.requestManualReview());
      expect(find.text(l10n.verifyManualReviewButton), findsOneWidget);
    });

    for (final (name, error, message) in [
      (
        'MANUAL_REVIEW_NOT_AVAILABLE',
        const ApiError('MANUAL_REVIEW_NOT_AVAILABLE', statusCode: 409),
        null,
      ),
      (
        'VERIFICATION_IN_REVIEW',
        const ApiError('VERIFICATION_IN_REVIEW', statusCode: 409),
        null,
      ),
      (
        'NETWORK_ERROR',
        const ApiError(ApiErrorCode.networkError),
        l10n.errorNetwork,
      ),
    ]) {
      testWidgets('manual review refused ($name): status reloaded'
          '${message == null ? ', no SnackBar' : ', SnackBar'}', (
        tester,
      ) async {
        statusReturns(declinedReviewable);
        when(() => verification.requestManualReview())
            .thenAnswer((_) async => throw error);
        await pumpHome(tester);
        verify(() => verification.getStatus()).called(1);

        await tester.tap(find.text(l10n.verifyManualReviewButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.manualReviewDialogConfirm));
        await tester.pumpAndSettle();

        verify(() => verification.getStatus()).called(1);
        expect(
          find.byType(SnackBar),
          message == null ? findsNothing : findsOneWidget,
        );
        if (message != null) expect(find.text(message), findsOneWidget);
      });
    }
  });
}
