import '../../verification/data/verification_status.dart';

/// The signed-in user, from `GET /me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.preferredLanguage,
    required this.verificationStatus,
    required this.createdAt,
    this.fullName,
    this.dateOfBirth,
    this.verifiedAt,
  });

  /// Throws a [FormatException] if [json] doesn't have the contract's shape.
  factory UserProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final phone = json['phone'];
    final fullName = json['fullName'];
    final dateOfBirth = json['dateOfBirth'];
    final preferredLanguage = json['preferredLanguage'];
    final verificationStatus = json['verificationStatus'];
    final verifiedAt = json['verifiedAt'];
    final createdAt = json['createdAt'];

    if (id is! String ||
        phone is! String ||
        preferredLanguage is! String ||
        verificationStatus is! String ||
        createdAt is! String ||
        (fullName != null && fullName is! String) ||
        (dateOfBirth != null && dateOfBirth is! String) ||
        (verifiedAt != null && verifiedAt is! String)) {
      throw const FormatException('Unexpected profile');
    }

    return UserProfile(
      id: id,
      phone: phone,
      fullName: fullName as String?,
      dateOfBirth: dateOfBirth as String?,
      preferredLanguage: preferredLanguage,
      verificationStatus: VerificationStatus.fromApi(verificationStatus),
      verifiedAt: verifiedAt == null
          ? null
          : parseUtcTimestamp(verifiedAt as String),
      createdAt: parseUtcTimestamp(createdAt),
    );
  }

  final String id;

  /// E.164, e.g. `+251911234567`.
  final String phone;

  /// From identity verification; `null` until approved. Not editable.
  final String? fullName;

  /// A plain `YYYY-MM-DD` string — never parsed into a `DateTime` (no time
  /// zone may shift it). Shown exactly as received.
  final String? dateOfBirth;

  /// `am`, `om` or `en`.
  final String preferredLanguage;
  final VerificationStatus verificationStatus;

  /// UTC.
  final DateTime? verifiedAt;

  /// UTC.
  final DateTime createdAt;

  /// Never prints identity data (hard rule 2).
  @override
  String toString() => 'UserProfile($id)';
}
