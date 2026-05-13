class UserModel {
  final String uid;
  final String? email;
  final String role;
  final String status;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final bool isPrivate;
  final bool notificationsEnabled;

  const UserModel({
    required this.uid,
    this.email,
    required this.role,
    required this.status,
    this.displayName,
    this.photoUrl,
    this.bio,
    this.dateOfBirth,
    this.isPrivate = false,
    this.notificationsEnabled = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? dob;
    final rawDob = json['date_of_birth'];
    if (rawDob is String && rawDob.isNotEmpty) {
      dob = DateTime.tryParse(rawDob);
    }
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      status: (json['status'] as String?) ?? '',
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String?,
      dateOfBirth: dob,
      isPrivate: (json['is_private'] as bool?) ?? false,
      notificationsEnabled: (json['notifications_enabled'] as bool?) ?? true,
    );
  }
}