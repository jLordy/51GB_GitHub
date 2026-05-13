import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.read(apiClientProvider));
});

class OnboardingRepository {
  OnboardingRepository(this._apiClient);

  final ApiClient _apiClient;

  /// POST /api/patients/self-register — create the patient's own health profile
  /// including the intake questionnaire answers collected during onboarding.
  Future<void> selfRegister({
    required String fullName,
    required DateTime dateOfBirth,
    required List<String> illnessTypes,
    String? illnessOther,
    // Intake profile fields
    required String biologicalSex,
    required String ethnicity,
    required bool hasAllergies,
    required List<String> allergyMedications,
    required List<String> allergyFood,
    required List<String> allergyEnvironmental,
    required double tobaccoPackYears,
    required double alcoholWeeklyFrequency,
    required String livingSituation,
    required String supportSystemStrength,
    required bool hasFamilyHistory,
    required List<String> familyConditions,
  }) async {
    await _apiClient.post(
      '/api/patients/self-register',
      body: {
        'full_name': fullName,
        'date_of_birth':
            '${dateOfBirth.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth.day.toString().padLeft(2, '0')}',
        'illness_type': illnessTypes,
        'illness_other': illnessOther,
        'intake_profile': {
          'biological_sex': biologicalSex,
          'ethnicity': ethnicity,
          'has_allergies': hasAllergies,
          'allergy_medications': allergyMedications,
          'allergy_food': allergyFood,
          'allergy_environmental': allergyEnvironmental,
          'tobacco_pack_years': tobaccoPackYears,
          'alcohol_weekly_frequency': alcoholWeeklyFrequency,
          'living_situation': livingSituation,
          'support_system_strength': supportSystemStrength,
          'has_family_history': hasFamilyHistory,
          'family_history_conditions': familyConditions,
        },
      },
    );
  }
}
