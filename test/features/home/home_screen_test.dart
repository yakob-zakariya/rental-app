import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/features/auth/data/auth_repository.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

import '../../helpers/pump_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

void main() {
  final l10n = AppLocalizationsEn();
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.checkSession()).thenAnswer((_) async {});
    when(() => auth.logout(any())).thenAnswer((_) async {});
  });

  Future<void> pumpSignedIn(WidgetTester tester) => tester.pumpRentalApp(
    brightness: brightnessVariant.currentValue!,
    storedTokens: _tokens,
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );

  testWidgets('shows home with a menu', (tester) async {
    await pumpSignedIn(tester);

    expect(find.text(l10n.homeTitle), findsOneWidget);
    expect(find.text(l10n.homeSignedInPlaceholder), findsOneWidget);
    expect(find.byTooltip(l10n.homeMenuTooltip), findsOneWidget);
    await expectAccessible(tester);
  }, variant: brightnessVariant);

  testWidgets('menu → Sign out: phone entry, tokens cleared, logout sent '
      'with the refresh token', (tester) async {
    await pumpSignedIn(tester);

    await tester.tap(find.byTooltip(l10n.homeMenuTooltip));
    await tester.pumpAndSettle();
    await expectAccessible(tester);
    await tester.tap(find.text(l10n.homeSignOut));
    await tester.pumpAndSettle();

    expect(find.text(l10n.phoneEntryHeadline), findsOneWidget);
    expect(await TokenStorage(const FlutterSecureStorage()).read(), isNull);
    verify(() => auth.logout(_tokens.refreshToken)).called(1);

    // Back doesn't return to home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeTitle), findsNothing);
  }, variant: brightnessVariant);
}
