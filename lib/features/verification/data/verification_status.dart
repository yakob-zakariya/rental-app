/// `status` from `GET /verification/status` and `GET /me`.
enum VerificationStatus {
  notVerified('not_verified'),
  pending('pending'),
  approved('approved'),
  declined('declined'),
  manualReview('manual_review'),
  blocked('blocked'),

  /// A status this app version doesn't know: shown with fallback text.
  unknown('');

  const VerificationStatus(this.apiValue);

  final String apiValue;

  static VerificationStatus fromApi(String value) => values.firstWhere(
    (s) => s.apiValue == value && s != unknown,
    orElse: () => unknown,
  );
}

/// The verification state from `GET /verification/status`. What the user may
/// do next ([canRetry], [canRequestManualReview]) comes from the API, never
/// from app logic (hard rule 7).
class VerificationSummary {
  const VerificationSummary({
    required this.status,
    required this.canRetry,
    required this.retriesLeftToday,
    required this.canRequestManualReview,
    this.retryAvailableAt,
    this.reasonCode,
  });

  /// Throws a [FormatException] if [json] doesn't have the contract's shape.
  factory VerificationSummary.fromJson(Map<String, Object?> json) {
    final status = json['status'];
    final canRetry = json['canRetry'];
    final retriesLeftToday = json['retriesLeftToday'];
    final canRequestManualReview = json['canRequestManualReview'];
    final retryAvailableAt = json['retryAvailableAt'];
    final reasonCode = json['reasonCode'];

    if (status is! String ||
        canRetry is! bool ||
        retriesLeftToday is! int ||
        canRequestManualReview is! bool ||
        (retryAvailableAt != null && retryAvailableAt is! String) ||
        (reasonCode != null && reasonCode is! String)) {
      throw const FormatException('Unexpected verification status');
    }

    return VerificationSummary(
      status: VerificationStatus.fromApi(status),
      canRetry: canRetry,
      retriesLeftToday: retriesLeftToday,
      canRequestManualReview: canRequestManualReview,
      retryAvailableAt: retryAvailableAt == null
          ? null
          : parseUtcTimestamp(retryAvailableAt as String),
      reasonCode: reasonCode as String?,
    );
  }

  final VerificationStatus status;

  /// "Verify" would start or resume a session right now.
  final bool canRetry;

  /// New sessions left in the rolling 24 hours.
  final int retriesLeftToday;

  /// "Request manual review" would be accepted now.
  final bool canRequestManualReview;

  /// When a new session can start (only when out of tries), in UTC.
  final DateTime? retryAvailableAt;

  /// Why it was declined (only for [VerificationStatus.declined]). Kept as
  /// text, so a code this app doesn't know yet still arrives (fallback text).
  final String? reasonCode;
}

/// Parses an API timestamp (ISO 8601 in UTC, e.g. `2026-10-31T09:12:33.123Z`).
DateTime parseUtcTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Not a UTC timestamp: $value');
  }
  return parsed;
}
