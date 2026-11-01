import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/time/addis_time.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/features/verification/presentation/widgets/verification_status_card.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../../helpers/pump_app.dart';

VerificationSummary summary(
  VerificationStatus status, {
  bool canRetry = false,
  bool canRequestManualReview = false,
  DateTime? retryAvailableAt,
  String? reasonCode,
}) => VerificationSummary(
  status: status,
  canRetry: canRetry,
  retriesLeftToday: canRetry ? 2 : 0,
  canRequestManualReview: canRequestManualReview,
  retryAvailableAt: retryAvailableAt,
  reasonCode: reasonCode,
);

/// The UTC instant of [hour]:[minute] on today's date in Addis Ababa.
/// (In widget tests `clock.now()` starts at the real current time.)
DateTime addisToday(int hour, [int minute = 0]) {
  final today = toAddisAbaba(clock.now());
  return DateTime.utc(
    today.year,
    today.month,
    today.day,
    hour,
    minute,
  ).subtract(addisAbabaOffset);
}

void main() {
  final l10n = AppLocalizationsEn();
  late List<String> tapped;
  late VerificationActions actions;

  setUp(() {
    tapped = [];
    actions = VerificationActions(
      onVerify: () => tapped.add('verify'),
      onContinue: () => tapped.add('continue'),
      onTryAgain: () => tapped.add('tryAgain'),
      onRequestManualReview: () => tapped.add('manualReview'),
    );
  });

  Future<void> pumpCard(
    WidgetTester tester,
    VerificationSummary s, {
    String? verifiedName,
  }) => tester.pumpScreen(
    Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          VerificationStatusCard(
            summary: s,
            actions: actions,
            verifiedName: verifiedName,
          ),
        ],
      ),
    ),
    brightness: brightnessVariant.currentValue!,
  );

  int buttonCount(WidgetTester tester) =>
      find.byType(FilledButton).evaluate().length +
      find.byType(OutlinedButton).evaluate().length;

  testWidgets('not_verified: why we verify + "Verify my identity"', (
    tester,
  ) async {
    await pumpCard(
      tester,
      summary(VerificationStatus.notVerified, canRetry: true),
    );

    expect(find.text(l10n.verifyNotVerifiedTitle), findsOneWidget);
    expect(find.text(l10n.verifyNotVerifiedBody), findsOneWidget);
    await tester.tap(find.text(l10n.verifyNotVerifiedButton));
    expect(tapped, ['verify']);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  group('pending', () {
    testWidgets('with canRetry: "Continue verification"', (tester) async {
      await pumpCard(
        tester,
        summary(VerificationStatus.pending, canRetry: true),
      );

      expect(find.text(l10n.verifyPendingTitle), findsOneWidget);
      await tester.tap(find.text(l10n.verifyContinueButton));
      expect(tapped, ['continue']);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('without canRetry: no button', (tester) async {
      await pumpCard(tester, summary(VerificationStatus.pending));

      expect(find.text(l10n.verifyPendingTitle), findsOneWidget);
      expect(buttonCount(tester), 0);
    }, variant: brightnessVariant);
  });

  group('approved', () {
    testWidgets('shows the verified badge and name', (tester) async {
      await pumpCard(
        tester,
        summary(VerificationStatus.approved),
        verifiedName: 'Abebe Kebede',
      );

      expect(find.text(l10n.verifyApprovedTitle), findsOneWidget);
      expect(find.text(l10n.verifyApprovedAs('Abebe Kebede')), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(buttonCount(tester), 0);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('before the name has loaded', (tester) async {
      await pumpCard(tester, summary(VerificationStatus.approved));

      expect(find.text(l10n.verifyApprovedBody), findsOneWidget);
    }, variant: brightnessVariant);
  });

  group('declined', () {
    testWidgets('shows the reason', (tester) async {
      await pumpCard(
        tester,
        summary(
          VerificationStatus.declined,
          canRetry: true,
          reasonCode: 'PHOTO_UNCLEAR',
        ),
      );

      expect(find.text(l10n.verifyDeclinedTitle), findsOneWidget);
      expect(find.text(l10n.reasonPhotoUnclear), findsOneWidget);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('an unknown reason: the fallback text', (tester) async {
      await pumpCard(
        tester,
        summary(VerificationStatus.declined, canRetry: true, reasonCode: 'NEW'),
      );

      expect(find.text(l10n.reasonFallback), findsOneWidget);
    }, variant: brightnessVariant);

    // The buttons follow the API's two flags independently (hard rule 7).
    for (final canRetry in [true, false]) {
      for (final canRequestManualReview in [true, false]) {
        testWidgets('canRetry: $canRetry, canRequestManualReview: '
            '$canRequestManualReview', (tester) async {
          await pumpCard(
            tester,
            summary(
              VerificationStatus.declined,
              canRetry: canRetry,
              canRequestManualReview: canRequestManualReview,
              reasonCode: 'DOCUMENT_NOT_VERIFIED',
            ),
          );

          expect(
            find.text(l10n.verifyTryAgainButton),
            canRetry ? findsOneWidget : findsNothing,
          );
          expect(
            find.text(l10n.verifyManualReviewButton),
            canRequestManualReview ? findsOneWidget : findsNothing,
          );
          // Out of tries without a known time: "later".
          expect(
            find.text(l10n.verifyTryAgainLater),
            canRetry ? findsNothing : findsOneWidget,
          );
          if (canRequestManualReview) {
            await tester.tap(find.text(l10n.verifyManualReviewButton));
            expect(tapped, ['manualReview']);
          }
          await expectAccessible(tester);
        }, variant: brightnessVariant);
      }
    }

    testWidgets('out of tries: "after HH:mm" today, in Addis Ababa time', (
      tester,
    ) async {
      // 12:00 today in Addis Ababa, whatever time the test runs.
      await pumpCard(
        tester,
        summary(VerificationStatus.declined, retryAvailableAt: addisToday(12)),
      );

      expect(find.text(l10n.verifyRetryAfter('12:00')), findsOneWidget);
    }, variant: brightnessVariant);

    testWidgets('out of tries: "tomorrow after HH:mm"', (tester) async {
      // 09:15 tomorrow in Addis Ababa.
      await pumpCard(
        tester,
        summary(
          VerificationStatus.declined,
          retryAvailableAt: addisToday(9, 15).add(const Duration(days: 1)),
        ),
      );

      expect(find.text(l10n.verifyRetryTomorrowAfter('09:15')), findsOneWidget);
    }, variant: brightnessVariant);
  });

  testWidgets('manual_review: "Our team is reviewing", no buttons', (
    tester,
  ) async {
    await pumpCard(tester, summary(VerificationStatus.manualReview));

    expect(find.text(l10n.verifyManualReviewTitle), findsOneWidget);
    expect(buttonCount(tester), 0);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('blocked: only "Please contact support", no reason, no buttons '
      '(even with a reasonCode)', (tester) async {
    await pumpCard(
      tester,
      summary(
        VerificationStatus.blocked,
        canRetry: true,
        canRequestManualReview: true,
        reasonCode: 'UNDERAGE',
      ),
    );

    expect(find.text(l10n.verifyBlockedBody), findsOneWidget);
    expect(find.text(l10n.reasonUnderage), findsNothing);
    expect(buttonCount(tester), 0);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('an unknown status: fallback text, no buttons', (tester) async {
    await pumpCard(tester, summary(VerificationStatus.unknown, canRetry: true));

    expect(find.text(l10n.verifyUnknownBody), findsOneWidget);
    expect(buttonCount(tester), 0);
    await expectAccessible(tester);
  }, variant: brightnessVariant);
}
