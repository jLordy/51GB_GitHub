enum RegistrationRole { patient, doctor, secretary, caregiver }

class RegisterRequest {
  final String email;
  final String password;
  final String displayName;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim(),
      'password': password,
      'display_name': displayName.trim(),
    };
  }
}