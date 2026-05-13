import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/chat/controller/chat_controller.dart';
import 'package:frontend/features/chat/controller/conversation_controller.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:frontend/features/chat/presentation/screens/create_new_message_screen.dart';
import 'package:frontend/features/chat/presentation/widgets/conversation_tile.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final bg = theme.scaffoldBackgroundColor;
    final currentUser = ref.watch(currentUserProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 680;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final conversationsAsync = ref.watch(
      conversationsStreamProvider(currentUser.uid),
    );

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      drawer: isWide ? null : const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu_rounded, color: scheme.onSurface),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Text(
          'Chats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: scheme.onSurface),
            tooltip: 'New message',
            onPressed: () => _openNewMessage(context),
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: scheme.onSurface),
            tooltip: 'Search',
            onPressed: () => context.push('/chat-search'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavbar(
              selectedIndex: -1,
              onJournalTap: () => context.go('/journal'),
              onNotificationsTap: () => context.go('/notifications'),
            ),
      body: conversationsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) {
          debugPrint('[ConversationsScreen] error: $e');
          debugPrint('[ConversationsScreen] stack: $st');
          return Center(
            child: Text(
              'Failed to load conversations',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        },
        data: (conversations) {
          final visible = conversations
              .where((c) => c.lastMessageAt != null)
              .toList();
          if (visible.isEmpty) {
            return _EmptyState(scheme: scheme);
          }
          return ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: scheme.outlineVariant, indent: 72),
            itemBuilder: (context, index) {
              final conv = visible[index];
              return Dismissible(
                key: ValueKey(conv.conversationId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: scheme.error,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.onError,
                  ),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete conversation?'),
                          content: const Text(
                            'This conversation will be permanently deleted.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  final success = await ref
                      .read(chatControllerProvider.notifier)
                      .deleteConversation(conv.conversationId);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete conversation.'),
                      ),
                    );
                  }
                },
                child: ConversationTile(
                  conversation: conv,
                  myUid: currentUser.uid,
                  onTap: () => _openChat(context, conv),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openNewMessage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: const CreateNewMessageScreen(),
      ),
    );
  }

  void _openChat(BuildContext context, ConversationModel conv) {
    context.push('/chat/${conv.conversationId}', extra: conv);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: scheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with someone from their profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
