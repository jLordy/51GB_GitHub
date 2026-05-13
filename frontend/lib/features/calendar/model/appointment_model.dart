import 'package:flutter/foundation.dart';

import 'doctor_ref_model.dart';
import 'patient_ref_model.dart';

enum AppointmentStatus { scheduled, completed, cancelled, noShow }

enum AppointmentType { patient, special }

@immutable
class AppointmentModel {
  const AppointmentModel({
    required this.appointmentId,
    required this.doctorUid,
    this.patientUid,
    required this.appointmentDate,
    required this.startTime,
    this.endTime,
    this.status = AppointmentStatus.scheduled,
    this.type = AppointmentType.patient,
    this.clinicName,
    this.clinicPlace,
    this.reason,
    this.notes,
    this.doctor,
    this.patient,
    this.createdAt,
    this.updatedAt,
  });

  final String appointmentId;
  final String doctorUid;
  final String? patientUid;
  final DateTime appointmentDate;
  final String startTime;
  final String? endTime;
  final AppointmentStatus status;
  final AppointmentType type;
  final String? clinicName;
  final String? clinicPlace;
  final String? reason;
  final String? notes;
  final DoctorRefModel? doctor;
  final PatientRefModel? patient;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final appointmentDateRaw = json['appointment_date'] as String? ?? '';
    return AppointmentModel(
      appointmentId: json['appointment_id'] as String? ?? '',
      doctorUid: json['doctor_uid'] as String? ?? '',
      patientUid: json['patient_uid'] as String?,
      appointmentDate: DateTime.tryParse(appointmentDateRaw) ?? DateTime.now(),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String?,
      status: _statusFromString(json['status'] as String?),
      type: _typeFromString(json['appointment_type'] as String?),
      clinicName: json['clinic_name'] as String?,
      clinicPlace: json['clinic_place'] as String?,
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      doctor: json['doctor'] is Map<String, dynamic>
          ? DoctorRefModel.fromJson(json['doctor'] as Map<String, dynamic>)
          : null,
      patient: json['patient'] is Map<String, dynamic>
          ? PatientRefModel.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
      createdAt: _parseTs(json['created_at']),
      updatedAt: _parseTs(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'appointment_id': appointmentId,
      'doctor_uid': doctorUid,
      'patient_uid': patientUid,
      'appointment_date': _toIsoDate(appointmentDate),
      'start_time': startTime,
      'end_time': endTime,
      'status': _statusToString(status),
      'appointment_type': _typeToString(type),
      'clinic_name': clinicName,
      'clinic_place': clinicPlace,
      'reason': reason,
      'notes': notes,
      'doctor': doctor?.toJson(),
      'patient': patient?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static AppointmentStatus _statusFromString(String? raw) {
    switch (raw) {
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'no_show':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.scheduled;
    }
  }

  static String _statusToString(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.noShow:
        return 'no_show';
      case AppointmentStatus.scheduled:
        return 'scheduled';
    }
  }

  static AppointmentType _typeFromString(String? raw) {
    switch (raw) {
      case 'special':
        return AppointmentType.special;
      default:
        return AppointmentType.patient;
    }
  }

  static String _typeToString(AppointmentType type) {
    switch (type) {
      case AppointmentType.special:
        return 'special';
      case AppointmentType.patient:
        return 'patient';
    }
  }

  static DateTime? _parseTs(dynamic raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  static String _toIsoDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().substring(0, 10);
  }
}
