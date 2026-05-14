import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/assistance/controller/assistance_controller.dart';
import 'package:frontend/features/assistance/model/emergency_hotline.dart';
import 'package:frontend/features/assistance/model/financial_assistance.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AssistanceScreen extends ConsumerWidget {
  const AssistanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistanceAsync = ref.watch(assistanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Palette.darkSurfaceColor : const Color(0xFFF5F9F7);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      body: Stack(
        children: [
          // Decorative orbs
          Positioned(
            top: -60,
            right: -40,
            child: _Orb(color: Palette.greenColor.withValues(alpha: 0.18), size: 220),
          ),
          Positioned(
            top: 140,
            left: -60,
            child: _Orb(color: Colors.teal.withValues(alpha: 0.12), size: 180),
          ),
          SafeArea(
            bottom: false,
            child: assistanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Could not load assistance data.')),
              data: (data) => CustomScrollView(
                slivers: [
                  _buildAppBar(context, isDark),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: 'Financial Assistance Programs'),
                          const SizedBox(height: 12),
                          _FinancialAssistanceRow(programs: data.programs),
                          const SizedBox(height: 24),
                          _SectionLabel(label: 'Emergency Hotlines'),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.builder(
                      itemCount: data.hotlines.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HotlineCard(hotline: data.hotlines[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      pinned: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => context.go('/home'),
      ),
      title: const Text(
        'AGAPAY',
        style: TextStyle(
          fontFamily: 'TanSongbird',
          fontSize: 20,
          color: Palette.greenColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Decorative background orb ─────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}

// ── Horizontal financial assistance row ──────────────────────────────────────

class _FinancialAssistanceRow extends StatelessWidget {
  const _FinancialAssistanceRow({required this.programs});

  final List<FinancialAssistance> programs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: programs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _FinancialCard(program: programs[i]),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.program});

  final FinancialAssistance program;

  static const _categoryColors = <String, Color>{
    'Health Insurance': Color(0xFF3D8B6E),
    'Medical Aid': Color(0xFF2D7DD2),
    'Integrated Aid': Color(0xFF7B5EA7),
    'Social Welfare': Color(0xFFD4813B),
    'Government Aid': Color(0xFF3A8F9F),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _categoryColors[program.category] ?? Palette.greenColor;

    return GlassmorphicContainer(
      width: 164,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              program.category,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            program.providerName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            program.amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 12,
                color: isDark
                    ? Colors.white54
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                program.distance,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white54
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Emergency hotline card ────────────────────────────────────────────────────

class _HotlineCard extends StatelessWidget {
  const _HotlineCard({required this.hotline});

  final EmergencyHotline hotline;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: hotline.phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassmorphicContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.greenColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(hotline.icon, color: Palette.greenColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotline.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  hotline.phoneNumber,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _call,
            icon: const Icon(Icons.phone_outlined, size: 16),
            label: const Text('Call'),
            style: TextButton.styleFrom(
              foregroundColor: Palette.greenColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Palette.greenColor.withValues(alpha: 0.4),
                ),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
