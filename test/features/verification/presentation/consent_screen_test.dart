import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/features/verification/presentation/verification_flow.dart';
import 'package:rental_app/features/verification/presentation/verification_messages.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../../helpers/pump_app.dart';
import 'verification_test_helpers.dart';

/// The consent text from spec 3.5, word for word.
const _specConsentText =
    'Your ID and selfie are checked by our verification partner, Didit. We '
    "don't store the photos. We keep your verified name, date of birth and a "
    'protected one-way reference to your ID number, used only to prevent '
    'duplicate and banned accounts.';

void main() {
  final l10n = AppLocalizationsEn();
  late MockVerificationRepository repository;
  late MockVerificationFlow flow;

  setUp(() {
    repository = MockVerificationRepository();
    flow = MockVerificationFlow();
    // The Checking screen (after a completed flow) keeps seeing "pending".
    when(() => repository.getStatus())
        .thenAnswer((_) async => summaryOf(VerificationStatus.pending));
  });

  /// Home → "Verify my identity" → the consent screen.
  Future<void> openConsent(WidgetTester tester) async {
    await pumpSignedIn(tester, repository: repository, flow: flow);
    await tester.tap(find.text(l10n.verifyNotVerifiedButton));
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.byType(FilledButton);

  testWidgets('shows the consent text exactly as in the spec', (tester) async {
    await openConsent(tester);

    expect(find.text(l10n.consentTitle), findsOneWidget);
    expect(find.text(l10n.consentHeadline), findsOneWidget);
    expect(l10n.consentBody, _specConsentText);
    expect(find.text(_specConsentText), findsOneWidget);
    verifyNever(() => flow.run());
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('Continue: a disabled spinner while starting; completed → '
      'Checking, and back from there goes home', (tester) async {
    final result = Completer<VerificationFlowResult>();
    when(() => flow.run()).thenAnswer((_) => result.future);
    await openConsent(tester);

    await tester.tap(continueButton());
    await tester.pump();
    expect(find.bySemanticsLabel(l10n.consentStarting), findsOneWidget);
    expect(tester.widget<FilledButton>(continueButton()).onPressed, isNull);

    result.complete(const OpenChecking());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.checkingTitle), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.homeTitle), findsOneWidget);
    expect(find.text(l10n.consentTitle), findsNothing);
    verify(() => flow.run()).called(1);
  }, variant: brightnessVariant);

  testWidgets('cancelled in Didit → home', (tester) async {
    when(() => flow.run()).thenAnswer((_) async => const BackHome());
    await openConsent(tester);

    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    expect(find.text(l10n.homeTitle), findsOneWidget);
  }, variant: brightnessVariant);

  testWidgets('failed in Didit → home with "couldn\'t continue"', (
    tester,
  ) async {
    when(() => flow.run()).thenAnswer((_) async => const SdkFailed());
    await openConsent(tester);

    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    expect(find.text(l10n.homeTitle), findsOneWidget);
    expect(find.text(l10n.verifyFailedMessage), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  group('a refused start', () {
    for (final code in [
      'ALREADY_VERIFIED',
      'VERIFICATION_IN_REVIEW',
      'VERIFICATION_UNAVAILABLE',
    ]) {
      testWidgets('$code → home (its reloaded card shows the status)', (
        tester,
      ) async {
        when(
          () => flow.run(),
        ).thenAnswer((_) async => StartFailed(ApiError(code, statusCode: 409)));
        await openConsent(tester);

        await tester.tap(continueButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.homeTitle), findsOneWidget);
      });
    }

    for (final (name, error) in [
      (
        'VERIFICATION_RETRY_LIMIT',
        const ApiError(
          'VERIFICATION_RETRY_LIMIT',
          statusCode: 429,
          retryAfterSeconds: 3600,
          manualReviewAvailable: true,
        ),
      ),
      (
        'VERIFICATION_PROVIDER_UNAVAILABLE',
        const ApiError('VERIFICATION_PROVIDER_UNAVAILABLE', statusCode: 503),
      ),
      ('NETWORK_ERROR', const ApiError(ApiErrorCode.networkError)),
    ]) {
      testWidgets('$name stays here with its message; Continue works again', (
        tester,
      ) async {
        when(() => flow.run()).thenAnswer((_) async => StartFailed(error));
        await openConsent(tester);

        await tester.tap(continueButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.consentTitle), findsOneWidget);
        // The same wording as Home ("after HH:mm" / "tomorrow after HH:mm").
        expect(find.text(startErrorMessage(error, l10n)!), findsOneWidget);
        expect(
          tester.widget<FilledButton>(continueButton()).onPressed,
          isNotNull,
        );
        await expectAccessible(tester);
      }, variant: brightnessVariant);
    }
  });
}
