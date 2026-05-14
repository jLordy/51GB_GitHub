import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.myUid,
    required this.onTap,
  });

  final ConversationModel conversation;
  final String myUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final otherName = conversation.otherName(myUid);
    final photoUrl = conversation.otherPhoto(myUid);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Avatar ─────────────────────────────────────────────────
            CircleAvatar(
              radius: 25,
              backgroundColor: scheme.outlineVariant,
              child: CircleAvatar(
                radius: 23,
                backgroundColor: scheme.surfaceContainerHighest,
                child: photoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Text(
                            otherName.isNotEmpty
                                ? otherName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Name + last message ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lastMessagePreview(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Time + unread badge ─────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (conversation.lastMessageAt != null)
                  Text(
                    _formatTime(conversation.lastMessageAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      conversation.unreadCount > 99
                          ? '99+'
                          : '${conversation.unreadCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _lastMessagePreview() {
    final type = conversation.lastMessageType;
    final isMe = conversation.lastSenderId == myUid;
    final prefix = isMe ? 'You' : conversation.otherName(myUid);

    if (type == 'image') {
      return isMe ? 'You sent a photo.' : '$prefix sent a photo.';
    }
    if (type == 'video') {
      return isMe ? 'You sent a video.' : '$prefix sent a video.';
    }
    if (type == 'missed_call') {
      return '📞 Missed call';
    }

    final msg = conversation.lastMessage;
    if (msg == null || msg.isEmpty) return 'No messages yet';
    if (msg.startsWith('enc:')) return '';
    return '$prefix: $msg';
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
      if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      }
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
