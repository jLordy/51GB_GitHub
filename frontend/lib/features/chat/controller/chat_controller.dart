import 'package:frontend/features/chat/controller/encryption_provider.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/chat/data/chat_stream_repository.dart';
import 'package:frontend/features/chat/model/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

/// Real-time stream of messages for a given conversationId.
final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, conversationId) {
      final repo = ref.watch(chatStreamRepositoryProvider);
      // Trigger the key fetch without gating the stream on its loading state.
      ref.listen(encryptionKeyProvider, (_, _) {});
      // Watch the synchronous cache — always AsyncData, never AsyncLoading.
      final key = ref.watch(encryptionKeyCacheProvider);
      return repo.messagesStream(conversationId, encryptionKey: key);
    });

// ─────────────────────────────────────────────────────────────────────────────
// ChatController — handles send + mark-as-read via the REST API
// ─────────────────────────────────────────────────────────────────────────────

final chatControllerProvider =
    StateNotifierProvider<ChatController, AsyncValue<void>>(
      (ref) => ChatController(ref.read(chatRepositoryProvider)),
    );

class ChatController extends StateNotifier<AsyncValue<void>> {
  ChatController(this._repo) : super(const AsyncValue.data(null));

  final ChatRepository _repo;

  Future<bool> sendMessage({
    required String conversationId,
    String? text,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _repo.sendMessage(
        conversationId: conversationId,
        text: text,
        type: type,
        mediaUrl: mediaUrl,
      ),
    );
    state = result.when(
      data: (_) => const AsyncValue.data(null),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
    return result is AsyncData;
  }

  Future<bool> sendImageMessage({
    required String conversationId,
    required XFile imageFile,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final url = await _repo.uploadImage(imageFile);
      await _repo.sendMessage(
        conversationId: conversationId,
        type: MessageType.image,
        mediaUrl: url,
      );
    });
    state = result.when(
      data: (_) => const AsyncValue.data(null),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
    return result is AsyncData;
  }

  Future<bool> sendVideoMessage({
    required String conversationId,
    required XFile videoFile,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final url = await _repo.uploadVideo(videoFile);
      await _repo.sendMessage(
        conversationId: conversationId,
        type: MessageType.video,
        mediaUrl: url,
      );
    });
    state = result.when(
      data: (_) => const AsyncValue.data(null),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
    return result is AsyncData;
  }

  Future<void> markAsRead(String conversationId) async {
    // Fire-and-forget; UI does not need to wait for this
    await _repo.markAsRead(conversationId).catchError((_) {});
    state = const AsyncValue.data(null);
  }

  Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _repo.deleteMessage(
        conversationId: conversationId,
        messageId: messageId,
      ),
    );
    state = result.when(
      data: (_) => const AsyncValue.data(null),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
    return result is AsyncData;
  }

  Future<bool> deleteConversation(String conversationId) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => _repo.deleteConversation(conversationId),
    );
    state = result.when(
      data: (_) => const AsyncValue.data(null),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
    return result is AsyncData;
  }
}
