import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/time/addis_time.dart';

void main() {
  group('formatAddisTime (UTC+3, no daylight saving)', () {
    test('adds 3 hours', () {
      expect(formatAddisTime(DateTime.utc(2026, 10, 31, 11, 30)), '14:30');
    });

    test('crosses midnight', () {
      expect(formatAddisTime(DateTime.utc(2026, 10, 31, 22, 15)), '01:15');
    });

    test('pads with zeros', () {
      expect(formatAddisTime(DateTime.utc(2026, 10, 31, 5, 7)), '08:07');
    });

    test('is the same in summer and winter (no DST)', () {
      expect(formatAddisTime(DateTime.utc(2026, 1, 15, 9)), '12:00');
      expect(formatAddisTime(DateTime.utc(2026, 7, 15, 9)), '12:00');
    });
  });

  group('isTodayInAddis', () {
    // 2026-10-31 10:00 in Addis Ababa.
    final now = DateTime.utc(2026, 10, 31, 7);

    test('later today', () {
      withClock(Clock.fixed(now), () {
        // 23:59 in Addis Ababa.
        expect(isTodayInAddis(DateTime.utc(2026, 10, 31, 20, 59)), isTrue);
      });
    });

    test('after midnight in Addis Ababa, though still the same UTC date', () {
      withClock(Clock.fixed(now), () {
        // 21:30 UTC = 00:30 on 1 November in Addis Ababa.
        expect(isTodayInAddis(DateTime.utc(2026, 10, 31, 21, 30)), isFalse);
      });
    });
  });
}
