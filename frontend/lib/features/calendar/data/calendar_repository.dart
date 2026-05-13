import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controller/auth_provider.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.read(apiClientProvider));
});

class CalendarRepository {
  const CalendarRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppointmentModel>> fetchDoctorAppointmentsByDate({
    required DateTime date,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/doctor/appointments',
      queryParameters: <String, dynamic>{'date': _toIsoDate(date)},
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchCaregiverAppointmentsByDate({
    required DateTime date,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/caregiver/appointments',
      queryParameters: <String, dynamic>{'date': _toIsoDate(date)},
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchSecretaryAppointmentsByDate({
    required DateTime date,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/secretary/appointments',
      queryParameters: <String, dynamic>{'date': _toIsoDate(date)},
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<UserModel>> fetchConnectedDoctorsForSecretary() async {
    final response = await _apiClient.get(
      '/api/calendar/secretary/doctors',
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <UserModel>[];
    return data
        .whereType<Map>()
        .map((raw) => UserModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<UserModel>> fetchPatientsForDoctorAsSecretary(
    String doctorUid,
  ) async {
    final response = await _apiClient.get(
      '/api/calendar/secretary/doctor/$doctorUid/patients',
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <UserModel>[];
    return data
        .whereType<Map>()
        .map((raw) => UserModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<void> createAppointmentAsSecretary({
    required String doctorUid,
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    await _apiClient.post(
      '/api/calendar/secretary/appointments',
      body: <String, dynamic>{
        'doctor_uid': doctorUid,
        'patient_uid': patientUid,
        'appointment_date': _toIsoDate(appointmentDate),
        'start_time': startTime,
        'end_time': endTime,
        'appointment_type': _typeToWire(type),
        'clinic_name': clinicName,
        'clinic_place': clinicPlace,
        'reason': reason,
        'notes': notes,
      },
      requiresAuth: true,
    );
  }

  Future<void> updateAppointmentStatusAsSecretary({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    await _apiClient.patch(
      '/api/calendar/secretary/appointments/$appointmentId/status',
      body: <String, dynamic>{'status': _statusToWire(status)},
      requiresAuth: true,
    );
  }

  Future<List<AppointmentModel>> fetchPatientAppointmentsByDate({
    required DateTime date,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/patient/appointments',
      queryParameters: <String, dynamic>{'date': _toIsoDate(date)},
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchDoctorAppointmentsByRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/doctor/appointments/range',
      queryParameters: <String, dynamic>{
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
      },
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<void> createAppointment({
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    await _apiClient.post(
      '/api/calendar/doctor/appointments',
      body: <String, dynamic>{
        'patient_uid': patientUid,
        'appointment_date': _toIsoDate(appointmentDate),
        'start_time': startTime,
        'end_time': endTime,
        'appointment_type': _typeToWire(type),
        'clinic_name': clinicName,
        'clinic_place': clinicPlace,
        'reason': reason,
        'notes': notes,
      },
      requiresAuth: true,
    );
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required AppointmentStatus status,
  }) async {
    await _apiClient.patch(
      '/api/calendar/doctor/appointments/$appointmentId/status',
      body: <String, dynamic>{'status': _statusToWire(status)},
      requiresAuth: true,
    );
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await _apiClient.patch(
      '/api/calendar/doctor/appointments/$appointmentId/status',
      body: const <String, dynamic>{'status': 'cancelled'},
      requiresAuth: true,
    );
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _apiClient.delete(
      '/api/calendar/doctor/appointments/$appointmentId',
      requiresAuth: true,
    );
  }

  Future<void> deleteAppointmentAsSecretary(String appointmentId) async {
    await _apiClient.delete(
      '/api/calendar/secretary/appointments/$appointmentId',
      requiresAuth: true,
    );
  }

  Future<void> updateAppointment({
    required String appointmentId,
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    await _apiClient.patch(
      '/api/calendar/doctor/appointments/$appointmentId',
      body: <String, dynamic>{
        'patient_uid': patientUid,
        'appointment_date': _toIsoDate(appointmentDate),
        'start_time': startTime,
        'end_time': endTime,
        'appointment_type': _typeToWire(type),
        'clinic_name': clinicName,
        'clinic_place': clinicPlace,
        'reason': reason,
        'notes': notes,
      },
      requiresAuth: true,
    );
  }

  Future<void> updateAppointmentAsSecretary({
    required String appointmentId,
    String? patientUid,
    required DateTime appointmentDate,
    required String startTime,
    String? endTime,
    AppointmentType type = AppointmentType.patient,
    String? clinicName,
    String? clinicPlace,
    String? reason,
    String? notes,
  }) async {
    await _apiClient.patch(
      '/api/calendar/secretary/appointments/$appointmentId',
      body: <String, dynamic>{
        'patient_uid': patientUid,
        'appointment_date': _toIsoDate(appointmentDate),
        'start_time': startTime,
        'end_time': endTime,
        'appointment_type': _typeToWire(type),
        'clinic_name': clinicName,
        'clinic_place': clinicPlace,
        'reason': reason,
        'notes': notes,
      },
      requiresAuth: true,
    );
  }

  /// Fetches a doctor's public clinic schedule for a given date.
  /// Returns only [AppointmentType.special] entries — no patient data.
  Future<List<AppointmentModel>> fetchPublicDoctorSchedule({
    required String doctorUid,
    required DateTime date,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/public/${doctorUid.trim()}/schedule',
      queryParameters: <String, dynamic>{'date': _toIsoDate(date)},
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchPatientAppointmentsByRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/patient/appointments/range',
      queryParameters: <String, dynamic>{
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
      },
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchCaregiverAppointmentsByRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/caregiver/appointments/range',
      queryParameters: <String, dynamic>{
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
      },
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchSecretaryAppointmentsByRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/secretary/appointments/range',
      queryParameters: <String, dynamic>{
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
      },
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<List<AppointmentModel>> fetchPublicDoctorScheduleByRange({
    required String doctorUid,
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _apiClient.get(
      '/api/calendar/public/${doctorUid.trim()}/schedule/range',
      queryParameters: <String, dynamic>{
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
      },
      requiresAuth: true,
    );

    final data = response.data;
    if (data is! List) return const <AppointmentModel>[];
    return data
        .whereType<Map>()
        .map((raw) => AppointmentModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  static String _toIsoDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().substring(0, 10);
  }

  static String _statusToWire(AppointmentStatus status) {
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

  static String _typeToWire(AppointmentType type) {
    switch (type) {
      case AppointmentType.special:
        return 'special';
      case AppointmentType.patient:
        return 'patient';
    }
  }
}
