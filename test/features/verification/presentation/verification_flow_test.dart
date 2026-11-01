import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/api/api_error.dart';
import 'package:rental_app/features/profile/data/profile_repository.dart';
import 'package:rental_app/features/profile/data/user_profile.dart';
import 'package:rental_app/features/verification/data/verification_repository.dart';
import 'package:rental_app/features/verification/data/verification_sdk.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/features/verification/presentation/verification_flow.dart';

class MockVerificationRepository extends Mock
    implements VerificationRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

/// Records how it was opened and ends the way the test says.
class FakeSdk implements VerificationSdk {
  FakeSdk(this.outcome);

  final SdkOutcome outcome;
  final calls = <(String token, String language)>[];

  @override
  Future<SdkOutcome> start(
    String sessionToken, {
    required String languageCode,
  }) async {
    calls.add((sessionToken, languageCode));
    return outcome;
  }
}

const _session = VerificationSession(
  verificationUrl: 'https://verify.didit.me/s',
  sessionToken: 'token-1',
);

UserProfile _me(String language) => UserProfile(
  id: 'u1',
  phone: '+251911234567',
  preferredLanguage: language,
  verificationStatus: VerificationStatus.notVerified,
  createdAt: DateTime.utc(2026),
);

void main() {
  late MockVerificationRepository repository;

  setUp(() {
    repository = MockVerificationRepository();
    when(() => repository.startSession()).thenAnswer((_) async => _session);
  });

  VerificationFlow flowWith(FakeSdk sdk) => VerificationFlow(
    repository: repository,
    sdk: sdk,
    languageCode: () async => 'en',
  );

  test('completed → OpenChecking; the SDK gets the session token', () async {
    final sdk = FakeSdk(SdkOutcome.completed);

    expect(await flowWith(sdk).run(), isA<OpenChecking>());
    expect(sdk.calls, [('token-1', 'en')]);
  });

  test('cancelled → BackHome', () async {
    expect(
      await flowWith(FakeSdk(SdkOutcome.cancelled)).run(),
      isA<BackHome>(),
    );
  });

  test('failed → SdkFailed', () async {
    expect(await flowWith(FakeSdk(SdkOutcome.failed)).run(), isA<SdkFailed>());
  });

  test('a refused start → StartFailed, and the SDK never opens', () async {
    const error = ApiError('VERIFICATION_RETRY_LIMIT', statusCode: 429);
    when(() => repository.startSession()).thenAnswer((_) async => throw error);
    final sdk = FakeSdk(SdkOutcome.completed);

    final result = await flowWith(sdk).run();

    expect(result, isA<StartFailed>().having((r) => r.error, 'error', error));
    expect(sdk.calls, isEmpty);
  });

  group('the language passed to Didit (from GET /me)', () {
    late MockProfileRepository profile;

    setUp(() => profile = MockProfileRepository());

    Future<String> languageSentFor(Future<UserProfile> Function() me) async {
      when(() => profile.getMe()).thenAnswer((_) => me());
      final sdk = FakeSdk(SdkOutcome.cancelled);
      final container = ProviderContainer(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(repository),
          verificationSdkProvider.overrideWithValue(sdk),
          profileRepositoryProvider.overrideWithValue(profile),
        ],
      );
      addTearDown(container.dispose);

      await container.read(verificationFlowProvider).run();
      return sdk.calls.single.$2;
    }

    test('Amharic (not supported by Didit) → en', () async {
      expect(await languageSentFor(() async => _me('am')), 'en');
    });

    test('Afaan Oromoo (not supported by Didit) → en', () async {
      expect(await languageSentFor(() async => _me('om')), 'en');
    });

    test('English → en', () async {
      expect(await languageSentFor(() async => _me('en')), 'en');
    });

    test('/me failing → en (the flow still opens)', () async {
      expect(
        await languageSentFor(
          () async => throw const ApiError(ApiErrorCode.networkError),
        ),
        'en',
      );
    });
  });
}
