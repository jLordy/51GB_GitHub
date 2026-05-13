import 'package:flutter/foundation.dart';

@immutable
class ConversationModel {
  const ConversationModel({
    required this.conversationId,
    required this.participants,
    required this.participantNames,
    required this.participantPhotos,
    required this.unreadCount,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageType,
    this.lastSenderId,
    this.lastMessageAt,
  });

  final String conversationId;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastSenderId;
  final String? lastMessageAt;
  final int unreadCount;
  final String createdAt;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: json['conversation_id'] as String,
      participants: List<String>.from(json['participants'] as List),
      participantNames: Map<String, String>.from(
        json['participant_names'] as Map,
      ),
      participantPhotos: (json['participant_photos'] as Map).map(
        (k, v) => MapEntry(k as String, v as String?),
      ),
      lastMessage: json['last_message'] as String?,
      lastMessageType: json['last_message_type'] as String?,
      lastSenderId: json['last_sender_id'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String,
    );
  }

  /// Build from a Firestore document snapshot map (used by stream repo).
  factory ConversationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
    String viewerUid,
  ) {
    final unreadCounts = data['unread_counts'] as Map<String, dynamic>? ?? {};
    final lastMessageAt = data['last_message_at'];
    return ConversationModel(
      conversationId: id,
      participants: List<String>.from(data['participants'] as List? ?? []),
      participantNames: Map<String, String>.from(
        data['participant_names'] as Map? ?? {},
      ),
      participantPhotos: ((data['participant_photos'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k as String, v as String?),
      ),
      lastMessage: data['last_message'] as String?,
      lastMessageType: data['last_message_type'] as String?,
      lastSenderId: data['last_sender_id'] as String?,
      lastMessageAt: lastMessageAt?.toString(),
      unreadCount: (unreadCounts[viewerUid] as num?)?.toInt() ?? 0,
      createdAt: (data['created_at'])?.toString() ?? '',
    );
  }

  /// The display name of the other participant in a 1-on-1 conversation.
  String otherName(String myUid) {
    final otherId = participants.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );
    return participantNames[otherId] ?? 'Unknown';
  }

  /// The photo URL of the other participant.
  String? otherPhoto(String myUid) {
    final otherId = participants.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );
    return participantPhotos[otherId];
  }

  /// The UID of the other participant.
  String otherUid(String myUid) {
    return participants.firstWhere((uid) => uid != myUid, orElse: () => '');
  }

  ConversationModel copyWith({
    String? conversationId,
    List<String>? participants,
    Map<String, String>? participantNames,
    Map<String, String?>? participantPhotos,
    String? lastMessage,
    String? lastMessageType,
    String? lastSenderId,
    String? lastMessageAt,
    int? unreadCount,
    String? createdAt,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      participantPhotos: participantPhotos ?? this.participantPhotos,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
