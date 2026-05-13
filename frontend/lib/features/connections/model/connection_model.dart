import 'package:flutter/foundation.dart';

enum ConnectionStatus { pending, accepted, declined }

@immutable
class ConnectionModel {
  const ConnectionModel({
    required this.connectionId,
    required this.requesterUid,
    required this.recipientUid,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String connectionId;
  final String requesterUid;
  final String recipientUid;
  final ConnectionStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    return ConnectionModel(
      connectionId: json['connection_id'] as String? ?? '',
      requesterUid: json['requester_uid'] as String? ?? '',
      recipientUid: json['recipient_uid'] as String? ?? '',
      status: _statusFromString(json['status'] as String? ?? ''),
      createdAt: _parseTs(json['created_at']),
      updatedAt: _parseTs(json['updated_at']),
    );
  }

  /// Returns the UID of the other party (not `selfUid`).
  String otherUid(String selfUid) =>
      requesterUid == selfUid ? recipientUid : requesterUid;

  static ConnectionStatus _statusFromString(String v) {
    switch (v) {
      case 'accepted':
        return ConnectionStatus.accepted;
      case 'declined':
        return ConnectionStatus.declined;
      default:
        return ConnectionStatus.pending;
    }
  }

  static DateTime? _parseTs(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
