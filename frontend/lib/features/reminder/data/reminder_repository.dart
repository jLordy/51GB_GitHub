import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.read(apiClientProvider));
});

/// Handles CRUD operations for reminders via the backend REST API.
///
/// Caregiver adjustments are permission-gated on the server by [caregiverId]:
/// a caregiver may only mutate reminders where they are listed as the owner.
/// Pass [caregiverId] when calling [markStatus] on behalf of a caregiver.
class ReminderRepository {
  ReminderRepository(this._api);

  final ApiClient _api;

  Future<List<MedicationReminder>> fetchAll() async {
    try {
      final res = await _api.get('/api/reminders');
      final list = res.data as List;
      return list
          .map((e) =>
              MedicationReminder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException {
      // API not yet wired — bubble up so the controller falls back to local.
      rethrow;
    }
  }

  Future<MedicationReminder> create(MedicationReminder reminder) async {
    final res = await _api.post(
      '/api/reminders',
      body: reminder.toJson(),
    );
    return MedicationReminder.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<MedicationReminder> update(MedicationReminder reminder) async {
    final res = await _api.put(
      '/api/reminders/${reminder.id}',
      body: reminder.toJson(),
    );
    return MedicationReminder.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/reminders/$id');
  }

  /// Update only the [status] field. Pass [caregiverId] for caregiver-scoped
  /// mutations; the backend validates ownership before applying the change.
  Future<MedicationReminder> markStatus(
    String id,
    ReminderStatus status, {
    String? caregiverId,
  }) async {
    final res = await _api.patch(
      '/api/reminders/$id/status',
      body: {
        'status': status.value,
        ...?( caregiverId != null ? {'caregiver_id': caregiverId} : null),
      },
    );
    return MedicationReminder.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }
}
