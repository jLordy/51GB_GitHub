import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/file/model/file_document_model.dart';
import 'package:frontend/features/file/model/file_folder_model.dart';
import 'package:frontend/features/file/model/storage_summary_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return FileRepository(ref.read(apiClientProvider));
});

class FileRepository {
  FileRepository(this._apiClient);

  final ApiClient _apiClient;

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<FileFolderModel> _parseFolders(Map<String, dynamic> data) {
    final raw = (data['folders'] as List<dynamic>?) ?? <dynamic>[];
    return raw
        .map((e) => FileFolderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<FileDocumentModel> _parseDocuments(Map<String, dynamic> data) {
    final raw = (data['documents'] as List<dynamic>?) ?? <dynamic>[];
    return raw
        .map((e) => FileDocumentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Patient self-access — folders ────────────────────────────────────────

  Future<List<FileFolderModel>> fetchFolders() async {
    final response = await _apiClient.get('/api/files/folders');
    return _parseFolders(response.data as Map<String, dynamic>);
  }

  Future<FileFolderModel> createFolder(String name) async {
    final response = await _apiClient.post(
      '/api/files/folders',
      body: {'name': name},
    );
    return FileFolderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FileFolderModel> renameFolder(String folderId, String name) async {
    final response = await _apiClient.patch(
      '/api/files/folders/$folderId',
      body: {'name': name},
    );
    return FileFolderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteFolder(String folderId) async {
    await _apiClient.delete('/api/files/folders/$folderId');
  }

  // ── Patient self-access — documents ──────────────────────────────────────

  Future<List<FileDocumentModel>> fetchDocuments(String folderId) async {
    final response = await _apiClient.get(
      '/api/files/folders/$folderId/documents',
    );
    return _parseDocuments(response.data as Map<String, dynamic>);
  }

  Future<FileDocumentModel> uploadDocument({
    required String folderId,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    String? displayName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
      if (displayName != null && displayName.isNotEmpty) 'name': displayName,
    });
    final response = await _apiClient.postMultipart(
      '/api/files/folders/$folderId/documents',
      formData: formData,
    );
    return FileDocumentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FileDocumentModel> renameDocument(
    String folderId,
    String docId,
    String name,
  ) async {
    final response = await _apiClient.patch(
      '/api/files/folders/$folderId/documents/$docId',
      body: {'name': name},
    );
    return FileDocumentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String folderId, String docId) async {
    await _apiClient.delete('/api/files/folders/$folderId/documents/$docId');
  }

  // ── Patient self-access — storage summary ────────────────────────────────

  Future<StorageSummaryModel> fetchStorageSummary() async {
    final response = await _apiClient.get('/api/files/storage-summary');
    return StorageSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Connected-user access — folders ──────────────────────────────────────

  Future<List<FileFolderModel>> fetchPatientFolders(String patientUid) async {
    final response = await _apiClient.get(
      '/api/files/patients/$patientUid/folders',
    );
    return _parseFolders(response.data as Map<String, dynamic>);
  }

  Future<FileFolderModel> createPatientFolder(
    String patientUid,
    String name,
  ) async {
    final response = await _apiClient.post(
      '/api/files/patients/$patientUid/folders',
      body: {'name': name},
    );
    return FileFolderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FileFolderModel> renamePatientFolder(
    String patientUid,
    String folderId,
    String name,
  ) async {
    final response = await _apiClient.patch(
      '/api/files/patients/$patientUid/folders/$folderId',
      body: {'name': name},
    );
    return FileFolderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePatientFolder(String patientUid, String folderId) async {
    await _apiClient.delete(
      '/api/files/patients/$patientUid/folders/$folderId',
    );
  }

  // ── Connected-user access — documents ────────────────────────────────────

  Future<List<FileDocumentModel>> fetchPatientDocuments(
    String patientUid,
    String folderId,
  ) async {
    final response = await _apiClient.get(
      '/api/files/patients/$patientUid/folders/$folderId/documents',
    );
    return _parseDocuments(response.data as Map<String, dynamic>);
  }

  Future<FileDocumentModel> uploadPatientDocument({
    required String patientUid,
    required String folderId,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    String? displayName,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
      if (displayName != null && displayName.isNotEmpty) 'name': displayName,
    });
    final response = await _apiClient.postMultipart(
      '/api/files/patients/$patientUid/folders/$folderId/documents',
      formData: formData,
    );
    return FileDocumentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FileDocumentModel> renamePatientDocument(
    String patientUid,
    String folderId,
    String docId,
    String name,
  ) async {
    final response = await _apiClient.patch(
      '/api/files/patients/$patientUid/folders/$folderId/documents/$docId',
      body: {'name': name},
    );
    return FileDocumentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePatientDocument(
    String patientUid,
    String folderId,
    String docId,
  ) async {
    await _apiClient.delete(
      '/api/files/patients/$patientUid/folders/$folderId/documents/$docId',
    );
  }

  Future<StorageSummaryModel> fetchPatientStorageSummary(
    String patientUid,
  ) async {
    final response = await _apiClient.get(
      '/api/files/patients/$patientUid/storage-summary',
    );
    return StorageSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }
}
