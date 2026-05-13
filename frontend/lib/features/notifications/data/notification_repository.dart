import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/notifications/model/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider));
});

class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<NotificationModel>> fetchNotifications({int limit = 40}) async {
    final response = await _apiClient.get(
      '/api/notifications',
      queryParameters: <String, dynamic>{'limit': limit},
      requiresAuth: true,
    );

    final dynamic data = response.data;
    if (data is! List) return const <NotificationModel>[];

    return data
        .whereType<Map>()
        .map((m) => NotificationModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Marks a list of notification IDs as read on the server.
  Future<void> markRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    await _apiClient.patch(
      '/api/notifications/read',
      body: <String, dynamic>{'notification_ids': notificationIds},
      requiresAuth: true,
    );
  }

  /// Deletes all notifications for the current user.
  Future<void> deleteAll() async {
    await _apiClient.delete('/api/notifications', requiresAuth: true);
  }

  /// Deletes a single notification by id.
  Future<void> deleteOne(String notificationId) async {
    await _apiClient.delete(
      '/api/notifications/$notificationId',
      requiresAuth: true,
    );
  }

  /// Persists the accepted/declined status into the notification's payload in
  /// Firestore so it survives app restarts.
  Future<void> patchPayloadStatus(String notificationId, String status) async {
    await _apiClient.patch(
      '/api/notifications/$notificationId/payload-status',
      body: <String, dynamic>{'status': status},
      requiresAuth: true,
    );
  }
}
