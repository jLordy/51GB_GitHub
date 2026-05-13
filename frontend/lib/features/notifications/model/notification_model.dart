import 'package:flutter/foundation.dart';

enum NotificationType {
  postReply, // actor replied to your post
  scheduleUpdate, // actor shared a schedule update
  groupPostShared, // multiple actors shared posts
  postHeart, // actor liked your post
  commentHeart, // actor liked your comment
  connectionRequest, // actor sent you a connection request
  connectionAccepted, // actor accepted your connection request
  unknown,
}

@immutable
class NotificationActor {
  const NotificationActor({
    required this.uid,
    required this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
    );
  }
}

@immutable
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.actors,
    required this.actorCount,
    required this.payload,
    required this.isRead,
    required this.createdAt,
    this.groupKey,
  });

  final String id;
  final NotificationType type;
  final List<NotificationActor> actors;
  final int actorCount;

  /// Type-specific data: postId, commentId, previewText, doctorName, etc.
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;
  final String? groupKey;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final type = _typeFromString(json['type'] as String? ?? '');

    final actorsRaw = json['actors'] as List<dynamic>? ?? <dynamic>[];
    final actors = actorsRaw
        .whereType<Map>()
        .map((a) => NotificationActor.fromJson(Map<String, dynamic>.from(a)))
        .toList();

    // Backend serialises SERVER_TIMESTAMP as an ISO-8601 string.
    final rawTs = json['created_at'] ?? json['createdAt'];
    final createdAt = rawTs is String
        ? DateTime.tryParse(rawTs) ?? DateTime.now()
        : DateTime.now();

    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: type,
      actors: actors,
      actorCount: (json['actorCount'] as num?)?.toInt() ?? actors.length,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? <dynamic, dynamic>{},
      ),
      isRead: (json['is_read'] ?? json['isRead']) as bool? ?? false,
      createdAt: createdAt,
      groupKey: json['groupKey'] as String?,
    );
  }

  NotificationModel copyWith({bool? isRead, Map<String, dynamic>? payload}) {
    return NotificationModel(
      id: id,
      type: type,
      actors: actors,
      actorCount: actorCount,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      groupKey: groupKey,
    );
  }

  static NotificationType _typeFromString(String value) {
    switch (value) {
      case 'post_reply':
        return NotificationType.postReply;
      case 'schedule_update':
        return NotificationType.scheduleUpdate;
      case 'group_post_shared':
        return NotificationType.groupPostShared;
      case 'post_heart':
        return NotificationType.postHeart;
      case 'comment_heart':
        return NotificationType.commentHeart;
      case 'connection_request':
        return NotificationType.connectionRequest;
      case 'connection_accepted':
        return NotificationType.connectionAccepted;
      default:
        return NotificationType.unknown;
    }
  }
}
