import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_controller.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LeftSidebar extends ConsumerStatefulWidget {
  const LeftSidebar({super.key});

  @override
  ConsumerState<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends ConsumerState<LeftSidebar> {
  @override
  void initState() {
    super.initState();
    // Dismiss any visible snackbar the moment the drawer opens.
    // SnackBars live in ScaffoldMessenger's overlay (above the Scaffold layer)
    // so they can't be z-indexed below the drawer — clearing them is the
    // only reliable fix.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppSnackBar.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData appTheme = ref.watch(themeNotifierProvider);
    final ColorScheme scheme = appTheme.colorScheme;
    final authState = ref.watch(authStateProvider);
    final authUser = authState.asData?.value;
    final currentUser = ref.watch(currentUserProvider);
    final bool isSigningOut = ref.watch(authControllerProvider).isLoading;
    final bool isAuthenticated =
        authUser != null && authUser.isAnonymous == false;
    final String displayName =
        currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : (authUser?.displayName?.trim().isNotEmpty == true
              ? authUser!.displayName!.trim()
              : (authUser?.email ?? 'Guest User'));
    final String? photoUrl = authUser?.photoURL?.trim();
    final String roleLabel = isAuthenticated
        ? _formatRoleLabel(currentUser?.role)
        : 'Guest';
    final bool isAdmin = currentUser?.role.toLowerCase() == 'admin';
    final bool isDark = appTheme.brightness == Brightness.dark;
    final Color drawerBackground = appTheme.scaffoldBackgroundColor;
    final Color textColor = scheme.onSurface;
    final Color avatarColor = scheme.surfaceContainerHighest;
    final Color dividerColor = scheme.outlineVariant;

    final double screenWidth = MediaQuery.of(context).size.width;
    // Use 85 % of screen width, capped at 304 (Material spec max).
    final double drawerWidth = (screenWidth * 0.85).clamp(0.0, 304.0);

    return Drawer(
      width: drawerWidth,
      backgroundColor: drawerBackground,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: ColoredBox(
          color: drawerBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: scheme.outline,
                      child: ClipOval(
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  width: 62,
                                  height: 62,
                                  color: avatarColor,
                                  child: Icon(
                                    Icons.person,
                                    size: 32,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                placeholder: (_, _) => Container(
                                  width: 62,
                                  height: 62,
                                  color: avatarColor,
                                ),
                              )
                            : Container(
                                width: 62,
                                height: 62,
                                color: avatarColor,
                                child: Icon(
                                  Icons.person,
                                  size: 32,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 33 / 2,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isAuthenticated && currentUser != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: dividerColor, height: 1),
                const SizedBox(height: 24),
                Column(
                  children: <Widget>[
                    if (!isAdmin) ...<Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _MenuCard(
                              Icons.description_outlined,
                              'Documents',
                              () {
                                Navigator.of(context).pop();
                                context.go('/documents');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MenuCard(
                              Icons.calendar_month_outlined,
                              'Calendar',
                              () {
                                Navigator.of(context).pop();
                                context.go('/calendar');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _MenuCard(
                              Icons.playlist_add_check,
                              'Summary',
                              () {
                                Navigator.of(context).pop();
                                final role =
                                    currentUser?.role.toLowerCase() ?? '';
                                final isProfessional =
                                    role == 'doctor' ||
                                    role == 'caregiver' ||
                                    role == 'secretary';
                                context.go(
                                  isProfessional ? '/report-picker' : '/report',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MenuCard(
                              Icons.settings_outlined,
                              'Settings',
                              () {
                                Navigator.of(context).pop();
                                context.go('/settings');
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _MenuCard(
                              Icons.settings_outlined,
                              'Settings',
                              () {
                                Navigator.of(context).pop();
                                context.go('/settings');
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 6,
                        child: isAuthenticated
                            ? ElevatedButton(
                                onPressed: isSigningOut
                                    ? null
                                    : () async {
                                        final router = GoRouter.of(context);
                                        Navigator.pop(context);
                                        await ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .signOut();
                                        router.go('/login');
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  disabledBackgroundColor: scheme.primary
                                      .withValues(alpha: 0.55),
                                  disabledForegroundColor: scheme.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  isSigningOut ? 'Signing out...' : 'Sign out',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Row(
                                children: <Widget>[
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => context.go('/login'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: scheme.primary,
                                        foregroundColor: scheme.onPrimary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => context.go('/register'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            scheme.primaryContainer,
                                        foregroundColor:
                                            scheme.onPrimaryContainer,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Register',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          ref
                              .read(themeNotifierProvider.notifier)
                              .toggleTheme();
                        },
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: textColor,
                        ),
                        tooltip: isDark
                            ? 'Switch to light mode'
                            : 'Switch to dark mode',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends ConsumerWidget {
  const _MenuCard(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData appTheme = ref.watch(themeNotifierProvider);
    final ColorScheme scheme = appTheme.colorScheme;
    final Color borderColor = scheme.outline;
    final Color iconColor = appTheme.iconTheme.color ?? scheme.onSurface;
    final Color labelColor = scheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 28, color: iconColor),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 35 / 2,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRoleLabel(String? role) {
  String raw = (role ?? '').trim();
  if (raw.isEmpty) {
    return 'User';
  }

  // Strip enum-style prefixes like "UserRole.patient" → "patient"
  final int dotIndex = raw.lastIndexOf('.');
  if (dotIndex != -1) {
    raw = raw.substring(dotIndex + 1).trim();
  }
  if (raw.isEmpty) return 'User';

  return raw
      .split(RegExp(r'[\s_-]+'))
      .where((String segment) => segment.isNotEmpty)
      .map((String segment) {
        if (segment.length == 1) {
          return segment.toUpperCase();
        }
        return '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}';
      })
      .join(' ');
}
