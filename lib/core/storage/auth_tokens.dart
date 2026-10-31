/// The signed-in user's token pair from `POST /auth/otp/verify` or
/// `POST /auth/refresh`. Always stored and replaced together (hard rule 4).
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  /// Never prints the tokens, so a stray `print(tokens)` or an error message
  /// can't leak them (hard rule 2).
  @override
  String toString() => 'AuthTokens(***)';
}
