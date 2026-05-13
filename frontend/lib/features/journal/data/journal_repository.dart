import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/journal/model/journal_entry_model.dart';
import 'package:frontend/features/journal/model/question_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.read(apiClientProvider));
});

class JournalRepository {
  JournalRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /api/journal/entries — returns all entries for the current user
  /// ordered by submitted_at descending (handled server-side).
  Future<List<JournalEntryModel>> fetchEntries() async {
    final response = await _apiClient.get('/api/journal/entries');
    final data = response.data as Map<String, dynamic>;
    final rawList = (data['entries'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map((e) => JournalEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/journal/questions — returns the daily questions for the authenticated patient.
  Future<JournalQuestionsResponse> fetchQuestions() async {
    final response = await _apiClient.get('/api/journal/questions');
    return JournalQuestionsResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// POST /api/journal/entries — submits a completed journal session.
  Future<JournalEntryModel> submitEntry({
    required String questionSetType,
    required Map<String, dynamic> answers,
  }) async {
    final response = await _apiClient.post(
      '/api/journal/entries',
      body: {'question_set_type': questionSetType, 'answers': answers},
    );
    return JournalEntryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /api/journal/entries/{entryId} — updates answers of an existing entry.
  Future<JournalEntryModel> updateEntry({
    required String entryId,
    required Map<String, dynamic> answers,
  }) async {
    final response = await _apiClient.patch(
      '/api/journal/entries/$entryId',
      body: {'answers': answers},
    );
    return JournalEntryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/journal/entries/{entryId}/history — returns the edit history for
  /// an entry, newest edit first. Returns an empty list when never edited.
  Future<List<EditHistoryEntry>> fetchEntryHistory(String entryId) async {
    final response = await _apiClient.get(
      '/api/journal/entries/$entryId/history',
    );
    final data = response.data as Map<String, dynamic>;
    final rawList = (data['history'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map((e) => EditHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /api/journal/entries/{entryId} — permanently deletes an entry and
  /// its entire edit history. Only the owning patient may call this.
  Future<void> deleteEntry(String entryId) async {
    await _apiClient.delete(
      '/api/journal/entries/${entryId.trim()}',
      requiresAuth: true,
    );
  }

  // -------------------------------------------------------------------------
  // Connection-gated access (doctor read-only; caregiver read + write)
  // -------------------------------------------------------------------------

  /// GET /api/journal/patients/{patientUid}/questions
  /// Returns the daily questions assembled from the patient's illness profile.
  Future<JournalQuestionsResponse> fetchPatientQuestions(
    String patientUid,
  ) async {
    final response = await _apiClient.get(
      '/api/journal/patients/$patientUid/questions',
    );
    return JournalQuestionsResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// GET /api/journal/patients/{patientUid}/entries
  /// Returns all journal entries for the connected patient, newest first.
  Future<List<JournalEntryModel>> listPatientEntries(String patientUid) async {
    final response = await _apiClient.get(
      '/api/journal/patients/$patientUid/entries',
    );
    final data = response.data as Map<String, dynamic>;
    final rawList = (data['entries'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map((e) => JournalEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/journal/patients/{patientUid}/entries/{entryId}/history
  /// Returns the edit history for a connected patient's entry, newest first.
  Future<List<EditHistoryEntry>> getPatientEntryHistory(
    String patientUid,
    String entryId,
  ) async {
    final response = await _apiClient.get(
      '/api/journal/patients/$patientUid/entries/$entryId/history',
    );
    final data = response.data as Map<String, dynamic>;
    final rawList = (data['history'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map((e) => EditHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/journal/patients/{patientUid}/entries
  /// Creates a journal entry on behalf of a connected patient (caregiver only).
  Future<JournalEntryModel> createEntryForPatient({
    required String patientUid,
    required String questionSetType,
    required Map<String, dynamic> answers,
  }) async {
    final response = await _apiClient.post(
      '/api/journal/patients/$patientUid/entries',
      body: {'question_set_type': questionSetType, 'answers': answers},
    );
    return JournalEntryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// PATCH /api/journal/patients/{patientUid}/entries/{entryId}
  /// Updates a connected patient's journal entry (caregiver only).
  Future<JournalEntryModel> updatePatientEntry({
    required String patientUid,
    required String entryId,
    required Map<String, dynamic> answers,
  }) async {
    final response = await _apiClient.patch(
      '/api/journal/patients/$patientUid/entries/$entryId',
      body: {'answers': answers},
    );
    return JournalEntryModel.fromJson(response.data as Map<String, dynamic>);
  }
}