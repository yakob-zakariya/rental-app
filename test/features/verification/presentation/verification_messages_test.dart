import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/features/verification/presentation/verification_messages.dart';
import 'package:rental_app/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('declineReasonMessage', () {
    test('every contract reason code', () {
      expect(
        declineReasonMessage('PHOTO_UNCLEAR', l10n),
        "The photo wasn't clear enough. Retake it in good light.",
      );
      expect(
        declineReasonMessage('DOCUMENT_EXPIRED', l10n),
        'Your document has expired.',
      );
      expect(
        declineReasonMessage('DOCUMENT_NOT_ACCEPTED', l10n),
        'Use your Fayda ID card or a passport.',
      );
      expect(
        declineReasonMessage('UNDERAGE', l10n),
        'You must be 18 or older.',
      );
      expect(
        declineReasonMessage('DOCUMENT_NOT_VERIFIED', l10n),
        "We couldn't verify your document. Please try again.",
      );
    });

    test('unknown or missing → the fallback', () {
      expect(declineReasonMessage('NEW_REASON', l10n), l10n.reasonFallback);
      expect(declineReasonMessage(null, l10n), l10n.reasonFallback);
    });
  });

  group('retryTimeMessage', () {
    // 2026-10-31 10:00 in Addis Ababa.
    final now = DateTime.utc(2026, 10, 31, 7);

    test('today: "after HH:mm" in Addis Ababa time', () {
      withClock(Clock.fixed(now), () {
        expect(
          retryTimeMessage(DateTime.utc(2026, 10, 31, 11, 30), l10n),
          'You can try again after 14:30.',
        );
      });
    });

    test('not today: "tomorrow after HH:mm"', () {
      withClock(Clock.fixed(now), () {
        expect(
          retryTimeMessage(DateTime.utc(2026, 11, 1, 6, 15), l10n),
          'You can try again tomorrow after 09:15.',
        );
      });
    });

    test('unknown time: "later"', () {
      expect(retryTimeMessage(null, l10n), 'You can try again later.');
    });
  });
}
