import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/notifications/data/notification_repository.dart';
import 'package:frontend/features/notifications/model/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Holds accepted/declined statuses for connection-request notifications.
///
/// Intentionally lives in its own non-autoDispose [Provider] so it survives
/// controller recreations triggered by [authStateProvider] changes (e.g. token
/// refresh). Without this, [NotificationController._resolvedStatuses] would be
/// wiped every time the auth state emits, reverting accepted/declined tiles.
class ConnectionStatusCache {
  final Map<String, String> _map = {};
  void set(String id, String status) => _map[id] = status;
  String? get(String id) => _map[id];
  bool get isEmpty => _map.isEmpty;
  void clear() => _map.clear();
}

final _connectionStatusCacheProvider = Provider<ConnectionStatusCache>(
  (ref) => ConnectionStatusCache(),
);

final notificationControllerProvider =
    StateNotifierProvider<
      NotificationController,
      AsyncValue<List<NotificationModel>>
    >((ref) {
      // Watch auth state so this provider is automatically invalidated —
      // and a fresh controller created — whenever the user signs in or out.
      ref.watch(authStateProvider);
      return NotificationController(
        ref.read(notificationRepositoryProvider),
        // Read (not watch) the cache — it must outlive this controller.
        ref.read(_connectionStatusCacheProvider),
      );
    });

class NotificationController
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationController(this._repo, this._statusCache)
    : super(const AsyncValue.loading()) {
    load();
  }

  final NotificationRepository _repo;

  /// Survives controller recreations — stored in [_connectionStatusCacheProvider].
  final ConnectionStatusCache _statusCache;

  /// Merges persisted statuses back into a freshly-fetched list.
  /// Matches on notification id first, then falls back to payload.connectionId
  /// for entries pre-seeded by [resolveByConnectionId] before data was loaded.
  List<NotificationModel> _applyResolved(List<NotificationModel> list) {
    if (_statusCache.isEmpty) return list;
    return list
        .map((n) {
          final String? override =
              _statusCache.get(n.id) ??
              _statusCache.get((n.payload['connectionId'] as String?) ?? '');
          if (override == null) return n;
          return n.copyWith(
            payload: Map<String, dynamic>.from(n.payload)
              ..['status'] = override,
          );
        })
        .toList(growable: false);
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(_repo.fetchNotifications);
    state = next.whenData(_applyResolved);
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(_repo.fetchNotifications);
    state = next.whenData(_applyResolved);
  }

  /// Optimistically marks all unread notifications as read, then syncs to
  /// the server. Rolls back the UI state if the network call fails.
  Future<void> markAllRead() async {
    final current = state.asData?.value;
    if (current == null) return;

    final unreadIds = current
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList(growable: false);

    if (unreadIds.isEmpty) return;

    // Optimistic update — user sees them as read immediately.
    state = AsyncValue.data(
      current.map((n) => n.copyWith(isRead: true)).toList(growable: false),
    );

    try {
      await _repo.markRead(unreadIds);
    } catch (_) {
      // Roll back on failure so unread state is accurate.
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Optimistically marks a single notification as read.
  Future<void> markRead(String notificationId) async {
    final current = state.asData?.value;
    if (current == null) return;

    final notification = current.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => current.first,
    );
    if (notification.isRead) return;

    // Optimistic update.
    state = AsyncValue.data(
      current
          .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
          .toList(growable: false),
    );

    try {
      await _repo.markRead(<String>[notificationId]);
    } catch (_) {
      // Roll back on failure.
      state = AsyncValue.data(current);
    }
  }

  Future<void> deleteAll() async {
    final current = state.asData?.value;
    state = const AsyncValue.data([]);
    _statusCache.clear();
    try {
      await _repo.deleteAll();
    } catch (_) {
      if (current != null) state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Optimistically removes a single notification, then syncs to server.
  Future<void> deleteSingle(String notificationId) async {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.where((n) => n.id != notificationId).toList(growable: false),
    );
    try {
      await _repo.deleteOne(notificationId);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  /// Optimistically stamps a connection-request notification with an
  /// accept/decline status so it persists across widget rebuilds and refreshes.
  /// Also persists the status to Firestore so it survives app restarts.
  void updateNotificationPayloadStatus(String id, String status) {
    _statusCache.set(id, status);
    // Fire-and-forget: persist to Firestore so the status survives restarts.
    _repo.patchPayloadStatus(id, status).ignore();
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncValue.data(
      current
          .map((n) {
            if (n.id != id) return n;
            return n.copyWith(
              payload: Map<String, dynamic>.from(n.payload)
                ..['status'] = status,
            );
          })
          .toList(growable: false),
    );
  }

  /// Called when a connection is accepted/declined outside the notification
  /// screen (e.g. from the connections screen). Finds the notification whose
  /// payload.connectionId matches, then delegates to
  /// [updateNotificationPayloadStatus] so the cache and UI both update.
  void resolveByConnectionId(String connectionId, String status) {
    final current = state.asData?.value;
    if (current == null) {
      // Notifications not yet loaded — pre-seed the cache so _applyResolved
      // picks it up once load() completes.
      _statusCache.set(connectionId, status);
      return;
    }
    for (final n in current) {
      if (n.type == NotificationType.connectionRequest &&
          n.payload['connectionId'] == connectionId) {
        updateNotificationPayloadStatus(n.id, status);
        return;
      }
    }
    // Notification not loaded yet — pre-seed the cache anyway. When load()
    // runs later, _applyResolved will apply it via the connectionId-keyed
    // entry. Store under connectionId as a fallback key; _applyResolved
    // still matches because we also resolve by connectionId below.
    _statusCache.set(connectionId, status);
  }
}
