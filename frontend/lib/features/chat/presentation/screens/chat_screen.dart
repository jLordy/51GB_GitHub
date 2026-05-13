import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:frontend/features/call/presentation/screens/call_screen.dart';
import 'package:frontend/features/chat/controller/chat_controller.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:frontend/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final ConversationModel conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages read when the screen opens (fire-and-forget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatControllerProvider.notifier)
          .markAsRead(widget.conversation.conversationId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.conversation.conversationId),
    );
    final sendState = ref.watch(chatControllerProvider);
    final isSending = sendState.isLoading;

    final myUid = currentUser?.uid ?? '';
    final otherName = widget.conversation.otherName(myUid);
    final otherPhoto = widget.conversation.otherPhoto(myUid);
    final otherUid = widget.conversation.otherUid(myUid);

    // Auto-scroll and mark as read when new messages arrive
    ref.listen(messagesStreamProvider(widget.conversation.conversationId), (
      prev,
      next,
    ) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        // If any incoming message is not yet read by me, mark conversation read
        final msgs = next.value!;
        final hasUnread = msgs.any(
          (m) => m.senderId != myUid && !m.readBy.contains(myUid),
        );
        if (hasUnread) {
          ref
              .read(chatControllerProvider.notifier)
              .markAsRead(widget.conversation.conversationId);
        }
      }
    });

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: _ChatAppBar(
        name: otherName,
        photoUrl: otherPhoto,
        otherUid: otherUid,
        myUid: myUid,
        myName:
            currentUser?.displayName ??
            currentUser?.email?.split('@').first ??
            '',
        myPhotoUrl: currentUser?.photoUrl,
        scheme: scheme,
      ),
      body: Column(
        children: [
          // ── Messages list ───────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load messages',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hi to $otherName 👋',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                // Find the last message sent by me that the other user has seen
                int lastSeenIndex = -1;
                for (int i = messages.length - 1; i >= 0; i--) {
                  final m = messages[i];
                  if (m.senderId == myUid && m.readBy.contains(otherUid)) {
                    lastSeenIndex = i;
                    break;
                  }
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == myUid;
                    return MessageBubble(
                      message: msg,
                      isMine: isMine,
                      senderPhotoUrl: isMine ? null : otherPhoto,
                      showSeen: index == lastSeenIndex,
                      onDelete: isMine
                          ? () async {
                              await ref
                                  .read(chatControllerProvider.notifier)
                                  .deleteMessage(
                                    conversationId: msg.conversationId,
                                    messageId: msg.messageId,
                                  );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          // ── Error banner if send fails ──────────────────────────────
          if (sendState.hasError)
            Container(
              color: scheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to send message. Try again.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Input bar ───────────────────────────────────────────────
          ChatInputBar(
            isLoading: isSending,
            onSend: (text) async {
              await ref
                  .read(chatControllerProvider.notifier)
                  .sendMessage(
                    conversationId: widget.conversation.conversationId,
                    text: text,
                  );
            },
            onLike: () async {
              await ref
                  .read(chatControllerProvider.notifier)
                  .sendMessage(
                    conversationId: widget.conversation.conversationId,
                    text: '👍',
                  );
            },
            onAttachImage: (imageFile) async {
              await ref
                  .read(chatControllerProvider.notifier)
                  .sendImageMessage(
                    conversationId: widget.conversation.conversationId,
                    imageFile: imageFile,
                  );
            },
            onAttachVideo: (videoFile) async {
              await ref
                  .read(chatControllerProvider.notifier)
                  .sendVideoMessage(
                    conversationId: widget.conversation.conversationId,
                    videoFile: videoFile,
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.name,
    required this.photoUrl,
    required this.otherUid,
    required this.myUid,
    required this.myName,
    required this.myPhotoUrl,
    required this.scheme,
  });

  final String name;
  final String? photoUrl;
  final String otherUid;
  final String myUid;
  final String myName;
  final String? myPhotoUrl;
  final ColorScheme scheme;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          backgroundColor: scheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 0,
          title: GestureDetector(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.outlineVariant,
                  child: CircleAvatar(
                    radius: 18.5,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: photoUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: photoUrl!,
                              width: 37,
                              height: 37,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (context) {
                  final callState = ProviderScope.containerOf(
                    context,
                  ).read(callControllerProvider);
                  final hasActiveCall = callState.hasActiveCall;
                  // True if the active call is already with this person.
                  final isCallWithThisPerson =
                      hasActiveCall &&
                      (callState.callModel!.calleeId == otherUid ||
                          callState.callModel!.callerId == otherUid);
                  return IconButton(
                    icon: Icon(
                      Icons.call_rounded,
                      color: (hasActiveCall && !isCallWithThisPerson)
                          ? scheme.outline
                          : scheme.primary,
                      size: 26,
                    ),
                    tooltip: (hasActiveCall && !isCallWithThisPerson)
                        ? 'Already in a call'
                        : 'Voice call',
                    onPressed: (hasActiveCall && !isCallWithThisPerson)
                        ? null
                        : isCallWithThisPerson
                        // Already in a call with this person — go to call screen.
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => CallScreen(
                                otherName: name,
                                otherPhotoUrl: photoUrl,
                              ),
                            ),
                          )
                        // No active call — start one.
                        : () async {
                            final controller = ProviderScope.containerOf(
                              context,
                            ).read(callControllerProvider.notifier);
                            await controller.startCall(
                              calleeUid: otherUid,
                              callerUid: myUid,
                              callerName: myName,
                              calleeName: name,
                              callerPhotoUrl: myPhotoUrl,
                              calleePhotoUrl: photoUrl,
                              isVideo: true,
                            );
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => CallScreen(
                                    otherName: name,
                                    otherPhotoUrl: photoUrl,
                                  ),
                                ),
                              );
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}
