import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_controller.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/settings/presentation/widgets/settings_section.dart';
import 'package:frontend/features/settings/presentation/widgets/settings_tile.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

// null = not yet overridden locally; widget falls back to currentUserProvider value.
final _notificationsEnabledProvider = StateProvider<bool?>((ref) => null);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = ref.watch(themeNotifierProvider);
    final ColorScheme scheme = theme.colorScheme;
    final Color panelColor =
        theme.cardTheme.color ?? scheme.surfaceContainerHighest;

    final authUser = ref.watch(authStateProvider).asData?.value;
    final currentUser = ref.watch(currentUserProvider);
    final serverNotifications = currentUser?.notificationsEnabled ?? true;
    final notificationsEnabled =
        ref.watch(_notificationsEnabledProvider) ?? serverNotifications;

    final String displayName =
        currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : (authUser?.displayName?.trim().isNotEmpty == true
              ? authUser!.displayName!.trim()
              : 'User');

    final String email = authUser?.email ?? currentUser?.email ?? '';
    final String? photoUrl = authUser?.photoURL?.trim();
    final bool hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    Future<void> handleSignOut() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Log Out?'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }

    Future<void> toggleNotifications(bool value) async {
      ref.read(_notificationsEnabledProvider.notifier).state = value;
      try {
        await ref
            .read(backendSessionRepositoryProvider)
            .updateAccountSettings(notificationsEnabled: value);
      } catch (_) {
        ref.read(_notificationsEnabledProvider.notifier).state = !value;
        if (context.mounted) {
          AppSnackBar.show(
            context,
            'Failed to update notification settings.',
            type: SnackBarType.error,
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        leadingWidth: 80,
        title: Text(
          'Settings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        leading: TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/community'),
          child: Text('Close', style: TextStyle(color: scheme.onSurface)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── User card ─────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: scheme.primaryContainer,
                        child: hasPhoto
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                TextButton(
                  onPressed: handleSignOut,
                  child: Text(
                    'Switch Account',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Account Setup ─────────────────────────────────────────────────
          SettingsSection(
            label: 'Account Setup',
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Change profile picture and change username',
                onTap: () => context.push('/settings/profile'),
              ),
              SettingsTile(
                icon: Icons.lock_outline,
                title: 'Account Security',
                subtitle: 'Change Password, Two Factor Auth, Login Device',
                onTap: () => context.push('/settings/account-security'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Preferences ───────────────────────────────────────────────────
          SettingsSection(
            label: 'Preferences',
            children: [
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage your notifications',
                showChevron: false,
                trailing: Switch(
                  value: notificationsEnabled,
                  activeThumbColor: scheme.primary,
                  onChanged: toggleNotifications,
                ),
              ),
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Change Theme',
                subtitle: 'Dark Mode, Light Mode, adjust as you like',
                onTap: () => context.push('/settings/change-theme'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Additional Settings ───────────────────────────────────────────
          SettingsSection(
            label: 'Additional Settings',
            children: [
              SettingsTile(
                icon: Icons.person_remove_outlined,
                title: 'Delete Account',
                subtitle: 'Delete your account',
                onTap: () => context.push('/settings/delete-account'),
              ),
              SettingsTile(
                icon: Icons.logout,
                title: 'Log Out Account',
                subtitle: 'Log out of your account',
                onTap: handleSignOut,
              ),
            ],
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}
