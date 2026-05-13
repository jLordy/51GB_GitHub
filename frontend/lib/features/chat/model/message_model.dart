import 'package:flutter/foundation.dart';

enum MessageType { text, image, video, missedCall }

extension MessageTypeX on MessageType {
  String get value {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.missedCall:
        return 'missed_call';
    }
  }

  static MessageType fromString(String? s) {
    switch (s) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'missed_call':
        return MessageType.missedCall;
      default:
        return MessageType.text;
    }
  }
}

@immutable
class MessageModel {
  const MessageModel({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.readBy,
    required this.createdAt,
    this.text,
    this.mediaUrl,
  });

  final String messageId;
  final String conversationId;
  final String senderId;
  final String? text;
  final MessageType type;
  final String? mediaUrl;
  final List<String> readBy;
  final String createdAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      messageId: json['message_id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      text: json['text'] as String?,
      type: MessageTypeX.fromString(json['type'] as String?),
      mediaUrl: json['media_url'] as String?,
      readBy: List<String>.from(json['read_by'] as List? ?? []),
      createdAt: json['created_at'] as String,
    );
  }

  /// Build from a Firestore document snapshot map (used by stream repo).
  factory MessageModel.fromFirestore(
    String id,
    String conversationId,
    Map<String, dynamic> data,
  ) {
    return MessageModel(
      messageId: id,
      conversationId: conversationId,
      senderId: data['sender_id'] as String? ?? '',
      text: data['text'] as String?,
      type: MessageTypeX.fromString(data['type'] as String?),
      mediaUrl: data['media_url'] as String?,
      readBy: List<String>.from(data['read_by'] as List? ?? []),
      createdAt: (data['created_at'])?.toString() ?? '',
    );
  }

  bool isReadBy(String uid) => readBy.contains(uid);
}
