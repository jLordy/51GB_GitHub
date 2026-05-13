import 'package:frontend/features/auth/model/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A chat screen shown before any conversation exists.
///
/// Nothing is written to Firestore until the user sends their first message.
/// On send the conversation is created, the message is delivered, and the
/// screen is replaced by the real [ChatScreen] — so back navigation returns
/// to the conversation list rather than this ephemeral view.
class PendingChatScreen extends ConsumerStatefulWidget {
  const PendingChatScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<PendingChatScreen> createState() => _PendingChatScreenState();
}

class _PendingChatScreenState extends ConsumerState<PendingChatScreen> {
  bool _isSending = false;

  String get _name => widget.user.displayName?.trim().isNotEmpty == true
      ? widget.user.displayName!
      : 'Unknown';

  Future<void> _sendFirstMessage(String text) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createOrFetchConversation(widget.user.uid);
      await repo.sendMessage(conversationId: conv.conversationId, text: text);
      if (!mounted) return;
      // Replace this screen so back goes to the conversations list.
      context.pushReplacement('/chat/${conv.conversationId}', extra: conv);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final photo = widget.user.photoUrl;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.surfaceContainerHighest,
              child: photo != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photo,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Text(
                          _name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      _name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Say hi to $_name 👋',
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          ChatInputBar(isLoading: _isSending, onSend: _sendFirstMessage),
        ],
      ),
    );
  }
}
