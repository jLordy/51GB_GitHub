/// Clinical profile for a patient, sourced from GET /api/patients.
///
/// Distinct from [UserModel] (auth/identity) — this record holds
/// health-domain data: date of birth, illness type, and the auto-generated
/// Firestore patient_id that links identity to clinical records.
class PatientProfileModel {
  final String patientId;
  final String userUid;
  final String fullName;
  final DateTime dateOfBirth;
  final String illnessType; // 'ckd' | 'diabetes' | 'oncology'

  const PatientProfileModel({
    required this.patientId,
    required this.userUid,
    required this.fullName,
    required this.dateOfBirth,
    required this.illnessType,
  });

  factory PatientProfileModel.fromJson(Map<String, dynamic> json) {
    return PatientProfileModel(
      patientId: json['patient_id'] as String,
      userUid: json['user_uid'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      illnessType: json['illness_type'] as String,
    );
  }

  /// Calculated age in whole years as of today.
  int get age {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years--;
    }
    return years;
  }
}
