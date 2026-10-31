import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/device/device_name.dart';

void main() {
  group('formatDeviceName', () {
    test('capitalises the maker and adds the model', () {
      expect(formatDeviceName('samsung', 'SM-M156B'), 'Samsung SM-M156B');
      expect(formatDeviceName('Google', 'Pixel 8'), 'Google Pixel 8');
    });

    test('skips the maker when the model already starts with it', () {
      expect(formatDeviceName('Xiaomi', 'Xiaomi 13'), 'Xiaomi 13');
      expect(formatDeviceName('xiaomi', 'Xiaomi 13'), 'Xiaomi 13');
    });

    test('works with only one of the two', () {
      expect(formatDeviceName('', 'SM-A145F'), 'SM-A145F');
      expect(formatDeviceName('tecno', ''), 'Tecno');
    });

    test('trims whitespace', () {
      expect(formatDeviceName('  samsung ', ' SM-M156B  '), 'Samsung SM-M156B');
    });

    test('is null when nothing is known', () {
      expect(formatDeviceName('', ''), isNull);
      expect(formatDeviceName('  ', ' '), isNull);
    });

    test('is at most 100 characters (the API limit)', () {
      final name = formatDeviceName('Maker', 'M' * 200)!;
      expect(name.length, maxDeviceNameLength);
      expect(name, startsWith('Maker M'));
    });
  });
}
