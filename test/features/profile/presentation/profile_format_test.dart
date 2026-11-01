import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/features/profile/presentation/profile_format.dart';
import 'package:rental_app/features/verification/data/verification_status.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('formatPhoneForDisplay (3-3-3 after +251)', () {
    test('a 09… number', () {
      expect(formatPhoneForDisplay('+251911234567'), '+251 911 234 567');
    });

    test('a 07… number', () {
      expect(formatPhoneForDisplay('+251711234567'), '+251 711 234 567');
    });

    test('anything else is shown as received', () {
      expect(formatPhoneForDisplay('+25191123456'), '+25191123456');
      expect(formatPhoneForDisplay('+12025550123'), '+12025550123');
      expect(formatPhoneForDisplay(''), '');
    });
  });

  group('verificationStatusLabel', () {
    test('every status has words', () {
      expect(
        {
          for (final s in VerificationStatus.values)
            s: verificationStatusLabel(s, l10n),
        },
        {
          VerificationStatus.notVerified: 'Not verified',
          VerificationStatus.pending: 'Being checked',
          VerificationStatus.approved: 'Verified',
          VerificationStatus.declined: 'Not approved',
          VerificationStatus.manualReview: 'Under review',
          VerificationStatus.blocked: 'Please contact support.',
          VerificationStatus.unknown: l10n.verifyUnknownBody,
        },
      );
    });
  });

  test('language choices: am, om, en, each in its own name', () {
    expect(languageChoices(l10n), [
      ('am', 'አማርኛ'),
      ('om', 'Afaan Oromoo'),
      ('en', 'English'),
    ]);
  });
}
