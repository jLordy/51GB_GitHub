import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';

final companionRepositoryProvider = Provider<CompanionRepository>((ref) {
  return CompanionRepository(ref.read(apiClientProvider));
});

class CompanionRepository {
  CompanionRepository(this._apiClient);

  final ApiClient _apiClient;

  /// POST /api/companion — send the user's message and receive an AI reply.
  ///
  /// Returns the reply string on success, or `null` if the backend / Ollama
  /// is unreachable or returns an error. Errors are logged via [debugPrint]
  /// for developer visibility; no exception is surfaced to the caller.
  Future<String?> getAiReply(String message) async {
    final prev = message.length > 80 ? '${message.substring(0, 80)}…' : message;
    debugPrint('[COMPANION] repo getAiReply: POST /api/companion msg_preview=$prev');
    try {
      final response = await _apiClient.post(
        '/api/companion',
        body: {'message': message},
      );
      debugPrint(
        '[COMPANION] repo getAiReply: http_status=${response.statusCode}',
      );
      final data = response.data as Map<String, dynamic>?;
      final reply = data?['reply'] as String?;
      if (reply != null && reply.isNotEmpty) {
        final rprev =
            reply.length > 120 ? '${reply.substring(0, 120)}…' : reply;
        debugPrint(
          '[COMPANION] repo getAiReply: OK reply_len=${reply.length} preview=$rprev',
        );
        return reply;
      }
      debugPrint('[COMPANION] Empty reply received from /api/companion');
      return null;
    } on DioException catch (e) {
      debugPrint('[COMPANION] DioException calling /api/companion: ${e.message} '
          '(status: ${e.response?.statusCode})');
      return null;
    } catch (e) {
      debugPrint('[COMPANION] Unexpected error calling /api/companion: $e');
      return null;
    }
  }

  /// GET /api/companion/health — called once at session start.
  ///
  /// Returns `true` if Ollama is reachable. On any error, returns `false`
  /// so the session falls back to local responses without bothering the user.
  Future<bool> checkHealth() async {
    debugPrint('[COMPANION] repo checkHealth: GET /api/companion/health');
    try {
      final response = await _apiClient.get('/api/companion/health');
      final data = response.data as Map<String, dynamic>?;
      final ok = data?['status'] == 'ok';
      debugPrint(
        '[COMPANION] repo checkHealth: http_status=${response.statusCode} '
        'body_status=${data?['status']} use_api=$ok',
      );
      return ok;
    } on DioException catch (e) {
      debugPrint('[COMPANION] Health check failed: ${e.message} '
          '(status: ${e.response?.statusCode})');
      return false;
    } catch (e) {
      debugPrint('[COMPANION] Health check unexpected error: $e');
      return false;
    }
  }
}
