import 'package:frontend/features/reminder/model/reminder_frequency.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';

class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.medName,
    required this.dosage,
    required this.scheduledTime,
    required this.frequency,
    required this.isAlarmEnabled,
    this.caregiverId,
    this.status = ReminderStatus.upcoming,
  });

  final String id;
  final String medName;
  final String dosage;
  final DateTime scheduledTime;
  final ReminderFrequency frequency;
  final bool isAlarmEnabled;
  final String? caregiverId;
  final ReminderStatus status;

  MedicationReminder copyWith({
    String? id,
    String? medName,
    String? dosage,
    DateTime? scheduledTime,
    ReminderFrequency? frequency,
    bool? isAlarmEnabled,
    String? caregiverId,
    ReminderStatus? status,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      medName: medName ?? this.medName,
      dosage: dosage ?? this.dosage,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      frequency: frequency ?? this.frequency,
      isAlarmEnabled: isAlarmEnabled ?? this.isAlarmEnabled,
      caregiverId: caregiverId ?? this.caregiverId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'med_name': medName,
        'dosage': dosage,
        'scheduled_time': scheduledTime.toUtc().toIso8601String(),
        'frequency': frequency.value,
        'is_alarm_enabled': isAlarmEnabled,
        'caregiver_id': caregiverId,
        'status': status.value,
      };

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      id: json['id'] as String,
      medName: json['med_name'] as String,
      dosage: json['dosage'] as String,
      scheduledTime:
          DateTime.parse(json['scheduled_time'] as String).toLocal(),
      frequency: ReminderFrequency.fromValue(
        json['frequency'] as String? ?? 'daily',
      ),
      isAlarmEnabled: json['is_alarm_enabled'] as bool? ?? true,
      caregiverId: json['caregiver_id'] as String?,
      status: ReminderStatus.fromValue(json['status'] as String? ?? 'upcoming'),
    );
  }
}
