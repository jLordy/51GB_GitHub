import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';

import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/chat/controller/conversation_controller.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchMessageScreen extends ConsumerStatefulWidget {
  const SearchMessageScreen({super.key});

  @override
  ConsumerState<SearchMessageScreen> createState() =>
      _SearchMessageScreenState();
}

class _SearchMessageScreenState extends ConsumerState<SearchMessageScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final q = _controller.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns an existing conversation with [targetUid], or null if none.
  ConversationModel? _findExisting(
    List<ConversationModel> convs,
    String targetUid,
  ) {
    for (final c in convs) {
      if (c.participants.contains(targetUid)) return c;
    }
    return null;
  }

  void _onUserTap(UserModel user) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final convs =
        ref.read(conversationsStreamProvider(currentUser.uid)).value ?? [];
    final existing = _findExisting(convs, user.uid);

    if (existing != null) {
      // Existing conversation — navigate directly to it.
      context.pushReplacement(
        '/chat/${existing.conversationId}',
        extra: existing,
      );
    } else {
      // No conversation yet — open ephemeral chat; only persists on first send.
      context.pushReplacement('/pending-chat', extra: user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final contactsAsync = ref.watch(acceptedConnectionUsersProvider);

    final List<UserModel> filtered =
        contactsAsync.whenOrNull(
          data: (users) {
            if (_query.isEmpty) return users;
            return users
                .where(
                  (u) =>
                      (u.displayName ?? '').toLowerCase().contains(_query) ||
                      u.role.toLowerCase().contains(_query),
                )
                .toList();
          },
        ) ??
        const [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 8,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(fontSize: 16, color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search people…',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
          ),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
              onPressed: () => _controller.clear(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Could not load contacts.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        data: (_) {
          if (filtered.isEmpty) {
            return Center(
              child: Text(
                _query.isEmpty
                    ? 'No connections yet.'
                    : 'No results for "$_query".',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: scheme.outlineVariant, indent: 72),
            itemBuilder: (context, index) {
              return _UserTile(
                user: filtered[index],
                scheme: scheme,
                onTap: () => _onUserTap(filtered[index]),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── User tile ────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.scheme,
    required this.onTap,
  });

  final UserModel user;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : 'Unknown';
    final initial = name[0].toUpperCase();
    final roleLabel =
        user.role[0].toUpperCase() + user.role.substring(1).toLowerCase();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: scheme.surfaceContainerHighest,
              child: user.photoUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user.photoUrl!,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Text(
                          initial,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      initial,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
