import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/app/router.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/device/device_name.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/storage_providers.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/features/auth/presentation/otp_screen.dart';
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

const _phone = '0911 234 567';
const _tokens = AuthTokens(
  accessToken: 'eyJaccess',
  refreshToken: 'eyJrefresh',
);

void main() {
  final l10n = AppLocalizationsEn();
  late MockAuthRepository auth;
  late TokenStorage tokens;

  setUp(() {
    auth = MockAuthRepository();
    // In-memory secure storage, so we can check what was stored.
    FlutterSecureStorage.setMockInitialValues({});
    tokens = TokenStorage(const FlutterSecureStorage());
  });

  /// Opens the code screen as phone entry would (after a 5-minute code).
  Future<void> openOtpScreen(
    WidgetTester tester, {
    int expiresInSeconds = 300,
  }) async {
    await tester.pumpRentalApp(
      brightness: brightnessVariant.currentValue ?? Brightness.light,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        verificationRepositoryProvider.overrideWithValue(
          FakeVerificationRepository(),
        ),
        tokenStorageProvider.overrideWithValue(tokens),
        deviceNameProvider.overrideWith((ref) async => 'Samsung SM-M156B'),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    unawaited(
      container
          .read(routerProvider)
          .push(
            AppRoutes.otp,
            extra: OtpScreenArgs(
              phone: _phone,
              expiresInSeconds: expiresInSeconds,
            ),
          ),
    );
    await tester.pumpAndSettle();
  }

  Finder codeField() => find.byType(TextField);
  Finder verifyButton() => find.widgetWithText(FilledButton, l10n.otpVerify);
  Finder newCodeButton() =>
      find.widgetWithText(OutlinedButton, l10n.otpSendNewCode);

  void verifyFails(ApiError error) {
    when(
      () => auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) async => throw error);
  }

  void verifySucceeds() {
    when(
      () => auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) async => _tokens);
  }

  testWidgets('shows the number, the field and the countdown', (tester) async {
    await openOtpScreen(tester);

    expect(find.text(l10n.otpTitle), findsOneWidget);
    expect(find.text(l10n.otpSentTo(_phone)), findsOneWidget);
    expect(find.text(l10n.otpExpiresIn('5:00')), findsOneWidget);
    expect(newCodeButton(), findsNothing);
    // Verify is disabled until 6 digits are entered.
    expect(tester.widget<FilledButton>(verifyButton()).onPressed, isNull);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('accepts digits only, at most 6', (tester) async {
    // Verify never answers here, so the screen stays open to inspect.
    final response = Completer<AuthTokens>();
    when(
      () => auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) => response.future);
    await openOtpScreen(tester);

    await tester.enterText(codeField(), '12a3-4');
    await tester.pump();
    expect(tester.widget<TextField>(codeField()).controller!.text, '1234');

    await tester.enterText(codeField(), '123456789');
    await tester.pump();
    expect(tester.widget<TextField>(codeField()).controller!.text, '123456');
    verify(
      () => auth.verifyOtp(
        phone: _phone,
        code: '123456',
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);

    response.complete(_tokens);
    await tester.pumpAndSettle();
  }, variant: brightnessVariant);

  testWidgets('6 digits submit automatically, store both tokens and go '
      'home (back does not return)', (tester) async {
    verifySucceeds();
    await openOtpScreen(tester);

    await tester.enterText(codeField(), '123456');
    await tester.pumpAndSettle();

    verify(
      () => auth.verifyOtp(
        phone: _phone,
        code: '123456',
        deviceName: 'Samsung SM-M156B',
      ),
    ).called(1);
    final stored = await tokens.read();
    expect(stored?.accessToken, _tokens.accessToken);
    expect(stored?.refreshToken, _tokens.refreshToken);
    expect(find.text(l10n.homeTitle), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeTitle), findsOneWidget);
    expect(find.text(l10n.otpTitle), findsNothing);
  }, variant: brightnessVariant);

  testWidgets('shows a disabled loading state while verifying', (tester) async {
    final response = Completer<AuthTokens>();
    when(
      () => auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) => response.future);
    await openOtpScreen(tester);

    await tester.enterText(codeField(), '123456');
    await tester.pump();

    expect(find.bySemanticsLabel(l10n.otpVerifying), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(codeField()).enabled, isFalse);

    response.complete(_tokens);
    await tester.pumpAndSettle();
    verify(
      () => auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);
  }, variant: brightnessVariant);

  group('countdown', () {
    testWidgets('counts down, then offers a new code', (tester) async {
      await openOtpScreen(tester);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.otpExpiresIn('4:59')), findsOneWidget);

      await tester.pump(const Duration(seconds: 238));
      expect(find.text(l10n.otpExpiresIn('1:01')), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(find.text(l10n.otpCodeExpired), findsOneWidget);
      expect(newCodeButton(), findsOneWidget);
      expect(tester.widget<TextField>(codeField()).enabled, isFalse);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('a new code restarts the countdown and clears the field', (
      tester,
    ) async {
      when(() => auth.requestOtp(_phone)).thenAnswer((_) async => 120);
      await openOtpScreen(tester, expiresInSeconds: 5);
      await tester.enterText(codeField(), '12');
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      await tester.tap(newCodeButton());
      await tester.pumpAndSettle();

      verify(() => auth.requestOtp(_phone)).called(1);
      expect(find.text(l10n.otpNewCodeSent), findsOneWidget);
      expect(find.text(l10n.otpExpiresIn('2:00')), findsOneWidget);
      expect(newCodeButton(), findsNothing);
      expect(tester.widget<TextField>(codeField()).controller!.text, isEmpty);
      expect(tester.widget<TextField>(codeField()).enabled, isTrue);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('a rate-limited new code shows the waiting time', (
      tester,
    ) async {
      when(() => auth.requestOtp(_phone)).thenAnswer(
        (_) async => throw const ApiError(
          'OTP_RATE_LIMITED',
          statusCode: 429,
          retryAfterSeconds: 400,
        ),
      );
      await openOtpScreen(tester, expiresInSeconds: 5);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      await tester.tap(newCodeButton());
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorTooManyAttemptsMinutes(7)), findsOneWidget);
      expect(newCodeButton(), findsOneWidget);
    }, variant: brightnessVariant);
  });

  group('errors', () {
    testWidgets('OTP_INVALID shows the attempts left and clears the field', (
      tester,
    ) async {
      verifyFails(
        const ApiError('OTP_INVALID', statusCode: 400, attemptsRemaining: 3),
      );
      await openOtpScreen(tester);

      await tester.enterText(codeField(), '000000');
      await tester.pumpAndSettle();

      expect(find.text(l10n.otpWrongCodeAttemptsLeft(3)), findsOneWidget);
      expect(tester.widget<TextField>(codeField()).controller!.text, isEmpty);
      expect(tester.widget<TextField>(codeField()).enabled, isTrue);
      expect(newCodeButton(), findsNothing);
      expect(await tokens.read(), isNull);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    for (final (code, message) in [
      ('OTP_EXPIRED', l10n.otpExpiredOrUsed),
      ('OTP_ATTEMPTS_EXCEEDED', l10n.otpAttemptsExceeded),
    ]) {
      testWidgets('$code offers a new code right away', (tester) async {
        verifyFails(ApiError(code, statusCode: 400));
        await openOtpScreen(tester);

        await tester.enterText(codeField(), '123456');
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(newCodeButton(), findsOneWidget);
        expect(tester.widget<TextField>(codeField()).enabled, isFalse);
        expect(await tokens.read(), isNull);
        await expectAccessible(tester);
      }, variant: brightnessVariant);
    }

    testWidgets('ACCOUNT_UNAVAILABLE opens the account-unavailable screen', (
      tester,
    ) async {
      verifyFails(const ApiError('ACCOUNT_UNAVAILABLE', statusCode: 403));
      await openOtpScreen(tester);

      await tester.enterText(codeField(), '123456');
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountUnavailableMessage), findsOneWidget);
      expect(find.text(l10n.accountUnavailableBackToSignIn), findsOneWidget);
      expect(codeField(), findsNothing);
      expect(await tokens.read(), isNull);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    for (final (name, error, message) in [
      (
        'NETWORK_ERROR',
        const ApiError(ApiErrorCode.networkError),
        l10n.errorNetwork,
      ),
      (
        'RATE_LIMITED',
        const ApiError('RATE_LIMITED', statusCode: 429, retryAfterSeconds: 90),
        l10n.errorTooManyAttemptsMinutes(2),
      ),
      ('an unknown code', const ApiError('SOMETHING_NEW'), l10n.errorGeneric),
    ]) {
      testWidgets('$name shows "$message" and lets the user try again', (
        tester,
      ) async {
        verifyFails(error);
        await openOtpScreen(tester);

        await tester.enterText(codeField(), '123456');
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(tester.widget<TextField>(codeField()).enabled, isTrue);
        expect(await tokens.read(), isNull);
      }, variant: brightnessVariant);
    }
  });

  testWidgets('without its arguments the route goes back to phone entry', (
    tester,
  ) async {
    await tester.pumpRentalApp();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );

    container.read(routerProvider).go(AppRoutes.otp);
    await tester.pumpAndSettle();

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
  });
}
