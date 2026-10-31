import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/core/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('accepts an http URL (emulator → local backend)', () {
      final config = AppConfig.parse('http://10.0.2.2:3000');

      expect(config.apiBaseUrl.scheme, 'http');
      expect(config.apiBaseUrl.host, '10.0.2.2');
      expect(config.apiBaseUrl.port, 3000);
    });

    test('accepts an https URL (ngrok tunnel)', () {
      final config = AppConfig.parse('https://example.ngrok-free.dev');

      expect(config.apiBaseUrl.host, 'example.ngrok-free.dev');
    });

    test('trims surrounding whitespace', () {
      final config = AppConfig.parse('  http://localhost:3000  ');

      expect(config.apiBaseUrl.host, 'localhost');
    });

    test('rejects an empty value (define missing)', () {
      expect(() => AppConfig.parse(''), throwsA(isA<AppConfigException>()));
      expect(() => AppConfig.parse('   '), throwsA(isA<AppConfigException>()));
    });

    test('rejects a value without a scheme', () {
      expect(
        () => AppConfig.parse('10.0.2.2:3000'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects a non-http scheme', () {
      expect(
        () => AppConfig.parse('ftp://example.com'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects a URL without a host', () {
      expect(
        () => AppConfig.parse('http://'),
        throwsA(isA<AppConfigException>()),
      );
    });
  });
}
