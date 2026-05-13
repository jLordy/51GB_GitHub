import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/dashboard/presentation/widgets/doctor_availability_widget.dart';
import 'package:frontend/features/dashboard/presentation/widgets/family_sync_status.dart';
import 'package:frontend/features/dashboard/presentation/widgets/health_summary_preview.dart';
import 'package:frontend/features/dashboard/presentation/widgets/journal_quick_log.dart';
import 'package:frontend/features/dashboard/presentation/widgets/lifestyle_tip_card.dart';
import 'package:frontend/features/dashboard/presentation/widgets/medication_card.dart';
import 'package:frontend/features/dashboard/presentation/widgets/recent_documents_widget.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeNotifierProvider);
    final cs = appTheme.colorScheme;
    final isDark = appTheme.brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    final currentUser = ref.watch(currentUserProvider);
    final role = currentUser?.role.toLowerCase() ?? 'patient';
    final firstName = currentUser?.displayName?.split(' ').first ?? 'User';
    final greeting = _timeGreeting();

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
        title: Text(
          'AGAPAY',
          style: const TextStyle(
            fontFamily: 'TanSongbird',
            fontSize: 22,
            color: Palette.greenColor,
            letterSpacing: 0.5,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.notifications_none_outlined,
              color: cs.onSurfaceVariant,
            ),
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
        children: <Widget>[
          // ── Decorative ambient orbs — give BackdropFilter something to blur ──
          Positioned(
            top: -60,
            right: -60,
            child: _AmbientOrb(
              size: 220,
              color: Palette.greenColor.withValues(
                alpha: isDark ? 0.18 : 0.14,
              ),
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
              color: Palette.greenColor.withValues(
                alpha: isDark ? 0.12 : 0.09,
              ),
            ),
          ),

          // ── Scrollable dashboard content ──────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    // Greeting header
                    _GreetingHeader(
                      greeting: greeting,
                      firstName: firstName,
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // Quick stats row (always shown)
                    _QuickStatsRow(cs: cs, isDark: isDark),
                    const SizedBox(height: 16),

                    // Health trend sparkline
                    const HealthSummaryPreview(),
                    const SizedBox(height: 12),

                    // Medication adherence card (patients only)
                    if (role == 'patient') ...<Widget>[
                      const MedicationCard(),
                      const SizedBox(height: 12),
                    ],

                    // Quick log shortcuts
                    const JournalQuickLog(),
                    const SizedBox(height: 12),

                    // Doctor appointment
                    const DoctorAvailabilityWidget(),
                    const SizedBox(height: 12),

                    // Family / connections sync
                    const FamilySyncStatus(),
                    const SizedBox(height: 12),

                    // Recent documents (patients only — others use patient picker)
                    if (role == 'patient') ...<Widget>[
                      const RecentDocumentsWidget(),
                      const SizedBox(height: 12),
                    ],

                    // Daily lifestyle tip
                    const LifestyleTipCard(),
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
//  Greeting header
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.greeting,
    required this.firstName,
    required this.cs,
    required this.isDark,
  });

  final String greeting;
  final String firstName;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$greeting, $firstName',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Here's your health snapshot for today.",
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick stats row — three pill-shaped metric chips
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.cs, required this.isDark});

  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final stats = <(IconData, String, String)>[
      (Icons.favorite_outline, '118/76', 'BP'),
      (Icons.bedtime_outlined, '7.2 hrs', 'Sleep'),
      (Icons.sentiment_satisfied_outlined, 'Good', 'Mood'),
    ];

    return Row(
      children: stats.map((s) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: s == stats.last ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Palette.darkSurfaceContainerColor
                  : Colors.white.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.60),
              ),
            ),
            child: Column(
              children: <Widget>[
                Icon(s.$1, color: Palette.greenColor, size: 18),
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
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ambient orb — blurred circle that gives BackdropFilter something to blur
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
