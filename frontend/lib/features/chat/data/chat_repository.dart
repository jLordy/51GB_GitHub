import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:frontend/features/chat/model/message_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(apiClientProvider));
});

class ChatRepository {
  ChatRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Get or create a 1-on-1 conversation with [otherUid].
  Future<ConversationModel> createOrFetchConversation(String otherUid) async {
    final response = await _apiClient.post(
      '/api/chat/conversations',
      body: {'other_uid': otherUid},
    );
    return ConversationModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Send a message in the given conversation.
  Future<MessageModel> sendMessage({
    required String conversationId,
    String? text,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    final response = await _apiClient.post(
      '/api/chat/conversations/$conversationId/messages',
      body: {'text': ?text, 'type': type.value, 'media_url': ?mediaUrl},
    );
    return MessageModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Mark all messages in a conversation as read for the current user.
  Future<void> markAsRead(String conversationId) async {
    await _apiClient.patch('/api/chat/conversations/$conversationId/read');
  }

  /// Delete a single message by ID.
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _apiClient.delete(
      '/api/chat/conversations/$conversationId/messages/$messageId',
    );
  }

  /// Delete an entire conversation.
  Future<void> deleteConversation(String conversationId) async {
    await _apiClient.delete('/api/chat/conversations/$conversationId');
  }

  /// Upload an image and return its public URL.
  Future<String> uploadImage(XFile imageFile) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        await imageFile.readAsBytes(),
        filename: imageFile.name,
      ),
    });
    final response = await _apiClient.postMultipart(
      '/api/upload/image',
      formData: formData,
      requiresAuth: true,
    );
    final data = response.data;
    if (data is! Map) throw Exception('Unexpected upload response.');
    return data['url'] as String;
  }

  /// Upload a video and return its public URL.
  Future<String> uploadVideo(XFile videoFile) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        await videoFile.readAsBytes(),
        filename: videoFile.name,
      ),
    });
    final response = await _apiClient.postMultipart(
      '/api/upload/video',
      formData: formData,
      requiresAuth: true,
    );
    final data = response.data;
    if (data is! Map) throw Exception('Unexpected upload response.');
    return data['url'] as String;
  }
}
