import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/app/router.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../../helpers/pump_app.dart';
import 'verification_test_helpers.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late MockVerificationRepository repository;
  late MockVerificationFlow flow;
  late int polls;

  /// Every poll answers with the next value of [answer].
  void answerPolls(Future<VerificationSummary> Function(int poll) answer) {
    polls = 0;
    when(() => repository.getStatus()).thenAnswer((_) => answer(++polls));
  }

  setUp(() {
    repository = MockVerificationRepository();
    flow = MockVerificationFlow();
    answerPolls((_) async => summaryOf(VerificationStatus.pending));
  });

  Future<void> openChecking(WidgetTester tester) async {
    await pumpSignedIn(tester, repository: repository, flow: flow);
    await pushFromHome(tester, AppRoutes.verificationChecking);
  }

  testWidgets('polls every 5 s for the first minute, then every 30 s', (
    tester,
  ) async {
    await openChecking(tester);
    expect(polls, 1); // right away
    expect(find.text(l10n.verifyPendingTitle), findsWidgets);
    expect(find.text(l10n.checkingLeaveHint), findsNothing);

    for (var i = 0; i < 11; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(polls, 12); // 0, 5, …, 55 s

    await tester.pump(const Duration(seconds: 5));
    expect(polls, 13); // 60 s — then the slow phase starts
    expect(find.text(l10n.checkingLeaveHint), findsOneWidget);

    await tester.pump(const Duration(seconds: 25));
    expect(polls, 13); // nothing at 65 … 85 s
    await tester.pump(const Duration(seconds: 5));
    expect(polls, 14); // 90 s
    await tester.pump(const Duration(seconds: 30));
    expect(polls, 15); // 120 s
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('polls at once when the app returns to the foreground', (
    tester,
  ) async {
    await openChecking(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(polls, 1);

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
    await tester.pump();

    expect(polls, 2);
  });

  testWidgets('a network error shows a hint, and polling continues', (
    tester,
  ) async {
    answerPolls(
      (poll) async => poll == 1
          ? throw const ApiError(ApiErrorCode.networkError)
          : summaryOf(VerificationStatus.pending),
    );
    await openChecking(tester);
    expect(find.text(l10n.checkingOfflineHint), findsOneWidget);
    await expectAccessible(tester);

    await tester.pump(const Duration(seconds: 5));
    expect(polls, 2);
    expect(find.text(l10n.checkingOfflineHint), findsNothing);
  }, variant: brightnessVariant);

  testWidgets('another error shows the generic hint', (tester) async {
    answerPolls(
      (_) async =>
          throw const ApiError(ApiErrorCode.unknownError, statusCode: 500),
    );
    await openChecking(tester);

    expect(find.text(l10n.checkingErrorHint), findsOneWidget);
  });

  testWidgets('the decision shows its card, polling stops, and "Back to '
      'home" leaves', (tester) async {
    answerPolls(
      (poll) async => poll < 3
          ? summaryOf(VerificationStatus.pending)
          : summaryOf(VerificationStatus.approved),
    );
    await openChecking(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(polls, 3);
    expect(find.text(l10n.verifyApprovedTitle), findsOneWidget);
    await expectAccessible(tester);

    await tester.pump(const Duration(minutes: 5));
    expect(polls, 3); // no more polling

    await tester.tap(find.text(l10n.checkingBackHome));
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeTitle), findsOneWidget);
  }, variant: brightnessVariant);

  testWidgets('declined: "Try again" opens the consent screen', (tester) async {
    answerPolls(
      (_) async => summaryOf(
        VerificationStatus.declined,
        canRetry: true,
        reasonCode: 'PHOTO_UNCLEAR',
      ),
    );
    await openChecking(tester);
    await tester.pump();
    expect(find.text(l10n.reasonPhotoUnclear), findsOneWidget);

    await tester.tap(find.text(l10n.verifyTryAgainButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.consentTitle), findsOneWidget);
  });

  testWidgets('declined: manual review from here, then home', (tester) async {
    answerPolls(
      (_) async => summaryOf(
        VerificationStatus.declined,
        canRequestManualReview: true,
        reasonCode: 'DOCUMENT_NOT_VERIFIED',
      ),
    );
    when(() => repository.requestManualReview())
        .thenAnswer((_) async => summaryOf(VerificationStatus.manualReview));
    await openChecking(tester);
    await tester.pump();

    await tester.tap(find.text(l10n.verifyManualReviewButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.manualReviewDialogConfirm));
    await tester.pumpAndSettle();

    verify(() => repository.requestManualReview()).called(1);
    expect(find.text(l10n.homeTitle), findsOneWidget);
  });

  testWidgets('leaving the screen stops polling', (tester) async {
    await openChecking(tester);
    expect(polls, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeTitle), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    expect(polls, 1);
  });
}
