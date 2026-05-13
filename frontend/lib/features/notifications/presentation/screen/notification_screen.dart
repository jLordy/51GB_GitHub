import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/notifications/controller/notification_controller.dart';
import 'package:frontend/features/notifications/model/notification_model.dart';
import 'package:frontend/features/notifications/presentation/widgets/notification_list_skeleton.dart';
import 'package:frontend/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleAccept(BuildContext context, NotificationModel n) async {
    final String? connectionId = n.payload['connectionId'] as String?;
    if (connectionId == null) return;
    try {
      await ref.read(pendingConnectionsProvider.notifier).accept(connectionId);
      // resolveByConnectionId inside accept() already updates the notification
      // status via updateNotificationPayloadStatus — no need to call it again.
      if (context.mounted) {
        AppSnackBar.show(
          context,
          'Connection accepted!',
          type: SnackBarType.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          'Failed to accept connection.',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _handleDecline(BuildContext context, NotificationModel n) async {
    final String? connectionId = n.payload['connectionId'] as String?;
    if (connectionId == null) return;
    try {
      await ref.read(pendingConnectionsProvider.notifier).decline(connectionId);
      // resolveByConnectionId inside decline() already handles the update.
      if (context.mounted) {
        AppSnackBar.show(
          context,
          'Connection declined.',
          type: SnackBarType.info,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.show(
          context,
          'Failed to decline connection.',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _openPost(BuildContext context, NotificationModel n) {
    final String? postId = n.payload['postId'] as String?;
    if (postId == null || postId.trim().isEmpty) {
      AppSnackBar.show(
        context,
        'Post not available.',
        type: SnackBarType.error,
      );
      return;
    }

    // Mark as read optimistically before navigating.
    if (!n.isRead) {
      ref.read(notificationControllerProvider.notifier).markRead(n.id);
    }

  }

  void _showOptionsSheet(BuildContext context) {
    final ThemeData theme = ref.read(themeNotifierProvider);
    final Color textColor = theme.colorScheme.onSurface;
    final Color surfaceColor = theme.colorScheme.surface;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.done_all, color: textColor),
                  title: Text(
                    'Mark all as read',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref
                        .read(notificationControllerProvider.notifier)
                        .markAllRead();
                    AppSnackBar.show(
                      context,
                      'All notifications marked as read.',
                      type: SnackBarType.success,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete all notifications',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ref
                        .read(notificationControllerProvider.notifier)
                        .deleteAll();
                    AppSnackBar.show(
                      context,
                      'All notifications deleted.',
                      type: SnackBarType.info,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, NotificationModel n) {
    final notifier = ref.read(notificationControllerProvider.notifier);

    void onMarkRead() => notifier.markRead(n.id);
    void onDelete() {
      notifier.deleteSingle(n.id);
      AppSnackBar.show(
        context,
        'Notification deleted.',
        type: SnackBarType.info,
      );
    }

    if (n.type == NotificationType.connectionAccepted) {
      return NotificationTile(
        notification: n,
        onTap: () {
          if (!n.isRead) notifier.markRead(n.id);
          context.go('/connections');
        },
        onMarkRead: onMarkRead,
        onDelete: onDelete,
      );
    }

    if (n.type == NotificationType.connectionRequest &&
        n.payload['connectionId'] != null) {
      final String? status = n.payload['status'] as String?;
      if (status == 'accepted') {
        return NotificationTile(
          notification: n,
          onTap: () => context.go('/connections'),
          onMarkRead: onMarkRead,
          onDelete: onDelete,
        );
      }
      if (status == 'declined') {
        return NotificationTile(
          notification: n,
          onTap: null,
          onMarkRead: onMarkRead,
          onDelete: onDelete,
        );
      }
      return NotificationTile(
        notification: n,
        onTap: null,
        onAccept: () => _handleAccept(context, n),
        onDecline: () => _handleDecline(context, n),
        onMarkRead: onMarkRead,
        onDelete: onDelete,
      );
    }
    return NotificationTile(
      notification: n,
      onTap: () => _openPost(context, n),
      onMarkRead: onMarkRead,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ref.watch(themeNotifierProvider);
    final Color backgroundColor = theme.scaffoldBackgroundColor;
    final Color textColor = theme.colorScheme.onSurface;
    final Color iconColor = theme.iconTheme.color ?? textColor;
    final double feedBottomPadding = 76 + MediaQuery.of(context).padding.bottom;

    final AsyncValue<List<NotificationModel>> notifState = ref.watch(
      notificationControllerProvider,
    );

    Widget buildBody() {
      final authUser = ref.watch(authStateProvider).asData?.value;
      final bool isGuest = authUser == null || authUser.isAnonymous;

      if (isGuest) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.greenColor.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.notifications_off_outlined,
                    size: 36,
                    color: Palette.greenColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Login to enable notifications',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an account or log in to receive updates on your posts and activity.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: textColor.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return notifState.when(
        loading: () => const NotificationListSkeleton(),
        error: (Object err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 48,
                color: textColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load notifications.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(notificationControllerProvider.notifier).refresh(),
                child: Text(
                  'Retry',
                  style: TextStyle(color: Palette.greenColor),
                ),
              ),
            ],
          ),
        ),
        data: (List<NotificationModel> notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            );
          }

          final DateTime now = DateTime.now();
          final DateTime todayStart = DateTime(now.year, now.month, now.day);

          final List<NotificationModel> todayNotifs = notifications
              .where((n) => !n.createdAt.isBefore(todayStart))
              .toList(growable: false);
          final List<NotificationModel> earlierNotifs = notifications
              .where((n) => n.createdAt.isBefore(todayStart))
              .toList(growable: false);

          return RefreshIndicator(
            color: Palette.greenColor,
            onRefresh: () =>
                ref.read(notificationControllerProvider.notifier).refresh(),
            child: ListView(
              padding: EdgeInsets.only(bottom: feedBottomPadding),
              children: <Widget>[
                if (todayNotifs.isNotEmpty) ...<Widget>[
                  _buildSectionHeader('Today', textColor),
                  ...todayNotifs.map(
                    (NotificationModel n) => _buildTile(context, n),
                  ),
                ],
                if (earlierNotifs.isNotEmpty) ...<Widget>[
                  _buildSectionHeader('Earlier', textColor),
                  ...earlierNotifs.map(
                    (NotificationModel n) => _buildTile(context, n),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: Builder(
          builder: (BuildContext ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: Icon(Icons.menu_rounded, color: iconColor),
          ),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => _showOptionsSheet(context),
            icon: Icon(Icons.more_horiz, color: iconColor),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: BottomNavbar(
        selectedIndex: 2,
        onHomeTap: () => context.go('/community'),
        onJournalTap: () => context.go('/journal'),
        onNotificationsTap: () {},
      ),
      body: buildBody(),
    );
  }
}
