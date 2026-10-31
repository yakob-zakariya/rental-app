import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_app/core/storage/auth_tokens.dart';
import 'package:rental_app/core/storage/token_storage.dart';

/// A fake FlutterSecureStorage: `when(...)` decides what each call returns,
/// `verify(...)` checks what was called (like jest.fn() in JavaScript).
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _key = TokenStorage.storageKey;
const _tokens = AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

void main() {
  late MockSecureStorage secure;
  late TokenStorage storage;

  void stored(String? value) {
    when(() => secure.read(key: _key)).thenAnswer((_) async => value);
  }

  setUp(() {
    secure = MockSecureStorage();
    storage = TokenStorage(secure);
    when(
      () => secure.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => secure.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  group('write', () {
    test('stores both tokens in a single write under one key', () async {
      await storage.write(_tokens);

      final value =
          verify(
                () => secure.write(
                  key: _key,
                  value: captureAny(named: 'value'),
                ),
              ).captured.single
              as String;
      expect(jsonDecode(value), {
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
      });
      // Exactly one write: the pair can never be half-updated.
      verifyNever(
        () => secure.write(
          key: any(named: 'key', that: isNot(_key)),
          value: any(named: 'value'),
        ),
      );
    });
  });

  group('read', () {
    test('returns the stored tokens', () async {
      stored(jsonEncode({'accessToken': 'a', 'refreshToken': 'r'}));

      final tokens = await storage.read();

      expect(tokens?.accessToken, 'a');
      expect(tokens?.refreshToken, 'r');
      verifyNever(() => secure.delete(key: any(named: 'key')));
    });

    test('returns null when nothing is stored (signed out)', () async {
      stored(null);

      expect(await storage.read(), isNull);
      verifyNever(() => secure.delete(key: any(named: 'key')));
    });

    final broken = {
      'not JSON': 'not json at all',
      'a JSON list': '[1, 2]',
      'missing refreshToken': jsonEncode({'accessToken': 'a'}),
      'missing accessToken': jsonEncode({'refreshToken': 'r'}),
      'empty accessToken': jsonEncode({'accessToken': '', 'refreshToken': 'r'}),
      'non-string token': jsonEncode({'accessToken': 1, 'refreshToken': 'r'}),
    };
    for (final MapEntry(key: name, value: raw) in broken.entries) {
      test('a broken value ($name) → null, and it is wiped', () async {
        stored(raw);

        expect(await storage.read(), isNull);
        verify(() => secure.delete(key: _key)).called(1);
      });
    }

    test('secure storage failing (e.g. key lost) → null, and wiped', () async {
      when(() => secure.read(key: _key))
          .thenThrow(PlatformException(code: 'InvalidKeyException'));

      expect(await storage.read(), isNull);
      verify(() => secure.delete(key: _key)).called(1);
    });

    test('a failing wipe after a broken read is not fatal', () async {
      stored('broken');
      when(() => secure.delete(key: _key))
          .thenThrow(PlatformException(code: 'error'));

      expect(await storage.read(), isNull);
    });
  });

  group('clear', () {
    test('deletes only our key (not everything)', () async {
      await storage.clear();

      verify(() => secure.delete(key: _key)).called(1);
      verifyNever(() => secure.deleteAll());
    });
  });

  test('AuthTokens.toString() never contains a token', () {
    const tokens = AuthTokens(
      accessToken: 'eyJsecret-access',
      refreshToken: 'eyJsecret-refresh',
    );

    expect(tokens.toString(), 'AuthTokens(***)');
    expect('$tokens', isNot(contains('secret')));
  });
}
