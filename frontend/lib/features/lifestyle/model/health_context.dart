import 'package:frontend/features/journal/model/journal_entry_model.dart';

/// Aggregated health snapshot derived from the user's most recent journal entries.
/// This is computed in-memory from journal data — no dedicated backend endpoint needed.
class HealthContext {
  const HealthContext({
    required this.illnessType,
    this.overallCondition,
    this.energyLevel,
    this.systolicBP,
    this.diastolicBP,
  });

  final String illnessType;
  final String? overallCondition; // 'better' | 'same' | 'worse'
  final String? energyLevel;      // 'high' | 'moderate' | 'low'
  final int? systolicBP;
  final int? diastolicBP;

  bool get isEmpty => illnessType.isEmpty;

  String get displayName {
    switch (illnessType.toLowerCase()) {
      case 'diabetes':
        return 'Diabetes';
      case 'ckd':
        return 'Kidney Disease (CKD)';
      case 'hypertension':
        return 'Hypertension';
      case 'heart_disease':
        return 'Heart Disease';
      case 'stroke':
        return 'Stroke Recovery';
      case 'cancer':
      case 'oncology':
        return 'Cancer Care';
      case 'asthma':
        return 'Asthma';
      case 'tuberculosis':
        return 'Tuberculosis';
      case 'arthritis':
        return 'Arthritis';
      case 'mental_health':
        return 'Mental Health';
      default:
        return illnessType.isEmpty ? 'General Wellness' : illnessType;
    }
  }

  /// Derive a HealthContext from the user's journal history.
  /// Uses the most recent entry that has a non-empty illness type.
  static HealthContext fromEntries(List<JournalEntryModel> entries) {
    if (entries.isEmpty) return const HealthContext(illnessType: '');

    // entries are newest-first from the API
    final recent = entries.firstWhere(
      (e) => e.illnessType.isNotEmpty,
      orElse: () => entries.first,
    );

    final answers = recent.answers;
    final bp = answers['blood_pressure'];
    int? systolic, diastolic;
    if (bp is Map) {
      systolic = (bp['systolic'] as num?)?.toInt();
      diastolic = (bp['diastolic'] as num?)?.toInt();
    }

    return HealthContext(
      illnessType: recent.illnessType,
      overallCondition: answers['overall_condition'] as String?,
      energyLevel: answers['energy_level'] as String?,
      systolicBP: systolic,
      diastolicBP: diastolic,
    );
  }
}
