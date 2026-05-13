/// Slim representation of a user who shares an accepted connection with someone.
/// Returned by GET /api/connections/by-user/{uid}/caregivers.
class UserConnectionSummary {
  const UserConnectionSummary({
    required this.userUid,
    required this.displayName,
    required this.role,
  });

  final String userUid;
  final String displayName;
  final String role;

  factory UserConnectionSummary.fromJson(Map<String, dynamic> json) {
    return UserConnectionSummary(
      userUid: json['user_uid'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}
