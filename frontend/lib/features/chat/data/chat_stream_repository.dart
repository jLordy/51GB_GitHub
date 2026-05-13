import 'package:frontend/core/utils/message_crypto.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:frontend/features/chat/model/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatStreamRepositoryProvider = Provider<ChatStreamRepository>((ref) {
  return ChatStreamRepository(FirebaseFirestore.instance);
});

class ChatStreamRepository {
  ChatStreamRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Real-time stream of all conversations for [uid], ordered newest-first.
  /// Pass [encryptionKey] to decrypt `last_message` previews on the fly.
  Stream<List<ConversationModel>> conversationsStream(
    String uid, {
    String? encryptionKey,
  }) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            if (encryptionKey != null) {
              final raw = data['last_message'];
              if (raw is String && raw.isNotEmpty) {
                data['last_message'] = tryDecryptMessage(raw, encryptionKey);
              }
            }
            return ConversationModel.fromFirestore(doc.id, data, uid);
          }).toList(),
        );
  }

  /// Real-time stream of messages in [conversationId], oldest-first.
  /// Pass [encryptionKey] to decrypt message text on the fly.
  Stream<List<MessageModel>> messagesStream(
    String conversationId, {
    String? encryptionKey,
  }) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            if (encryptionKey != null) {
              final raw = data['text'];
              if (raw is String && raw.isNotEmpty) {
                data['text'] = tryDecryptMessage(raw, encryptionKey);
              }
            }
            return MessageModel.fromFirestore(doc.id, conversationId, data);
          }).toList(),
        );
  }
}
