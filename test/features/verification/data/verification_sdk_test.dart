import 'package:didit_sdk/sdk_flutter.dart' as didit;
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/features/verification/data/verification_sdk.dart';

void main() {
  group('sdkOutcomeOf (the SDK verdict is ignored, hard rule 5)', () {
    for (final status in didit.VerificationStatus.values) {
      test('completed with Didit status "${status.name}" → completed', () {
        expect(
          sdkOutcomeOf(
            didit.VerificationCompleted(
              session: didit.SessionData(sessionId: 's1', status: status),
            ),
          ),
          SdkOutcome.completed,
        );
      });
    }

    test('cancelled → cancelled', () {
      expect(
        sdkOutcomeOf(const didit.VerificationCancelled()),
        SdkOutcome.cancelled,
      );
    });

    for (final type in didit.VerificationErrorType.values) {
      test('failed (${type.name}) → failed', () {
        expect(
          sdkOutcomeOf(
            didit.VerificationFailed(
              error: didit.VerificationError(type: type, message: 'details'),
            ),
          ),
          SdkOutcome.failed,
        );
      });
    }
  });

  group('diditLanguageFor (the user\'s language if Didit has it, else en)', () {
    test('Amharic and Afaan Oromo are not supported by Didit → English', () {
      expect(diditSupportedLanguages, isNot(contains('am')));
      expect(diditSupportedLanguages, isNot(contains('om')));
      expect(diditLanguageFor('am'), 'en');
      expect(diditLanguageFor('om'), 'en');
    });

    test('English stays English', () {
      expect(diditLanguageFor('en'), 'en');
    });

    test('a supported language is passed through', () {
      expect(diditLanguageFor('fr'), 'fr');
      expect(diditLanguageFor('ar'), 'ar');
    });

    test('unknown or missing → English', () {
      expect(diditLanguageFor('xx'), 'en');
      expect(diditLanguageFor(null), 'en');
    });

    test('Didit lists 54 languages', () {
      expect(diditSupportedLanguages, hasLength(54));
    });
  });
}
