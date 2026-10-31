/// Every error the app gets from an API call.
///
/// Screens switch on [code] (hard rule 3) — never on a message text.
class ApiError implements Exception {
  const ApiError(
    this.code, {
    this.statusCode,
    this.retryAfterSeconds,
    this.attemptsRemaining,
    this.manualReviewAvailable,
  });

  /// The API's error code (see [ApiErrorCode]), or one of the app's own:
  /// [ApiErrorCode.networkError] / [ApiErrorCode.unknownError].
  ///
  /// A code the app doesn't know yet is kept as-is; screens show generic
  /// fallback text for it.
  final String code;

  /// The HTTP status, or `null` when no response arrived (network errors).
  final int? statusCode;

  /// Seconds to wait before retrying (body `retryAfterSeconds`, else the
  /// `Retry-After` header).
  final int? retryAfterSeconds;

  /// `OTP_INVALID`: wrong tries left for this code.
  final int? attemptsRemaining;

  /// `VERIFICATION_RETRY_LIMIT`: a manual review may be requested.
  final bool? manualReviewAvailable;

  /// Network failures (no connection, timeouts): "check your connection".
  bool get isNetworkError => code == ApiErrorCode.networkError;

  @override
  String toString() =>
      'ApiError($code, statusCode: $statusCode, '
      'retryAfterSeconds: $retryAfterSeconds)';
}

/// Error codes, copied exactly from `docs/api-for-mobile.md`.
///
/// Compare against these constants instead of typing the strings by hand.
abstract final class ApiErrorCode {
  // Any request body
  static const validationFailed = 'VALIDATION_FAILED';

  // Sign-in
  static const invalidPhone = 'INVALID_PHONE';
  static const otpInvalid = 'OTP_INVALID';
  static const otpExpired = 'OTP_EXPIRED';
  static const otpAttemptsExceeded = 'OTP_ATTEMPTS_EXCEEDED';
  static const otpRateLimited = 'OTP_RATE_LIMITED';
  static const rateLimited = 'RATE_LIMITED';
  static const smsSendFailed = 'SMS_SEND_FAILED';

  // Tokens and accounts
  static const unauthenticated = 'UNAUTHENTICATED';
  static const accessTokenExpired = 'ACCESS_TOKEN_EXPIRED';
  static const invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const accountUnavailable = 'ACCOUNT_UNAVAILABLE';

  // Identity verification
  static const alreadyVerified = 'ALREADY_VERIFIED';
  static const verificationInReview = 'VERIFICATION_IN_REVIEW';
  static const verificationUnavailable = 'VERIFICATION_UNAVAILABLE';
  static const verificationRetryLimit = 'VERIFICATION_RETRY_LIMIT';
  static const verificationProviderUnavailable =
      'VERIFICATION_PROVIDER_UNAVAILABLE';
  static const manualReviewNotAvailable = 'MANUAL_REVIEW_NOT_AVAILABLE';

  // The app's own codes (never sent by the API)
  /// No connection, or a timeout.
  static const networkError = 'NETWORK_ERROR';

  /// A response without a readable `code` (e.g. an ngrok or proxy error page).
  static const unknownError = 'UNKNOWN_ERROR';

  /// Every code the API can send, from the contract's error table.
  static const fromApi = [
    validationFailed,
    invalidPhone,
    otpInvalid,
    otpExpired,
    otpAttemptsExceeded,
    otpRateLimited,
    rateLimited,
    smsSendFailed,
    unauthenticated,
    accessTokenExpired,
    invalidRefreshToken,
    accountUnavailable,
    alreadyVerified,
    verificationInReview,
    verificationUnavailable,
    verificationRetryLimit,
    verificationProviderUnavailable,
    manualReviewNotAvailable,
  ];
}
