import 'dart:math' as math;

import 'package:frontend/features/connections/presentation/widgets/painters.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Care-team member data
// ─────────────────────────────────────────────────────────────────────────────

class CareTeamMember {
  final String displayName;
  final String connectionId;
  final bool isDoctor;
  final bool isPatient;

  const CareTeamMember({
    required this.displayName,
    required this.connectionId,
    required this.isDoctor,
    this.isPatient = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Health Circle Visualization
// ─────────────────────────────────────────────────────────────────────────────

class HealthCircleView extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final List<CareTeamMember> members;
  final void Function(CareTeamMember)? onMemberTap;

  /// Optional patient sub-orbit for secretary view.
  /// Key = index into [members]; value = list of patient display names.
  final Map<int, List<String>> patientSubOrbit;

  /// Called when a patient sub-node is tapped.
  /// Parameters: member index, patient display name.
  final void Function(int memberIndex, String patientName)? onPatientSubTap;

  /// Optional secretary sub-orbit for patient view.
  /// Key = index into [members] (doctor node); value = list of secretary display names.
  final Map<int, List<String>> secretarySubOrbit;

  /// Called when a secretary sub-node is tapped.
  /// Parameters: member index, secretary display name.
  final void Function(int memberIndex, String secretaryName)? onSecretarySubTap;

  const HealthCircleView({
    super.key,
    required this.pulseAnimation,
    required this.members,
    this.onMemberTap,
    this.patientSubOrbit = const {},
    this.onPatientSubTap,
    this.secretarySubOrbit = const {},
    this.onSecretarySubTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final n = members.length;

        final centerPos = Offset(w / 2, n > 0 && n <= 4 ? h * 0.28 : h * 0.38);

        // ── Empty state ────────────────────────────────────────────────
        if (n == 0) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: centerPos.dx - 60,
                top: centerPos.dy - 60,
                child: CenterNode(pulseAnimation: pulseAnimation),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.62,
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.greenColor.withValues(alpha: 0.07),
                        border: Border.all(
                          color: Palette.greenColor.withValues(alpha: 0.20),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        size: 28,
                        color: Palette.greenColor.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add your care team',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            (isDark
                                    ? Palette.darkOnSurfaceColor
                                    : const Color(0xFF374151))
                                .withValues(alpha: 0.50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to connect with a doctor\nor fellow patient',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color:
                            (isDark
                                    ? Palette.darkOnSurfaceColor
                                    : const Color(0xFF374151))
                                .withValues(alpha: 0.38),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // ── Adaptive node half-size based on member count ──────────────
        final double nodeHalf = n <= 2
            ? 46.0
            : n <= 4
            ? 38.0
            : 30.0;

        final maxRadiusX = w / 2 - nodeHalf - 12;
        final maxRadiusY = h * 0.52 - nodeHalf;
        final radius = math.max(
          nodeHalf * 2.4 + 20,
          math.min(maxRadiusX, maxRadiusY).clamp(80.0, 190.0),
        );

        // ── Positions: downward fan for ≤4 nodes, circular for 5+ ─────
        final positions = List.generate(n, (i) {
          final double angle;
          if (n <= 4) {
            // Fan opening downward from the center node, like tree branches.
            const down = math.pi / 2;
            final spread = n == 1
                ? 0.0
                : n == 2
                ? math.pi *
                      0.40 // ≈72°
                : n == 3
                ? math.pi *
                      0.60 // ≈108°
                : math.pi * 0.75; // ≈135°
            angle = n == 1 ? down : down - spread / 2 + spread * i / (n - 1);
          } else {
            angle = math.pi / 2 + (2 * math.pi * i / n);
          }
          return Offset(
            centerPos.dx + radius * math.cos(angle),
            centerPos.dy + radius * math.sin(angle),
          );
        });

        // ── Patient sub-orbit data ─────────────────────────────────
        const double patRadius = 130.0;
        const double patAvatarSize = 44.0;
        const double patGlowHalf = (patAvatarSize + 8) / 2; // 26
        const double patNodeHalf = 44.0; // half of sub-node widget width

        // Build per-doctor patient positions and lines
        final List<({Offset from, Offset to})> patLines = [];
        // Map: memberIndex → list of (name, position)
        final Map<int, List<({String name, Offset pos})>> patData = {};

        // Secretary sub-orbit constants (violet)
        const double secRadius = 130.0;
        const double secAvatarSize = 44.0;
        const double secGlowHalf = (secAvatarSize + 8) / 2; // 26
        const double secNodeHalf = 44.0;

        final List<({Offset from, Offset to})> secLines = [];
        final Map<int, List<({String name, Offset pos})>> secData = {};

        for (final entry in patientSubOrbit.entries) {
          final i = entry.key;
          final names = entry.value;
          if (i >= n || names.isEmpty) continue;

          final docPos = positions[i];
          final nc = names.length;
          final outAngle = math.atan2(
            docPos.dy - centerPos.dy,
            docPos.dx - centerPos.dx,
          );
          final double halfFan = nc == 1
              ? 0.0
              : nc == 2
              ? math.pi / 8
              : math.pi / 6;
          final double fanStep = nc <= 1 ? 0.0 : halfFan * 2 / (nc - 1);

          final entries2 = <({String name, Offset pos})>[];
          for (int j = 0; j < nc; j++) {
            final angle = outAngle - halfFan + j * fanStep;
            final patPos = Offset(
              docPos.dx + patRadius * math.cos(angle),
              docPos.dy + patRadius * math.sin(angle),
            );
            entries2.add((name: names[j], pos: patPos));
            patLines.add((from: docPos, to: patPos));
          }
          patData[i] = entries2;
        }

        // Build secretary sub-orbit (under doctor nodes, for patient view)
        for (final entry in secretarySubOrbit.entries) {
          final i = entry.key;
          final names = entry.value;
          if (i >= n || names.isEmpty) continue;

          final docPos = positions[i];
          // Fan outward from center→doctor direction, offset slightly right
          // so it doesn't overlap with the patient sub-orbit if both exist.
          final outAngle =
              math.atan2(docPos.dy - centerPos.dy, docPos.dx - centerPos.dx) +
              math.pi / 12; // 15° offset
          final nc = names.length;
          final double halfFan = nc == 1
              ? 0.0
              : nc == 2
              ? math.pi / 8
              : math.pi / 6;
          final double fanStep = nc <= 1 ? 0.0 : halfFan * 2 / (nc - 1);

          final secEntries = <({String name, Offset pos})>[];
          for (int j = 0; j < nc; j++) {
            final angle = outAngle - halfFan + j * fanStep;
            final secPos = Offset(
              docPos.dx + secRadius * math.cos(angle),
              docPos.dy + secRadius * math.sin(angle),
            );
            secEntries.add((name: names[j], pos: secPos));
            secLines.add((from: docPos, to: secPos));
          }
          secData[i] = secEntries;
        }

        // Determine the total canvas height needed (base + any sub-orbit overflow).
        double maxSubOrbitBottom = h;
        for (final e in patData.values) {
          for (final p in e) {
            final bottom = p.pos.dy + patGlowHalf + 22;
            if (bottom > maxSubOrbitBottom) maxSubOrbitBottom = bottom;
          }
        }
        for (final e in secData.values) {
          for (final p in e) {
            final bottom = p.pos.dy + secGlowHalf + 22;
            if (bottom > maxSubOrbitBottom) maxSubOrbitBottom = bottom;
          }
        }
        final canvasH = math.max(h, maxSubOrbitBottom + 16);

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(300),
          minScale: 0.5,
          maxScale: 2.2,
          child: SizedBox(
            width: w,
            height: canvasH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Gradient connection lines ──────────────────────────────
                CustomPaint(
                  size: Size(w, canvasH),
                  painter: MultiConnectionLinesPainter(
                    center: centerPos,
                    targets: positions,
                  ),
                ),

                // ── Doctor→patient dashed lines ────────────────────────────
                if (patLines.isNotEmpty)
                  CustomPaint(
                    size: Size(w, canvasH),
                    painter: _PatientSubLinesPainter(segments: patLines),
                  ),

                // ── Doctor→secretary dashed lines (violet) ─────────────────
                if (secLines.isNotEmpty)
                  CustomPaint(
                    size: Size(w, canvasH),
                    painter: _SecretarySubLinesPainter(segments: secLines),
                  ),

                // ── Center "Me" node ───────────────────────────────────────
                Positioned(
                  left: centerPos.dx - 60,
                  top: centerPos.dy - 60,
                  child: CenterNode(pulseAnimation: pulseAnimation),
                ),

                // ── Care-team member nodes ─────────────────────────────────
                // PersonNode is fixed: width=92 → half=46, glow=84 → half=42.
                // Use those exact values so the avatar center sits on positions[i].
                for (int i = 0; i < n; i++)
                  Positioned(
                    left: positions[i].dx - 46,
                    top: positions[i].dy - 42,
                    child: PersonNode(
                      label: members[i].displayName,
                      jerseyType: members[i].isDoctor
                          ? JerseyType.magic
                          : members[i].isPatient
                          ? JerseyType.peer
                          : JerseyType.warriors,
                      showMessage: false,
                      showPhone: false,
                      onNodeTap: () => onMemberTap?.call(members[i]),
                    ),
                  ),

                // ── Patient sub-orbit nodes ────────────────────────────────
                for (final e in patData.entries)
                  for (final p in e.value)
                    Positioned(
                      left: p.pos.dx - patNodeHalf,
                      top: p.pos.dy - patGlowHalf,
                      child: _PatientSubNode(
                        displayName: p.name,
                        avatarSize: patAvatarSize,
                        nodeWidth: patNodeHalf * 2,
                        onTap: onPatientSubTap == null
                            ? null
                            : () => onPatientSubTap!(e.key, p.name),
                      ),
                    ),

                // ── Secretary sub-orbit nodes (violet) ──────────────────────
                for (final e in secData.entries)
                  for (final p in e.value)
                    Positioned(
                      left: p.pos.dx - secNodeHalf,
                      top: p.pos.dy - secGlowHalf,
                      child: _SecretarySubNode(
                        displayName: p.name,
                        avatarSize: secAvatarSize,
                        nodeWidth: secNodeHalf * 2,
                        onTap: onSecretarySubTap == null
                            ? null
                            : () => onSecretarySubTap!(e.key, p.name),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Center "Me" Node
// ─────────────────────────────────────────────────────────────────────────────

class CenterNode extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const CenterNode({super.key, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulsing halo
                  Transform.scale(
                    scale: pulseAnimation.value,
                    child: Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.greenColor.withValues(
                          alpha: 0.10 * (2.0 - pulseAnimation.value),
                        ),
                      ),
                    ),
                  ),
                  // Mid ring
                  Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Palette.greenColor.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Main gradient avatar
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF43A97A), Palette.greenColor],
                      ),
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.greenColor.withValues(alpha: 0.38),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF43A97A), Palette.greenColor],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Palette.greenColor.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              'You',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Child / Person Nodes
// ─────────────────────────────────────────────────────────────────────────────

class PersonNode extends StatelessWidget {
  final String label;
  final JerseyType jerseyType;
  final bool showMessage;
  final bool showPhone;
  final VoidCallback onNodeTap;
  final VoidCallback? onMessageTap;
  final VoidCallback? onPhoneTap;

  const PersonNode({
    super.key,
    required this.label,
    required this.jerseyType,
    required this.showMessage,
    required this.showPhone,
    required this.onNodeTap,
    this.onMessageTap,
    this.onPhoneTap,
  });

  Color get _roleColor => switch (jerseyType) {
    JerseyType.magic => const Color(0xFF3B82F6),
    JerseyType.peer  => const Color(0xFF0D9488),
    _                => const Color(0xFF7C3AED),
  };

  List<Color> get _gradientColors => switch (jerseyType) {
    JerseyType.magic => [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
    JerseyType.peer  => [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
    _                => [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
  };

  IconData get _roleIcon => switch (jerseyType) {
    JerseyType.magic => Icons.medical_services_rounded,
    JerseyType.peer  => Icons.people_rounded,
    _                => Icons.favorite_rounded,
  };

  String get _firstName => label.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onNodeTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Subtle glow backdrop
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _roleColor.withValues(alpha: 0.07),
                  ),
                ),
                // Gradient avatar
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _gradientColors,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _roleColor.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                // Role badge
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _roleColor,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _roleColor.withValues(alpha: 0.40),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(_roleIcon, size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _roleColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _firstName,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Palette.darkOnSurfaceColor
                    : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          if (showMessage || showPhone)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showMessage)
                    _ActionDot(
                      icon: Icons.chat_bubble_rounded,
                      color: _roleColor,
                      onTap: onMessageTap ?? () {},
                    ),
                  if (showMessage && showPhone) const SizedBox(width: 6),
                  if (showPhone)
                    _ActionDot(
                      icon: Icons.phone_rounded,
                      color: _roleColor,
                      onTap: onPhoneTap ?? () {},
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small action icon dot beneath a person node
// ─────────────────────────────────────────────────────────────────────────────

class _ActionDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionDot({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.38), width: 1.2),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Patient Sub-orbit Node  (small green node shown under a doctor node)
//  Used in the secretary view to display the doctor's patients.
// ─────────────────────────────────────────────────────────────────────────────

class _PatientSubNode extends StatelessWidget {
  final String displayName;
  final double avatarSize;
  final double nodeWidth;
  final VoidCallback? onTap;

  const _PatientSubNode({
    required this.displayName,
    required this.avatarSize,
    required this.nodeWidth,
    this.onTap,
  });

  static const _green1 = Color(0xFF43A97A);

  String get _firstName => displayName.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: nodeWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Glow halo
                Container(
                  width: avatarSize + 8,
                  height: avatarSize + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green1.withValues(alpha: 0.08),
                  ),
                ),
                // Avatar
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_green1, Palette.greenColor],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.greenColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: avatarSize * 0.52,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _green1.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _firstName,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Palette.darkOnSurfaceColor
                    : const Color(0xFF1A1A2E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter for doctor→patient dashed lines in secretary sub-orbit
// ─────────────────────────────────────────────────────────────────────────────

class _PatientSubLinesPainter extends CustomPainter {
  final List<({Offset from, Offset to})> segments;

  const _PatientSubLinesPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF43A97A).withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;

    for (final seg in segments) {
      final dx = seg.to.dx - seg.from.dx;
      final dy = seg.to.dy - seg.from.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist == 0) continue;
      final ux = dx / dist;
      final uy = dy / dist;
      double drawn = 0;
      bool drawing = true;
      while (drawn < dist) {
        final len = math.min(drawing ? dashWidth : dashGap, dist - drawn);
        if (drawing) {
          canvas.drawLine(
            Offset(seg.from.dx + ux * drawn, seg.from.dy + uy * drawn),
            Offset(
              seg.from.dx + ux * (drawn + len),
              seg.from.dy + uy * (drawn + len),
            ),
            paint,
          );
        }
        drawn += len;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_PatientSubLinesPainter old) => old.segments != segments;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Secretary Sub-orbit Node  (small violet node shown under a doctor node)
//  Used in the patient view to display the doctor's secretary.
// ─────────────────────────────────────────────────────────────────────────────

class _SecretarySubNode extends StatelessWidget {
  final String displayName;
  final double avatarSize;
  final double nodeWidth;
  final VoidCallback? onTap;

  const _SecretarySubNode({
    required this.displayName,
    required this.avatarSize,
    required this.nodeWidth,
    this.onTap,
  });

  static const _violet1 = Color(0xFF7C3AED);
  static const _violet2 = Color(0xFF6D28D9);

  String get _firstName => displayName.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: nodeWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Glow halo
                Container(
                  width: avatarSize + 8,
                  height: avatarSize + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _violet1.withValues(
                      alpha: onTap != null ? 0.18 : 0.10,
                    ),
                  ),
                ),
                // Avatar
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_violet1, _violet2],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _violet1.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.badge_rounded,
                    size: avatarSize * 0.48,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Palette.darkSurfaceContainerColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _violet1.withValues(alpha: 0.30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _firstName,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _violet1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter for doctor→secretary dashed lines in patient sub-orbit
// ─────────────────────────────────────────────────────────────────────────────

class _SecretarySubLinesPainter extends CustomPainter {
  final List<({Offset from, Offset to})> segments;

  const _SecretarySubLinesPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;

    for (final seg in segments) {
      final dx = seg.to.dx - seg.from.dx;
      final dy = seg.to.dy - seg.from.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist == 0) continue;
      final ux = dx / dist;
      final uy = dy / dist;
      double drawn = 0;
      bool drawing = true;
      while (drawn < dist) {
        final len = math.min(drawing ? dashWidth : dashGap, dist - drawn);
        if (drawing) {
          canvas.drawLine(
            Offset(seg.from.dx + ux * drawn, seg.from.dy + uy * drawn),
            Offset(
              seg.from.dx + ux * (drawn + len),
              seg.from.dy + uy * (drawn + len),
            ),
            paint,
          );
        }
        drawn += len;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_SecretarySubLinesPainter old) => old.segments != segments;
}
