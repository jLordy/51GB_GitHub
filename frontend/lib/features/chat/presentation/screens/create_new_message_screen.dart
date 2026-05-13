import 'package:frontend/features/auth/model/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateNewMessageScreen extends ConsumerStatefulWidget {
  const CreateNewMessageScreen({super.key});

  @override
  ConsumerState<CreateNewMessageScreen> createState() =>
      _CreateNewMessageScreenState();
}

class _CreateNewMessageScreenState
    extends ConsumerState<CreateNewMessageScreen> {
  final _controller = TextEditingController();
  String _query = '';
  bool _isCreating = false;

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

  Future<void> _openChat(UserModel user) async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createOrFetchConversation(user.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/${conv.conversationId}', extra: conv);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open conversation.')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final contactsAsync = ref.watch(acceptedConnectionUsersProvider);

    final List<UserModel> filtered =
        contactsAsync.whenOrNull(
          data: (users) {
            if (_query.isEmpty) return users;
            return users
                .where(
                  (u) =>
                      (u.displayName ?? '').toLowerCase().contains(_query) ||
                      (u.role).toLowerCase().contains(_query),
                )
                .toList();
          },
        ) ??
        const [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // ── Header ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        title: Text(
          'New Message',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Palette.greenColor,
            padding: const EdgeInsets.only(left: 8),
          ),
          child: const Text(
            'Close',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: scheme.outlineVariant),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "To:" search row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'To:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 16, color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => _controller.clear(),
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: scheme.outlineVariant),

          // ── Contacts list ───────────────────────────────────────────────
          Expanded(
            child: contactsAsync.when(
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
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: filtered.length + 1, // +1 for section header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          _query.isEmpty ? 'Suggested' : 'Results',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                      );
                    }

                    final user = filtered[index - 1];
                    return _ContactTile(
                      user: user,
                      scheme: scheme,
                      isLoading: _isCreating,
                      onTap: () => _openChat(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact tile ─────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.user,
    required this.scheme,
    required this.isLoading,
    required this.onTap,
  });

  final UserModel user;
  final ColorScheme scheme;
  final bool isLoading;
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
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
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
            // Name + role
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
