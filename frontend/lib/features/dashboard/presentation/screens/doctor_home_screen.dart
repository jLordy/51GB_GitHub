import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

class DoctorHomeScreen extends ConsumerWidget {
  const DoctorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeNotifierProvider);
    final cs = appTheme.colorScheme;
    final isDark = appTheme.brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    final currentUser = ref.watch(currentUserProvider);
    final firstName = currentUser?.displayName?.split(' ').first ?? 'Doctor';
    final greeting = _timeGreeting();

    final acceptedAsync = ref.watch(acceptedConnectionsProvider);
    final pendingAsync = ref.watch(pendingConnectionsProvider);
    final profilesAsync = ref.watch(patientProfilesProvider);

    final myUid = currentUser?.uid ?? '';
    final acceptedList = acceptedAsync.value ?? [];
    final pendingList = pendingAsync.value ?? [];
    final profiles = profilesAsync.value ?? {};

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      drawerScrimColor: isDark
          ? Colors.black.withValues(alpha: 0.30)
          : Colors.black.withValues(alpha: 0.45),
      drawer: const LeftSidebar(),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
          ),
        ),
        title: const Text(
          'AGAPAY',
          style: TextStyle(
            fontFamily: 'TanSongbird',
            fontSize: 22,
            color: Palette.greenColor,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: cs.onSurfaceVariant),
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded, color: cs.onSurfaceVariant),
            onPressed: () => context.go('/chat'),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavbar(selectedIndex: 0),
      body: Stack(
        children: [
          // Ambient orbs
          Positioned(
            top: -60,
            right: -60,
            child: _AmbientOrb(
              size: 220,
              color: Palette.greenColor.withValues(alpha: isDark ? 0.18 : 0.14),
            ),
          ),
          Positioned(
            top: 180,
            left: -80,
            child: _AmbientOrb(
              size: 180,
              color: cs.primary.withValues(alpha: isDark ? 0.10 : 0.08),
            ),
          ),
          Positioned(
            bottom: 200,
            right: -40,
            child: _AmbientOrb(
              size: 140,
              color: Palette.greenColor.withValues(alpha: isDark ? 0.12 : 0.09),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Greeting
                    _GreetingHeader(
                      greeting: greeting,
                      firstName: firstName,
                      cs: cs,
                    ),
                    const SizedBox(height: 20),

                    // Stats row
                    _StatsRow(
                      totalPatients: acceptedList.length,
                      pendingRequests: pendingList.length,
                      isDark: isDark,
                      cs: cs,
                    ),
                    const SizedBox(height: 20),

                    // Pending requests banner
                    if (pendingList.isNotEmpty) ...[
                      _PendingBanner(count: pendingList.length, cs: cs, isDark: isDark),
                      const SizedBox(height: 16),
                    ],

                    // Patients section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Patients',
                          style: appTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (acceptedList.isNotEmpty)
                          Text(
                            '${acceptedList.length} connected',
                            style: appTheme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Patient list
                    acceptedAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => _ErrorCard(cs: cs, isDark: isDark),
                      data: (connections) {
                        if (connections.isEmpty) {
                          return _EmptyPatients(cs: cs, isDark: isDark);
                        }
                        return Column(
                          children: connections.map((conn) {
                            final patientUid = conn.otherUid(myUid);
                            final profile = profiles[patientUid];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PatientCard(
                                patientUid: patientUid,
                                profile: profile,
                                cs: cs,
                                isDark: isDark,
                                onMessage: () => context.go('/chat'),
                                onCalendar: () => context.go('/calendar'),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting header
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greeting,
    required this.firstName,
    required this.cs,
  });

  final String greeting;
  final String firstName;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, Dr. $firstName',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Here's your patient overview for today.",
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalPatients,
    required this.pendingRequests,
    required this.isDark,
    required this.cs,
  });

  final int totalPatients;
  final int pendingRequests;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final stats = [
      (Icons.people_outline_rounded, '$totalPatients', 'Patients'),
      (Icons.pending_outlined, '$pendingRequests', 'Pending'),
      (Icons.calendar_today_outlined, 'Today', 'Schedule'),
    ];

    return Row(
      children: List.generate(stats.length, (i) {
        final s = stats[i];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < stats.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Palette.darkSurfaceContainerColor
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),
            ),
            child: Column(
              children: [
                Icon(s.$1, color: Palette.greenColor, size: 20),
                const SizedBox(height: 4),
                Text(
                  s.$2,
                  style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                Text(
                  s.$3,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending requests banner
// ─────────────────────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.count,
    required this.cs,
    required this.isDark,
  });

  final int count;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/connections'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Palette.greenColor.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Palette.greenColor.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_add_outlined, color: Palette.greenColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count pending connection ${count == 1 ? 'request' : 'requests'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Palette.greenColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Palette.greenColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient card
// ─────────────────────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.patientUid,
    required this.profile,
    required this.cs,
    required this.isDark,
    required this.onMessage,
    required this.onCalendar,
  });

  final String patientUid;
  final PatientProfileModel? profile;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onMessage;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final name = profile?.fullName ?? 'Unknown Patient';
    final initials = _initials(name);
    final age = profile?.age;
    final illness = profile?.illnessType ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Palette.darkSurfaceContainerColor
            : Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.50)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Palette.greenColor.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: tt.titleSmall?.copyWith(
                color: Palette.greenColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (age != null) ...[
                      Text(
                        '$age yrs',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (illness.isNotEmpty)
                      _IllnessChip(illness: illness, isDark: isDark),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconAction(
                icon: Icons.chat_bubble_outline_rounded,
                color: Palette.greenColor,
                onTap: onMessage,
              ),
              const SizedBox(width: 6),
              _IconAction(
                icon: Icons.calendar_today_outlined,
                color: cs.onSurfaceVariant,
                onTap: onCalendar,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illness chip
// ─────────────────────────────────────────────────────────────────────────────

class _IllnessChip extends StatelessWidget {
  const _IllnessChip({required this.illness, required this.isDark});

  final String illness;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (illness.toLowerCase()) {
      'ckd' => ('CKD', const Color(0xFF2196F3)),
      'diabetes' => ('Diabetes', const Color(0xFFFF9800)),
      'oncology' => ('Oncology', const Color(0xFF9C27B0)),
      _ => (illness.isNotEmpty ? _capitalize(illness) : 'Other', const Color(0xFF607D8B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon action button
// ─────────────────────────────────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPatients extends StatelessWidget {
  const _EmptyPatients({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? Palette.darkSurfaceContainerColor
            : Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.50)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'No patients yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Accept connection requests to see your patients here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/connections'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Palette.greenColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Palette.greenColor.withValues(alpha: 0.30)),
              ),
              child: Text(
                'View Connections',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Palette.greenColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load patient list. Pull to refresh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient orb
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
