import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/report/model/report_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.read(apiClientProvider));
});

class ReportRepository {
  ReportRepository(this._apiClient);

  final ApiClient _apiClient;

  // -------------------------------------------------------------------------
  // Patient-scoped endpoints (no patientUid prefix)
  // -------------------------------------------------------------------------

  /// POST /api/reports/generate — returns the diary text without saving.
  Future<String> generateSummary({
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    final response = await _apiClient.post(
      '/api/reports/generate',
      body: {'start_date': startDate, 'end_date': endDate, 'period': period},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['content'] as String?) ?? '';
  }

  /// POST /api/reports — saves a new report for the calling patient.
  Future<ReportModel> saveReport({
    required String startDate,
    required String endDate,
    required String period,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/api/reports',
      body: {
        'start_date': startDate,
        'end_date': endDate,
        'period': period,
        'content': content,
      },
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/reports — lists saved reports for the calling patient.
  Future<List<ReportModel>> listReports() async {
    final response = await _apiClient.get('/api/reports');
    final data = response.data as Map<String, dynamic>;
    final rawList = (data['reports'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/reports/{reportId}
  Future<ReportModel> getReport(String reportId) async {
    final response = await _apiClient.get('/api/reports/$reportId');
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /api/reports/{reportId}
  Future<ReportModel> updateReport({
    required String reportId,
    required String content,
  }) async {
    final response = await _apiClient.patch(
      '/api/reports/$reportId',
      body: {'content': content},
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// DELETE /api/reports/{reportId}
  Future<void> deleteReport(String reportId) async {
    await _apiClient.delete('/api/reports/$reportId', requiresAuth: true);
  }

  // -------------------------------------------------------------------------
  // Professional-scoped endpoints (patientUid prefix required)
  // -------------------------------------------------------------------------

  /// POST /api/reports/patients/{patientUid}/generate
  Future<String> generatePatientSummary({
    required String patientUid,
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    final response = await _apiClient.post(
      '/api/reports/patients/$patientUid/generate',
      body: {'start_date': startDate, 'end_date': endDate, 'period': period},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['content'] as String?) ?? '';
  }

  /// POST /api/reports/patients/{patientUid}
  Future<ReportModel> savePatientReport({
    required String patientUid,
    required String startDate,
    required String endDate,
    required String period,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/api/reports/patients/$patientUid',
      body: {
        'start_date': startDate,
        'end_date': endDate,
        'period': period,
        'content': content,
      },
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/reports/patients/{patientUid}
  Future<List<ReportModel>> listPatientReports(String patientUid) async {
    final response = await _apiClient.get('/api/reports/patients/$patientUid');
    final data = response.data as Map<String, dynamic>;
    final rawList = (data['reports'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/reports/patients/{patientUid}/{reportId}
  Future<ReportModel> getPatientReport({
    required String patientUid,
    required String reportId,
  }) async {
    final response = await _apiClient.get(
      '/api/reports/patients/$patientUid/$reportId',
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /api/reports/patients/{patientUid}/{reportId}
  Future<ReportModel> updatePatientReport({
    required String patientUid,
    required String reportId,
    required String content,
  }) async {
    final response = await _apiClient.patch(
      '/api/reports/patients/$patientUid/$reportId',
      body: {'content': content},
    );
    return ReportModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// DELETE /api/reports/patients/{patientUid}/{reportId}
  Future<void> deletePatientReport({
    required String patientUid,
    required String reportId,
  }) async {
    await _apiClient.delete(
      '/api/reports/patients/$patientUid/$reportId',
      requiresAuth: true,
    );
  }

  // -------------------------------------------------------------------------
  // PDF generation
  // -------------------------------------------------------------------------

  /// GET /api/reports/{reportId}/pdf — bytes for a stored report (no new save).
  Future<List<int>> getPdfForReport(String reportId) async {
    final response = await _apiClient.getBytes('/api/reports/$reportId/pdf');
    return List<int>.from(response.data as List);
  }

  /// GET /api/reports/patients/{patientUid}/{reportId}/pdf — bytes for a stored patient report (no new save).
  Future<List<int>> getPatientPdfForReport({
    required String patientUid,
    required String reportId,
  }) async {
    final response = await _apiClient.getBytes(
      '/api/reports/patients/$patientUid/$reportId/pdf',
    );
    return List<int>.from(response.data as List);
  }

  /// POST /api/reports/generate/pdf — returns raw PDF bytes for the patient's own journals.
  Future<List<int>> generatePdf({
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    final response = await _apiClient.postBytes(
      '/api/reports/generate/pdf',
      body: {'start_date': startDate, 'end_date': endDate, 'period': period},
    );
    // On web, Dio returns Uint8List (not List<dynamic>); handle both.
    return List<int>.from(response.data as List);
  }

  /// POST /api/reports/patients/{patientUid}/generate/pdf — PDF for a connected patient.
  Future<List<int>> generatePatientPdf({
    required String patientUid,
    required String patientName,
    required String startDate,
    required String endDate,
    required String period,
  }) async {
    final response = await _apiClient.postBytes(
      '/api/reports/patients/$patientUid/generate/pdf',
      body: {
        'start_date': startDate,
        'end_date': endDate,
        'period': period,
        'patient_name': patientName,
      },
    );
    // On web, Dio returns Uint8List (not List<dynamic>); handle both.
    return List<int>.from(response.data as List);
  }
}
