import 'package:frontend/features/chat/controller/encryption_provider.dart';
import 'package:frontend/features/chat/data/chat_stream_repository.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real-time stream of conversations for a given UID.
final conversationsStreamProvider = StreamProvider.autoDispose
    .family<List<ConversationModel>, String>((ref, uid) {
      final repo = ref.watch(chatStreamRepositoryProvider);
      // Trigger the key fetch without gating the stream on its loading state.
      ref.listen(encryptionKeyProvider, (_, _) {});
      // Watch the synchronous cache — always AsyncData, never AsyncLoading.
      final key = ref.watch(encryptionKeyCacheProvider);
      return repo.conversationsStream(uid, encryptionKey: key);
    });

/// True when the current user has at least one conversation with unread messages.
final hasUnreadChatsProvider = Provider.autoDispose.family<bool, String>((
  ref,
  uid,
) {
  final conversations = ref.watch(conversationsStreamProvider(uid));
  return conversations.asData?.value.any((c) => c.unreadCount > 0) ?? false;
});
