import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final l10n = AppLocalizationsEn();
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  Future<void> pump(WidgetTester tester) => tester.pumpRentalApp(
    brightness: brightnessVariant.currentValue!,
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );

  Finder field() => find.byType(TextField);
  Finder sendButton() =>
      find.widgetWithText(FilledButton, l10n.phoneEntrySendCode);

  testWidgets('shows the phone entry screen', (tester) async {
    await pump(tester);

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    expect(find.text(l10n.phoneEntryBody), findsOneWidget);
    expect(find.text(l10n.phoneEntryFieldLabel), findsOneWidget);
    expect(sendButton(), findsOneWidget);
    expect(tester.widget<TextField>(field()).keyboardType, TextInputType.phone);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('an empty field shows an error and calls nothing', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(field(), '   ');
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text(l10n.phoneEntryEmpty), findsOneWidget);
    verifyZeroInteractions(auth);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('shows a disabled loading button while sending, without '
      'double submits', (tester) async {
    final response = Completer<int>();
    when(() => auth.requestOtp(any())).thenAnswer((_) => response.future);
    await pump(tester);

    await tester.enterText(field(), '0911 234 567');
    await tester.tap(sendButton());
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.phoneEntrySending), findsOneWidget);

    // Submitting again from the keyboard does nothing while loading.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    verify(() => auth.requestOtp('0911 234 567')).called(1);

    response.complete(300);
    await tester.pumpAndSettle();
  }, variant: brightnessVariant);

  testWidgets('on success, opens the code screen; back returns with the '
      'number kept', (tester) async {
    when(() => auth.requestOtp(any())).thenAnswer((_) async => 300);
    await pump(tester);

    await tester.enterText(field(), '0911 234 567');
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text(l10n.otpTitle), findsOneWidget);
    expect(
      find.text(l10n.otpPlaceholderSentTo('0911 234 567')),
      findsOneWidget,
    );
    await expectAccessible(tester);

    // Android's back button.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    // The number is still in the field.
    expect(tester.widget<TextField>(field()).controller!.text, '0911 234 567');
  }, variant: brightnessVariant);

  testWidgets('submits from the keyboard\'s Done key', (tester) async {
    when(() => auth.requestOtp(any())).thenAnswer((_) async => 300);
    await pump(tester);

    await tester.enterText(field(), '0911234567');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(() => auth.requestOtp('0911234567')).called(1);
    expect(find.text(l10n.otpTitle), findsOneWidget);
  }, variant: brightnessVariant);

  group('errors', () {
    final cases = {
      'INVALID_PHONE (under the field)': (
        const ApiError('INVALID_PHONE', statusCode: 400),
        l10n.errorInvalidPhone,
      ),
      'OTP_RATE_LIMITED': (
        const ApiError(
          'OTP_RATE_LIMITED',
          statusCode: 429,
          retryAfterSeconds: 420,
        ),
        l10n.errorTooManyAttemptsMinutes(7),
      ),
      'RATE_LIMITED': (
        const ApiError('RATE_LIMITED', statusCode: 429, retryAfterSeconds: 30),
        l10n.errorTooManyAttemptsMinutes(1),
      ),
      'SMS_SEND_FAILED': (
        const ApiError('SMS_SEND_FAILED', statusCode: 503),
        l10n.errorSmsSendFailed,
      ),
      'NETWORK_ERROR': (
        const ApiError(ApiErrorCode.networkError),
        l10n.errorNetwork,
      ),
      'an unknown code': (
        const ApiError('SOMETHING_NEW', statusCode: 400),
        l10n.errorGeneric,
      ),
    };

    for (final MapEntry(key: name, value: (error, expected)) in cases.entries) {
      testWidgets('$name shows "$expected" and the button works again', (
        tester,
      ) async {
        when(() => auth.requestOtp(any())).thenAnswer((_) async => throw error);
        await pump(tester);

        await tester.enterText(field(), '0911 234 567');
        await tester.tap(sendButton());
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
        expect(find.text(l10n.otpTitle), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        await expectAccessible(tester);
      }, variant: brightnessVariant);
    }

    testWidgets('a new attempt clears the previous error', (tester) async {
      when(() => auth.requestOtp(any())).thenAnswer(
        (_) async => throw const ApiError('INVALID_PHONE', statusCode: 400),
      );
      await pump(tester);
      await tester.enterText(field(), '123');
      await tester.tap(sendButton());
      await tester.pumpAndSettle();
      expect(find.text(l10n.errorInvalidPhone), findsOneWidget);

      when(() => auth.requestOtp(any())).thenAnswer((_) async => 300);
      await tester.enterText(field(), '0911 234 567');
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      expect(find.text(l10n.otpTitle), findsOneWidget);
    }, variant: brightnessVariant);
  });
}
