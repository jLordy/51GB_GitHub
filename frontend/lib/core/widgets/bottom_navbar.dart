import 'dart:ui';

import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/voice_companion/screens/companion_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/theme/palette.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BottomNavbar
//
//  Role-aware bottom navigation bar.
//
//  • Patient / unknown  → Home | Journal | [center] | Notifications | Assistance
//  • Doctor             → Dashboard | Community | [center] | Patients | Notifications
//  • Caregiver          → Home | Journal | [center] | Notifications | Assistance
//
//  The selected tab is derived from the current GoRouter location so callers
//  do not need to manage [selectedIndex] manually (it is kept only for
//  backward compatibility and is ignored when a route match is found).
//  All tap callbacks are optional; the bar routes internally via [context.go].
// ─────────────────────────────────────────────────────────────────────────────

class BottomNavbar extends ConsumerWidget {
  const BottomNavbar({
    super.key,
    this.selectedIndex = 0,
    this.onHomeTap = _noop,
    this.onJournalTap = _noop,
    this.onCenterTap = _noop,
    this.onNotificationsTap = _noop,
    this.onAssistanceTap = _noop,
  });

  final int selectedIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onJournalTap;
  final VoidCallback onCenterTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAssistanceTap;

  static void _noop() {}

  // ── Route → index maps ───────────────────────────────────────────────────

  static int _patientIndex(String path) {
    if (path == '/home') return 0;
    if (path.startsWith('/journal') || path.startsWith('/monitoring')) return 1;
    if (path.startsWith('/reminder')) return 2;
    if (path.startsWith('/assistance')) return 3;
    return -1;
  }

  static int _doctorIndex(String path) {
    if (path == '/doctor-dashboard') return 0;
    if (path == '/patients' || path.startsWith('/patients/')) return 1;
    if (path.startsWith('/patients-journal')) return 2;
    if (path.startsWith('/notifications')) return 3;
    return -1;
  }

  static int _secretaryIndex(String path) {
    if (path == '/doctor-dashboard') return 0;
    if (path == '/patients' || path.startsWith('/patients/')) return 1;
    if (path.startsWith('/patients-journal')) return 2;
    if (path.startsWith('/notifications')) return 3;
    return -1;
  }

  static int _caregiverIndex(String path) {
    if (path == '/home') return 0;
    if (path.startsWith('/patients')) return 1;
    if (path.startsWith('/notifications')) return 2;
    if (path.startsWith('/assistance')) return 3;
    return -1;
  }

  static int _adminIndex(String path) {
    if (path.startsWith('/admin/dashboard')) return 0;
    if (path.startsWith('/admin/users')) return 1;
    if (path == '/community' || path.startsWith('/community')) return 2;
    if (path.startsWith('/admin/assistance')) return 3;
    return -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData appTheme = ref.watch(themeNotifierProvider);
    final bool isDark = appTheme.brightness == Brightness.dark;
    final Color selectedColor = Palette.greenColor;
    final Color unselectedColor = isDark
        ? Palette.lightSurfaceColor
        : Palette.darkSurfaceColor.withValues(alpha: 0.84);

    final role = ref.watch(currentUserProvider)?.role.toLowerCase() ?? '';
    final isAdmin = role == 'admin';
    final isDoctor = role == 'doctor';
    final isSecretary = role == 'secretary';
    final isCaregiver = role == 'caregiver';

    String? path;
    try {
      path = GoRouterState.of(context).uri.path;
    } catch (_) {
      path = null;
    }
    final computedIndex = path == null
        ? -1
        : isAdmin
        ? _adminIndex(path)
        : isDoctor
        ? _doctorIndex(path)
        : isSecretary
        ? _secretaryIndex(path)
        : isCaregiver
        ? _caregiverIndex(path)
        : _patientIndex(path);
    final activeIndex = computedIndex != -1 ? computedIndex : selectedIndex;

    // ── Shared shell ─────────────────────────────────────────────────────────
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(28, 0, 28, 12),
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 66,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
                          Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.22 : 0.30,
                        ),
                        width: 1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.26 : 0.12,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: isAdmin
                        ? _AdminItems(
                            activeIndex: activeIndex,
                            selectedColor: selectedColor,
                            unselectedColor: unselectedColor,
                          )
                        : isDoctor
                        ? _DoctorItems(
                            activeIndex: activeIndex,
                            selectedColor: selectedColor,
                            unselectedColor: unselectedColor,
                          )
                        : isSecretary
                        ? _SecretaryItems(
                            activeIndex: activeIndex,
                            selectedColor: selectedColor,
                            unselectedColor: unselectedColor,
                          )
                        : isCaregiver
                        ? _CaregiverItems(
                            activeIndex: activeIndex,
                            selectedColor: selectedColor,
                            unselectedColor: unselectedColor,
                          )
                        : _PatientItems(
                            activeIndex: activeIndex,
                            selectedColor: selectedColor,
                            unselectedColor: unselectedColor,
                            onJournalTap: onJournalTap,
                            onHomeTap: onHomeTap,
                            onNotificationsTap: onNotificationsTap,
                            onAssistanceTap: onAssistanceTap,
                          ),
                  ),
                ),
              ),
            ),
            // ── Centre Agapay button ────────────────────────────────────────
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () {
                  showCompanionOverlay(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/agapay_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: isDark
                          ? Palette.darkSurfaceColor
                          : Palette.lightSurfaceColor,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.spa_outlined,
                        size: 24,
                        color: selectedColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Admin tab row  (Dashboard | Users | [gap] | Community | Settings)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminItems extends StatelessWidget {
  const _AdminItems({
    required this.activeIndex,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final int activeIndex;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _NavItem(
          icon: Icons.dashboard_outlined,
          isSelected: activeIndex == 0,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/admin/dashboard'),
        ),
        _NavItem(
          icon: Icons.manage_accounts_outlined,
          isSelected: activeIndex == 1,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/admin/users'),
        ),
        const SizedBox(width: 58),
        _NavItem(
          icon: Icons.groups_outlined,
          isSelected: activeIndex == 2,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/community'),
        ),
        _NavItem(
          icon: Icons.front_hand_outlined,
          isSelected: activeIndex == 3,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/admin/assistance'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Patient tab row  (Home | Journal | [gap] | Notifications | Assistance)
// ─────────────────────────────────────────────────────────────────────────────

class _PatientItems extends StatelessWidget {
  const _PatientItems({
    required this.activeIndex,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onHomeTap,
    required this.onJournalTap,
    required this.onNotificationsTap,
    required this.onAssistanceTap,
  });

  final int activeIndex;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onHomeTap;
  final VoidCallback onJournalTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAssistanceTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _NavItem(
          icon: Icons.home_outlined,
          isSelected: activeIndex == 0,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () {
            onHomeTap();
            context.go('/home');
          },
        ),
        _NavItem(
          icon: Icons.edit_outlined,
          isSelected: activeIndex == 1,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () {
            onJournalTap();
            context.go('/journal');
          },
        ),
        const SizedBox(width: 58),
        _NavItem(
          icon: Icons.medication_rounded,
          isSelected: activeIndex == 2,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () {
            onNotificationsTap();
            context.go('/reminder');
          },
        ),
        _NavItem(
          icon: Icons.front_hand_outlined,
          isSelected: activeIndex == 3,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () {
            onAssistanceTap();
            context.go('/assistance');
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Doctor tab row  (Dashboard | Community | [gap] | Patients | Notifications)
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorItems extends StatelessWidget {
  const _DoctorItems({
    required this.activeIndex,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final int activeIndex;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _NavItem(
          icon: Icons.dashboard_outlined,
          isSelected: activeIndex == 0,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/doctor-dashboard'),
        ),
        _NavItem(
          icon: Icons.people_outline,
          isSelected: activeIndex == 1,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/patients'),
        ),
        const SizedBox(width: 58),
        _NavItem(
          icon: Icons.folder_shared_outlined,
          isSelected: activeIndex == 2,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/patients-journal'),
        ),
        _NavItem(
          icon: Icons.notifications_none,
          isSelected: activeIndex == 3,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/notifications'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary tab row  (Dashboard | Patients | [gap] | Journal | Notifications)
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryItems extends StatelessWidget {
  const _SecretaryItems({
    required this.activeIndex,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final int activeIndex;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _NavItem(
          icon: Icons.dashboard_outlined,
          isSelected: activeIndex == 0,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/doctor-dashboard'),
        ),
        _NavItem(
          icon: Icons.people_outline,
          isSelected: activeIndex == 1,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/patients'),
        ),
        const SizedBox(width: 58),
        _NavItem(
          icon: Icons.folder_shared_outlined,
          isSelected: activeIndex == 2,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/patients-journal'),
        ),
        _NavItem(
          icon: Icons.notifications_none,
          isSelected: activeIndex == 3,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/notifications'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Caregiver tab row  (Home | Journal | [gap] | Notifications | Assistance)
// ─────────────────────────────────────────────────────────────────────────────

class _CaregiverItems extends StatelessWidget {
  const _CaregiverItems({
    required this.activeIndex,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final int activeIndex;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _NavItem(
          icon: Icons.home_outlined,
          isSelected: activeIndex == 0,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/home'),
        ),
        _NavItem(
          icon: Icons.folder_shared_outlined,
          isSelected: activeIndex == 1,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/patients-journal'),
        ),
        const SizedBox(width: 58),
        _NavItem(
          icon: Icons.notifications_none,
          isSelected: activeIndex == 2,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/notifications'),
        ),
        _NavItem(
          icon: Icons.front_hand_outlined,
          isSelected: activeIndex == 3,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => context.go('/assistance'),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
    this.isSelected = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
