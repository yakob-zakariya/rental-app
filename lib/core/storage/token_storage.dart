import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_tokens.dart';

/// Keeps the token pair in secure storage — the only place tokens may live
/// (hard rule 1). On Android, secure storage encrypts with a key held by the
/// Android Keystore, so the key never leaves the phone.
///
/// Both tokens are saved together as one value under one key: a single write,
/// so the app can never be left with a new access token next to an old,
/// already-revoked refresh token.
class TokenStorage {
  TokenStorage(this._storage);

  static const storageKey = 'auth_tokens';

  final FlutterSecureStorage _storage;

  /// The stored tokens, or `null` when signed out.
  ///
  /// A broken value (unreadable, half-written, wrong shape) is wiped and
  /// treated as signed out: the user simply signs in again. Nothing is logged.
  Future<AuthTokens?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: storageKey);
    } on Exception {
      // e.g. the Keystore key is gone (after a backup restore).
      await _clearQuietly();
      return null;
    }
    if (raw == null) return null;

    final tokens = _decode(raw);
    if (tokens == null) await _clearQuietly();
    return tokens;
  }

  /// Stores both tokens, replacing any previous pair.
  Future<void> write(AuthTokens tokens) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode({
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
      }),
    );
  }

  /// Deletes the tokens (sign-out).
  Future<void> clear() => _storage.delete(key: storageKey);

  Future<void> _clearQuietly() async {
    try {
      await clear();
    } on Exception {
      // Nothing more we can do; the next read will try again.
    }
  }

  static AuthTokens? _decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;

    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    if (access is! String || access.isEmpty) return null;
    if (refresh is! String || refresh.isEmpty) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
