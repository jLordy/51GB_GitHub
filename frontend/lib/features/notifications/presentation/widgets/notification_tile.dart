import 'package:frontend/features/notifications/model/notification_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationTile extends StatefulWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAccept,
    this.onDecline,
    this.onMarkRead,
    this.onDelete,
  });

  final NotificationModel notification;
  final VoidCallback? onTap;

  /// Only set for [NotificationType.connectionRequest] tiles.
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;

  /// Callbacks for the per-tile options sheet.
  final VoidCallback? onMarkRead;
  final VoidCallback? onDelete;

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

enum _ActionState { pending, loading, accepted, declined }

class _NotificationTileState extends State<NotificationTile> {
  _ActionState _actionState = _ActionState.pending;

  @override
  void initState() {
    super.initState();
    _seedFromPayload(widget.notification.payload);
  }

  @override
  void didUpdateWidget(covariant NotificationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? oldStatus =
        oldWidget.notification.payload['status'] as String?;
    final String? newStatus = widget.notification.payload['status'] as String?;
    if (oldStatus != newStatus) {
      _seedFromPayload(widget.notification.payload);
    }
  }

  void _seedFromPayload(Map<String, dynamic> payload) {
    final String? status = payload['status'] as String?;
    if (status == 'accepted') {
      _actionState = _ActionState.accepted;
    } else if (status == 'declined') {
      _actionState = _ActionState.declined;
    }
  }

  bool get _isPendingRequest =>
      widget.notification.type == NotificationType.connectionRequest &&
      (widget.onAccept != null || widget.onDecline != null);

  Future<void> _onAccept() async {
    if (widget.onAccept == null) return;
    setState(() => _actionState = _ActionState.loading);
    try {
      await widget.onAccept!();
      if (mounted) setState(() => _actionState = _ActionState.accepted);
    } catch (_) {
      if (mounted) setState(() => _actionState = _ActionState.pending);
    }
  }

  Future<void> _onDecline() async {
    if (widget.onDecline == null) return;
    setState(() => _actionState = _ActionState.loading);
    try {
      await widget.onDecline!();
      if (mounted) setState(() => _actionState = _ActionState.declined);
    } catch (_) {
      if (mounted) setState(() => _actionState = _ActionState.pending);
    }
  }

  void _showTileOptionsSheet(
    BuildContext context,
    Color iconColor,
    Color textColor,
  ) {
    final ThemeData theme = Theme.of(context);
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
                if (!widget.notification.isRead)
                  ListTile(
                    leading: Icon(Icons.done, color: textColor),
                    title: Text(
                      'Mark as read',
                      style: TextStyle(color: textColor),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      widget.onMarkRead?.call();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete this notification',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    widget.onDelete?.call();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionArea(Color mutedColor) {
    switch (_actionState) {
      case _ActionState.loading:
        return const SizedBox(
          height: 26,
          width: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Palette.greenColor),
          ),
        );
      case _ActionState.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Palette.greenColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Palette.greenColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: Palette.greenColor,
              ),
              const SizedBox(width: 5),
              Text(
                'Accepted',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Palette.greenColor,
                ),
              ),
            ],
          ),
        );
      case _ActionState.declined:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: mutedColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: mutedColor.withValues(alpha: 0.25)),
          ),
          child: Text(
            'Declined',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
        );
      case _ActionState.pending:
        return Row(
          children: <Widget>[
            _ActionButton(
              label: 'Accept',
              color: Palette.greenColor,
              onTap: () {
                _onAccept();
              },
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Decline',
              color: Colors.transparent,
              textColor: mutedColor,
              borderColor: mutedColor.withValues(alpha: 0.5),
              onTap: () {
                _onDecline();
              },
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = theme.colorScheme.onSurface;
    final Color iconColor = theme.iconTheme.color ?? textColor;
    final Color mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.42);
    final Color unreadBg = isDark
        ? Palette.greenColor.withValues(alpha: 0.14)
        : Palette.greenColor.withValues(alpha: 0.10);
    final Color avatarColor = isDark
        ? const Color(0xFF555D66)
        : const Color(0xFFCBCBCB);

    final String? photoUrl = widget.notification.actors.isNotEmpty
        ? widget.notification.actors.first.photoUrl
        : null;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: widget.notification.isRead ? Colors.transparent : unreadBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: avatarColor,
              child: (photoUrl != null && photoUrl.isNotEmpty)
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Text(
                          widget.notification.actors.isNotEmpty
                              ? widget.notification.actors.first.displayName
                                    .trim()
                                    .split(RegExp(r'\s+'))
                                    .take(2)
                                    .map((w) => w[0].toUpperCase())
                                    .join()
                              : '?',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.notification.actors.isNotEmpty
                          ? widget.notification.actors.first.displayName
                                .trim()
                                .split(RegExp(r'\s+'))
                                .take(2)
                                .map((w) => w[0].toUpperCase())
                                .join()
                          : '?',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: textColor,
                        height: 1.4,
                      ),
                      children: _buildSpans(widget.notification, textColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(widget.notification.createdAt),
                    style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
                  ),
                  if (_isPendingRequest &&
                      _actionState != _ActionState.accepted &&
                      _actionState != _ActionState.declined) ...<Widget>[
                    const SizedBox(height: 10),
                    _buildActionArea(mutedColor),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showTileOptionsSheet(context, iconColor, textColor),
              child: Icon(Icons.more_horiz, color: iconColor, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(NotificationModel n, Color textColor) {
    final TextStyle boldStyle = GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      color: textColor,
      fontSize: 14,
    );
    TextSpan bold(String text) => TextSpan(text: text, style: boldStyle);
    TextSpan plain(String text) => TextSpan(text: text);

    final String actor1 = n.actors.isNotEmpty
        ? n.actors.first.displayName
        : 'Someone';
    final String actor2 = n.actors.length > 1 ? n.actors[1].displayName : '';
    final int extra = n.actorCount - n.actors.length;
    final String andOthers = extra > 0 ? ' and $extra others' : '';

    switch (n.type) {
      case NotificationType.postReply:
        final String preview = n.payload['previewText'] as String? ?? '';
        return <InlineSpan>[
          bold(actor1),
          plain(' replied to your post'),
          if (preview.isNotEmpty) plain(': \u201c$preview\u201d'),
        ];

      case NotificationType.scheduleUpdate:
        final String doctorName = n.payload['doctorName'] as String? ?? '';
        return <InlineSpan>[
          bold(actor1),
          plain(' shared an update'),
          if (doctorName.isNotEmpty) ...<InlineSpan>[
            plain(' on '),
            bold(doctorName),
            plain('\u2019s schedule.'),
          ] else
            plain('.'),
        ];

      case NotificationType.groupPostShared:
        final int count = (n.payload['postCount'] as num?)?.toInt() ?? 0;
        return <InlineSpan>[
          bold(actor1),
          if (actor2.isNotEmpty) ...<InlineSpan>[
            plain(' and '),
            bold('$actor2$andOthers'),
          ],
          plain(' recently shared $count question${count == 1 ? '' : 's'}.'),
        ];

      case NotificationType.postHeart:
        return <InlineSpan>[
          bold('$actor1$andOthers'),
          plain(' liked your post.'),
        ];

      case NotificationType.commentHeart:
        return <InlineSpan>[
          bold('$actor1$andOthers'),
          plain(' liked your comment.'),
        ];

      case NotificationType.connectionRequest:
        if (_actionState == _ActionState.accepted) {
          return <InlineSpan>[
            plain('You accepted '),
            bold(actor1),
            plain('\u2019s connection request.'),
          ];
        }
        return <InlineSpan>[
          bold(actor1),
          plain(' sent you a connection request.'),
        ];

      case NotificationType.connectionAccepted:
        return <InlineSpan>[
          bold(actor1),
          plain(' accepted your connection request.'),
        ];

      case NotificationType.unknown:
        return <InlineSpan>[plain('You have a new notification.')];
    }
  }

  String _formatTime(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor = Colors.white,
    this.borderColor = Colors.transparent,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
