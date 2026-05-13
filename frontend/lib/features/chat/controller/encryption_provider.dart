import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Synchronous cache of the AES-256 key (null until the first successful fetch).
///
/// Stream providers watch this instead of [encryptionKeyProvider] so that
/// Firestore streams start immediately and are never blocked by the async
/// key-loading state.
final encryptionKeyCacheProvider = StateProvider<String?>((ref) => null);

/// Fetches the AES-256 chat encryption key from the backend.
///
/// On success it populates [encryptionKeyCacheProvider] so that stream
/// providers can decrypt without restarting the stream.
final encryptionKeyProvider = FutureProvider<String>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/chat/key');
  final data = Map<String, dynamic>.from(response.data as Map);
  final key = data['encryption_key'] as String;
  // Write the synchronous cache so stream providers pick it up.
  ref.read(encryptionKeyCacheProvider.notifier).state = key;
  return key;
});
