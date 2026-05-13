import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/features/connections/model/user_connection_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepository(ref.read(apiClientProvider));
});

class ConnectionRepository {
  ConnectionRepository(this._apiClient);

  final ApiClient _apiClient;

  // ── User browsing ───────────────────────────────────────────────────────

  /// Returns all active doctors and caregivers for the connection picker.
  Future<List<UserModel>> browseDoctorsAndCaregivers() async {
    final response = await _apiClient.get(
      '/api/users/browse',
      requiresAuth: true,
    );

    final dynamic data = response.data;
    if (data is! List) return const <UserModel>[];

    return data
        .whereType<Map>()
        .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Fetches a single patient's clinical profile by their Firebase UID.
  /// Uses GET /api/patients/by-uid/{userUid} — accessible to doctors/admins.
  /// Returns null if no profile exists for that UID.
  Future<PatientProfileModel?> fetchPatientProfileByUid(String userUid) async {
    try {
      final response = await _apiClient.get(
        '/api/patients/by-uid/$userUid',
        requiresAuth: true,
      );
      final dynamic data = response.data;
      if (data is! Map) return null;
      return PatientProfileModel.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Returns all active patients — used by doctors/caregivers to display
  /// the profiles of people connected to them.
  Future<List<UserModel>> browsePatients() async {
    final response = await _apiClient.get(
      '/api/users/browse-patients',
      requiresAuth: true,
    );

    final dynamic data = response.data;
    if (data is! List) return const <UserModel>[];

    return data
        .whereType<Map>()
        .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Returns all active secretaries — used to resolve requester names
  /// in incoming connection requests.
  Future<List<UserModel>> browseSecretaries() async {
    final response = await _apiClient.get(
      '/api/users/browse-secretaries',
      requiresAuth: true,
    );

    final dynamic data = response.data;
    if (data is! List) return const <UserModel>[];

    return data
        .whereType<Map>()
        .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ── Connection CRUD ─────────────────────────────────────────────────────

  Future<ConnectionModel> sendRequest(String recipientUid) async {
    final response = await _apiClient.post(
      '/api/connections',
      body: <String, dynamic>{'recipient_uid': recipientUid},
      requiresAuth: true,
    );
    return ConnectionModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<ConnectionModel>> fetchAccepted() async {
    final response = await _apiClient.get(
      '/api/connections',
      queryParameters: <String, dynamic>{'status': 'accepted'},
      requiresAuth: true,
    );
    final dynamic data = response.data;
    if (data is! List) return const <ConnectionModel>[];
    return data
        .whereType<Map>()
        .map((m) => ConnectionModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<ConnectionModel>> fetchPendingIncoming() async {
    final response = await _apiClient.get(
      '/api/connections/pending',
      requiresAuth: true,
    );
    final dynamic data = response.data;
    if (data is! List) return const <ConnectionModel>[];
    return data
        .whereType<Map>()
        .map((m) => ConnectionModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<ConnectionModel> acceptConnection(String connectionId) async {
    final response = await _apiClient.patch(
      '/api/connections/$connectionId/accept',
      requiresAuth: true,
    );
    return ConnectionModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ConnectionModel> declineConnection(String connectionId) async {
    final response = await _apiClient.patch(
      '/api/connections/$connectionId/decline',
      requiresAuth: true,
    );
    return ConnectionModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> removeConnection(String connectionId) async {
    await _apiClient.delete(
      '/api/connections/$connectionId',
      requiresAuth: true,
    );
  }

  /// Returns the caregivers who share an accepted connection with [userUid].
  /// The calling user must themselves be accepted-connected to [userUid].
  /// Returns an empty list on failure or 403 (no caregiver).
  Future<List<UserConnectionSummary>> fetchCaregiversForUser(
    String userUid,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/connections/by-user/$userUid/caregivers',
        requiresAuth: true,
      );
      final dynamic data = response.data;
      if (data is! List) return const <UserConnectionSummary>[];
      return data
          .whereType<Map>()
          .map(
            (m) => UserConnectionSummary.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return const <UserConnectionSummary>[];
    }
  }

  /// Returns the patients of [doctorUid] as seen by the current secretary.
  /// The backend enforces that the secretary must be connected to [doctorUid].
  /// Returns an empty list on failure or 403.
  Future<List<UserModel>> fetchPatientsForDoctorAsSecretary(
    String doctorUid,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/calendar/secretary/doctor/$doctorUid/patients',
        requiresAuth: true,
      );
      final dynamic data = response.data;
      if (data is! List) return const <UserModel>[];
      final parsed = <UserModel>[];
      for (final m in data.whereType<Map>()) {
        try {
          parsed.add(UserModel.fromJson(Map<String, dynamic>.from(m)));
        } catch (_) {
          // Skip malformed entries so the rest are still returned.
        }
      }
      return parsed;
    } catch (_) {
      return const <UserModel>[];
    }
  }

  /// Returns doctors connected to [secretaryUid].
  /// Public endpoint — no auth required, works for guest/anonymous users too.
  Future<List<UserModel>> fetchDoctorsForSecretary(String secretaryUid) async {
    try {
      final response = await _apiClient.get(
        '/api/connections/secretary/$secretaryUid/doctors',
        requiresAuth: false,
      );
      final dynamic data = response.data;
      if (data is! List) return const <UserModel>[];
      return data
          .whereType<Map>()
          .map((m) => UserModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const <UserModel>[];
    }
  }

  /// Returns the doctors who share an accepted connection with [userUid].
  /// The calling user must themselves be accepted-connected to [userUid].
  /// Returns an empty list on failure or 403 (no doctor).
  Future<List<UserConnectionSummary>> fetchDoctorsForUser(
    String userUid,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/connections/by-user/$userUid/doctors',
        requiresAuth: true,
      );
      final dynamic data = response.data;
      if (data is! List) return const <UserConnectionSummary>[];
      return data
          .whereType<Map>()
          .map(
            (m) => UserConnectionSummary.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return const <UserConnectionSummary>[];
    }
  }

  /// Returns secretaries accepted-connected to [userUid] (typically a doctor).
  /// The calling user must be accepted-connected to [userUid].
  /// Returns an empty list on failure or 403.
  Future<List<UserConnectionSummary>> fetchSecretariesForUser(
    String userUid,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/connections/by-user/$userUid/secretaries',
        requiresAuth: true,
      );
      final dynamic data = response.data;
      if (data is! List) return const <UserConnectionSummary>[];
      return data
          .whereType<Map>()
          .map(
            (m) => UserConnectionSummary.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return const <UserConnectionSummary>[];
    }
  }

  /// Returns secretaries connected to the doctors of [patientUid].
  /// The calling user must be accepted-connected to [patientUid].
  /// Returns an empty list on failure or 403.
  Future<List<UserConnectionSummary>> fetchDoctorSecretariesForPatient(
    String patientUid,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/connections/by-user/$patientUid/doctor-secretaries',
        requiresAuth: true,
      );
      final dynamic data = response.data;
      if (data is! List) return const <UserConnectionSummary>[];
      return data
          .whereType<Map>()
          .map(
            (m) => UserConnectionSummary.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    } catch (_) {
      return const <UserConnectionSummary>[];
    }
  }
}
