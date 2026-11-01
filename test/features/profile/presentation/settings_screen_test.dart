import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/app/licenses.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/features/profile/data/profile_repository.dart';
import 'package:rental_app/features/profile/data/user_profile.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

const _tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

UserProfile profileOf({
  VerificationStatus status = VerificationStatus.notVerified,
  String language = 'am',
  String? fullName,
  String? dateOfBirth,
}) => UserProfile(
  id: 'u1',
  phone: '+251911234567',
  fullName: fullName,
  dateOfBirth: dateOfBirth,
  preferredLanguage: language,
  verificationStatus: status,
  createdAt: DateTime.utc(2026, 10, 30),
);

void main() {
  final l10n = AppLocalizationsEn();
  late MockAuthRepository auth;
  late MockProfileRepository profile;

  setUpAll(registerFontLicenses);

  setUp(() {
    auth = MockAuthRepository();
    profile = MockProfileRepository();
    when(() => auth.checkSession()).thenAnswer((_) async {});
    when(() => auth.logout(any())).thenAnswer((_) async {});
  });

  void meReturns(UserProfile me) =>
      when(() => profile.getMe()).thenAnswer((_) async => me);

  /// Signed in, then Home's menu → Settings.
  Future<void> openSettings(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpRentalApp(
      brightness: brightnessVariant.currentValue ?? Brightness.light,
      storedTokens: _tokens,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profile),
        verificationStatusProvider.overrideWith(
          (ref) async => const VerificationSummary(
            status: VerificationStatus.notVerified,
            canRetry: true,
            retriesLeftToday: 3,
            canRequestManualReview: false,
          ),
        ),
      ],
    );
    await tester.tap(find.byTooltip(l10n.homeMenuTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.homeSettings));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Finder savingSpinnerIn(WidgetTester tester, String language) =>
      find.descendant(
        of: find.widgetWithText(RadioListTile<String>, language),
        matching: find.byType(CircularProgressIndicator),
      );

  String? selectedLanguage(WidgetTester tester) => tester
      .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
      .groupValue;

  testWidgets('a new user: phone (grouped), status, language; no identity '
      'data', (tester) async {
    meReturns(profileOf());
    await openSettings(tester);

    expect(find.text(l10n.settingsTitle), findsOneWidget);
    expect(find.text('+251 911 234 567'), findsOneWidget);
    expect(find.text(l10n.statusNotVerified), findsOneWidget);
    expect(find.text(l10n.settingsVerifiedName), findsNothing);
    expect(find.text(l10n.settingsDateOfBirth), findsNothing);
    for (final label in ['አማርኛ', 'Afaan Oromoo', 'English']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(selectedLanguage(tester), 'am');
    expect(find.text(l10n.settingsLanguageNote), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('approved: the verified name, and the date of birth exactly as '
      'received', (tester) async {
    meReturns(
      profileOf(
        status: VerificationStatus.approved,
        fullName: 'Abebe Kebede',
        dateOfBirth: '1995-03-01',
      ),
    );
    await openSettings(tester);

    expect(find.text(l10n.statusApproved), findsOneWidget);
    expect(find.text('Abebe Kebede'), findsOneWidget);
    expect(find.text('1995-03-01'), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('blocked: only the neutral text, no identity data', (
    tester,
  ) async {
    meReturns(
      profileOf(
        status: VerificationStatus.blocked,
        fullName: 'Abebe Kebede',
        dateOfBirth: '1995-03-01',
      ),
    );
    await openSettings(tester);

    expect(find.text(l10n.verifyBlockedBody), findsOneWidget);
    expect(find.text('Abebe Kebede'), findsNothing);
    expect(find.text('1995-03-01'), findsNothing);
  }, variant: brightnessVariant);

  testWidgets('an unknown preferred language: nothing ticked', (tester) async {
    meReturns(profileOf(language: 'fr'));
    await openSettings(tester);

    expect(selectedLanguage(tester), 'fr');
    expect(
      tester
          .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
          .map((t) => t.value),
      isNot(contains('fr')),
    );
  });

  testWidgets('loading, then a failed first load with Retry', (tester) async {
    final first = Completer<UserProfile>();
    when(() => profile.getMe()).thenAnswer((_) => first.future);
    await openSettings(tester, settle: false);
    expect(find.bySemanticsLabel(l10n.settingsLoading), findsOneWidget);

    first.completeError(const ApiError(ApiErrorCode.networkError));
    await tester.pumpAndSettle();
    expect(find.text(l10n.errorNetwork), findsOneWidget);
    await expectAccessible(tester);

    meReturns(profileOf());
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text('+251 911 234 567'), findsOneWidget);
  }, variant: brightnessVariant);

  group('language', () {
    testWidgets('choosing one: spinner, PATCH /me, reload, ticked', (
      tester,
    ) async {
      meReturns(profileOf(language: 'am'));
      final saved = Completer<UserProfile>();
      when(() => profile.updateLanguage(any())).thenAnswer((_) => saved.future);
      await openSettings(tester);

      await tester.tap(find.text('English'));
      await tester.pump();
      // The spinner sits in the English row (whose screen-reader label then
      // reads "English, Saving…").
      expect(savingSpinnerIn(tester, 'English'), findsOneWidget);
      // While saving, the other choices are disabled.
      expect(
        tester
            .widgetList<RadioListTile<String>>(
              find.byType(RadioListTile<String>),
            )
            .every((t) => t.enabled == false),
        isTrue,
      );

      meReturns(profileOf(language: 'en'));
      saved.complete(profileOf(language: 'en'));
      await tester.pumpAndSettle();

      verify(() => profile.updateLanguage('en')).called(1);
      expect(selectedLanguage(tester), 'en');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await expectAccessible(tester);
    }, variant: brightnessVariant);

    testWidgets('choosing the current one sends nothing', (tester) async {
      meReturns(profileOf(language: 'am'));
      await openSettings(tester);

      await tester.tap(find.text('አማርኛ'));
      await tester.pumpAndSettle();

      verifyNever(() => profile.updateLanguage(any()));
    });

    for (final (name, error, message) in [
      (
        'no connection',
        const ApiError(ApiErrorCode.networkError),
        l10n.errorNetwork,
      ),
      (
        'another error',
        const ApiError('VALIDATION_FAILED', statusCode: 400),
        l10n.errorGeneric,
      ),
    ]) {
      testWidgets('a failed change ($name): SnackBar, the old choice stays', (
        tester,
      ) async {
        meReturns(profileOf(language: 'am'));
        when(() => profile.updateLanguage(any()))
            .thenAnswer((_) async => throw error);
        await openSettings(tester);

        await tester.tap(find.text('Afaan Oromoo'));
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(selectedLanguage(tester), 'am');
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }, variant: brightnessVariant);
    }
  });

  testWidgets('Sign out → phone entry, tokens cleared, logout sent', (
    tester,
  ) async {
    meReturns(profileOf());
    await openSettings(tester);

    // Below the cards: scroll to it, as on a small phone.
    await tester.scrollUntilVisible(find.text(l10n.homeSignOut), 200);
    await tester.tap(find.text(l10n.homeSignOut));
    await tester.pumpAndSettle();

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    expect(await TokenStorage(const FlutterSecureStorage()).read(), isNull);
    verify(() => auth.logout(_tokens.refreshToken)).called(1);
  });

  testWidgets('the licences link opens the licences page', (tester) async {
    meReturns(profileOf());
    await openSettings(tester);

    await tester.scrollUntilVisible(find.text(l10n.settingsLicences), 200);
    await tester.tap(find.text(l10n.settingsLicences));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('back from settings returns home', (tester) async {
    meReturns(profileOf());
    await openSettings(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(l10n.homeTitle), findsOneWidget);
  });
}
