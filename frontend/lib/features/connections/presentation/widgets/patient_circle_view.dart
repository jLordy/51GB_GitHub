import 'dart:math' as math;

import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/features/connections/model/user_connection_summary.dart';
import 'package:frontend/features/connections/presentation/widgets/health_circle_view.dart';
import 'package:frontend/features/connections/presentation/widgets/painters.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Doctor / Caregiver Circle View
//  Shows the current user at center with connected patients orbiting around.
// ─────────────────────────────────────────────────────────────────────────────

class PatientCircleView extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final List<UserModel> patients;

  /// Secretary connections – distinct violet nodes, no caregiver sub-orbit.
  final List<UserModel> secretaries;
  final List<ConnectionModel> connections;
  final String currentUid;
  final Map<String, List<UserConnectionSummary>> patientCaregivers;

  /// Secretaries of the patient's doctor(s) – rendered as a second-level
  /// sub-orbit hanging off each doctor node (caregiver view only).
  final Map<String, List<UserConnectionSummary>> patientDoctorSecretaries;

  final void Function(UserModel patient, String? connectionId)? onPatientTap;
  final void Function(UserConnectionSummary caregiver)? onCaregiverTap;
  final void Function(UserModel secretary, String? connectionId)?
  onSecretaryTap;

  const PatientCircleView({
    super.key,
    required this.pulseAnimation,
    required this.patients,
    this.secretaries = const [],
    required this.connections,
    required this.currentUid,
    this.patientCaregivers = const {},
    this.patientDoctorSecretaries = const {},
    this.onPatientTap,
    this.onCaregiverTap,
    this.onSecretaryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty && secretaries.isEmpty) {
      return _EmptyPatientsState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final allNodes = [...patients, ...secretaries];
        final secretaryUids = {for (final s in secretaries) s.uid};
        final n = allNodes.length;

        // ── Adaptive node sizing based on patient count ────────────────
        final double nodeHalf;
        final double avatarSize;
        if (n <= 2) {
          nodeHalf = 46.0;
          avatarSize = 76.0;
        } else if (n <= 4) {
          nodeHalf = 38.0;
          avatarSize = 64.0;
        } else if (n <= 7) {
          nodeHalf = 30.0;
          avatarSize = 50.0;
        } else {
          nodeHalf = 24.0;
          avatarSize = 40.0;
        }

        // ── Center "You" node position ─────────────────────────────────
        final centerPos = Offset(w / 2, h * 0.38);

        // ── Orbit radius: max space minus node size and a margin ───────
        final maxRadiusX = w / 2 - nodeHalf - 12;
        final maxRadiusY = h * 0.52 - nodeHalf;
        final radius = math.max(
          nodeHalf * 2.4 + 20,
          math.min(maxRadiusX, maxRadiusY).clamp(80.0, 190.0),
        );

        // ── Positions evenly distributed, starting from 6-o'clock ─────
        final positions = List.generate(n, (i) {
          final angle = math.pi / 2 + (2 * math.pi * i / n);
          return Offset(
            centerPos.dx + radius * math.cos(angle),
            centerPos.dy + radius * math.sin(angle),
          );
        });

        // ── Connection IDs per node ───────────────────────────────────────────────────
        final connIds = allNodes.map((u) {
          try {
            return connections
                .firstWhere(
                  (c) => c.requesterUid == u.uid || c.recipientUid == u.uid,
                )
                .connectionId;
          } catch (_) {
            return null;
          }
        }).toList();

        // ── Caregiver sub-orbit positions ──────────────────────────────
        const double careRadius = 100.0;
        const double careAvatarSize = 32.0;
        const double careGlowHalf = (careAvatarSize + 8) / 2; // = 20.0
        const double careNodeHalf =
            40.0; // half of 80px full node width → centers avatar on line endpoint

        final Map<String, List<({UserConnectionSummary cg, Offset pos})>>
        cgData = {};
        final List<({Offset from, Offset to})> cgLines = [];

        for (int i = 0; i < n; i++) {
          final uid = allNodes[i].uid;
          if (secretaryUids.contains(uid)) {
            continue; // secretaries have no sub-orbit
          }
          final caregivers = patientCaregivers[uid] ?? const [];
          if (caregivers.isEmpty) continue;

          final patPos = positions[i];
          final nc = caregivers.length;

          // Direction pointing outward from center through this patient node
          final outAngle = math.atan2(
            patPos.dy - centerPos.dy,
            patPos.dx - centerPos.dx,
          );

          // Fan: 0° spread for 1, ±22.5° for 2, ±30° for 3+
          final double halfFan = nc == 1
              ? 0.0
              : nc == 2
              ? math.pi / 8
              : math.pi / 6;
          final double fanStep = nc <= 1 ? 0.0 : halfFan * 2 / (nc - 1);

          final entries = <({UserConnectionSummary cg, Offset pos})>[];
          for (int j = 0; j < nc; j++) {
            final angle = outAngle - halfFan + j * fanStep;
            final cgPos = Offset(
              patPos.dx + careRadius * math.cos(angle),
              patPos.dy + careRadius * math.sin(angle),
            );
            entries.add((cg: caregivers[j], pos: cgPos));
            cgLines.add((from: patPos, to: cgPos));
          }
          cgData[uid] = entries;
        }

        // ── Secretary sub-orbit: fan each patient's doctor secretaries
        //    around the doctor node position (second level) ────────────
        const double secRadius = 78.0;
        const double secAvatarSize = 26.0;
        const double secGlowHalf = (secAvatarSize + 8) / 2; // 17.0
        const double secNodeHalf = 40.0;

        final Map<String, List<({UserConnectionSummary sec, Offset pos})>>
        secData = {};
        final List<({Offset from, Offset to})> secLines = [];

        for (final entry in patientDoctorSecretaries.entries) {
          final patUid = entry.key;
          final secs = entry.value;
          if (secs.isEmpty) continue;

          // Use all doctor nodes for this patient as anchor points.
          final doctorEntries = (cgData[patUid] ?? [])
              .where((e) => e.cg.role == 'doctor')
              .toList();
          if (doctorEntries.isEmpty) continue;

          // Distribute secretaries evenly across doctor nodes.
          final perDoc = (secs.length / doctorEntries.length).ceil();
          final results = <({UserConnectionSummary sec, Offset pos})>[];

          for (int di = 0; di < doctorEntries.length; di++) {
            final docPos = doctorEntries[di].pos;
            final mine = secs.skip(di * perDoc).take(perDoc).toList();
            if (mine.isEmpty) continue;

            // Fan outward from doctor away from the patient
            final patIdx = allNodes.indexWhere((u) => u.uid == patUid);
            final patPos = patIdx >= 0 ? positions[patIdx] : centerPos;
            final outAngle = math.atan2(
              docPos.dy - patPos.dy,
              docPos.dx - patPos.dx,
            );
            final ns = mine.length;
            final double halfFan = ns == 1
                ? 0.0
                : ns == 2
                ? math.pi / 8
                : math.pi / 6;
            final double fanStep = ns <= 1 ? 0.0 : halfFan * 2 / (ns - 1);

            for (int si = 0; si < ns; si++) {
              final angle = outAngle - halfFan + si * fanStep;
              final secPos = Offset(
                docPos.dx + secRadius * math.cos(angle),
                docPos.dy + secRadius * math.sin(angle),
              );
              results.add((sec: mine[si], pos: secPos));
              secLines.add((from: docPos, to: secPos));
            }
          }
          if (results.isNotEmpty) secData[patUid] = results;
        }

        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(300),
          minScale: 0.5,
          maxScale: 2.2,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Center→patient gradient lines ──────────────────────
                CustomPaint(
                  size: Size(w, h),
                  painter: MultiConnectionLinesPainter(
                    center: centerPos,
                    targets: positions,
                  ),
                ),

                // ── Patient→caregiver dashed lines ─────────────────────
                if (cgLines.isNotEmpty)
                  CustomPaint(
                    size: Size(w, h),
                    painter: _CaregiverLinesPainter(segments: cgLines),
                  ),

                // ── Doctor→secretary dashed lines (violet) ─────────────
                if (secLines.isNotEmpty)
                  CustomPaint(
                    size: Size(w, h),
                    painter: _SecretaryLinesPainter(segments: secLines),
                  ),

                // ── Center "You" node ───────────────────────────────────
                Positioned(
                  left: centerPos.dx - 60,
                  top: centerPos.dy - 60,
                  child: CenterNode(pulseAnimation: pulseAnimation),
                ),

                // ── Patient / Secretary nodes ───────────────────────────────────
                for (int i = 0; i < n; i++)
                  Positioned(
                    left: positions[i].dx - nodeHalf,
                    top: positions[i].dy - (avatarSize + 8) / 2,
                    child: secretaryUids.contains(allNodes[i].uid)
                        ? SecretaryNode(
                            secretary: allNodes[i],
                            nodeSize: nodeHalf * 2,
                            avatarSize: avatarSize,
                            onTap: onSecretaryTap == null
                                ? null
                                : () =>
                                      onSecretaryTap!(allNodes[i], connIds[i]),
                          )
                        : PatientNode(
                            patient: allNodes[i],
                            nodeSize: nodeHalf * 2,
                            avatarSize: avatarSize,
                            onTap: onPatientTap == null
                                ? null
                                : () => onPatientTap!(allNodes[i], connIds[i]),
                          ),
                  ),

                // ── Caregiver nodes ─────────────────────────────────────
                for (final e in cgData.values.expand((l) => l))
                  Positioned(
                    left: e.pos.dx - careNodeHalf,
                    top: e.pos.dy - careGlowHalf,
                    child: _CaregiverNode(
                      displayName: e.cg.displayName,
                      role: e.cg.role,
                      avatarSize: careAvatarSize,
                      onTap: onCaregiverTap == null
                          ? null
                          : () => onCaregiverTap!(e.cg),
                    ),
                  ),

                // ── Secretary nodes (sub-orbit of doctor) ───────────────
                for (final e in secData.values.expand((l) => l))
                  Positioned(
                    left: e.pos.dx - secNodeHalf,
                    top: e.pos.dy - secGlowHalf,
                    child: _CaregiverNode(
                      displayName: e.sec.displayName,
                      role: 'secretary',
                      avatarSize: secAvatarSize,
                      onTap: onCaregiverTap == null
                          ? null
                          : () => onCaregiverTap!(e.sec),
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
//  Patient Orbit Node
// ─────────────────────────────────────────────────────────────────────────────

class PatientNode extends StatelessWidget {
  final UserModel patient;
  final double nodeSize;
  final double avatarSize;
  final VoidCallback? onTap;

  const PatientNode({
    super.key,
    required this.patient,
    required this.nodeSize,
    required this.avatarSize,
    this.onTap,
  });

  static const _green1 = Color(0xFF43A97A);

  String get _firstName =>
      (patient.displayName ?? patient.email ?? 'P').split(' ').first;

  double get _fontSize => avatarSize >= 68
      ? 11.0
      : avatarSize >= 52
      ? 10.0
      : 9.0;

  double get _badgeSize => avatarSize >= 60 ? 22.0 : 16.0;
  double get _badgeIconSize => avatarSize >= 60 ? 11.0 : 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: nodeSize,
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
                // Gradient avatar
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
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.greenColor.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: avatarSize * 0.5,
                    color: Colors.white,
                  ),
                ),
                // Patient badge
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: _badgeSize,
                    height: _badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.greenColor,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.greenColor.withValues(alpha: 0.38),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: _badgeIconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: avatarSize >= 60 ? 10 : 7,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Palette.greenColor.withValues(alpha: 0.25),
              ),
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
                fontSize: _fontSize,
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
//  Secretary Orbit Node  (violet accent — distinct from green patient nodes)
// ─────────────────────────────────────────────────────────────────────────────

class SecretaryNode extends StatelessWidget {
  final UserModel secretary;
  final double nodeSize;
  final double avatarSize;
  final VoidCallback? onTap;

  const SecretaryNode({
    super.key,
    required this.secretary,
    required this.nodeSize,
    required this.avatarSize,
    this.onTap,
  });

  static const _violet1 = Color(0xFF7C3AED);
  static const _violet2 = Color(0xFF6D28D9);

  String get _firstName =>
      (secretary.displayName ?? secretary.email ?? 'S').split(' ').first;

  double get _fontSize => avatarSize >= 68
      ? 11.0
      : avatarSize >= 52
      ? 10.0
      : 9.0;
  double get _badgeSize => avatarSize >= 60 ? 22.0 : 16.0;
  double get _badgeIconSize => avatarSize >= 60 ? 11.0 : 8.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: nodeSize,
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
                    color: _violet1.withValues(alpha: 0.08),
                  ),
                ),
                // Gradient avatar
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
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _violet1.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.manage_accounts_rounded,
                    size: avatarSize * 0.5,
                    color: Colors.white,
                  ),
                ),
                // Secretary badge
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: _badgeSize,
                    height: _badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _violet1,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _violet1.withValues(alpha: 0.38),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: _badgeIconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: avatarSize >= 60 ? 10 : 7,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _violet1.withValues(alpha: 0.30)),
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
                fontSize: _fontSize,
                fontWeight: FontWeight.w700,
                color: _violet1,
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
//  Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPatientsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF374151);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 52,
            color: textColor.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 14),
          Text(
            'No patients connected yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Patients can send you a request\nto appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.38),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Caregiver orbit node  (small sky-blue node orbiting a patient)
// ─────────────────────────────────────────────────────────────────────────────

class _CaregiverNode extends StatelessWidget {
  final String displayName;
  final String role;
  final double avatarSize;
  final VoidCallback? onTap;

  const _CaregiverNode({
    required this.displayName,
    required this.role,
    required this.avatarSize,
    this.onTap,
  });

  static const _care1 = Color(0xFF0EA5E9);
  static const _care2 = Color(0xFF0284C7);
  static const _doc1 = Color(0xFFD97706);
  static const _doc2 = Color(0xFFB45309);
  static const _sec1 = Color(0xFF7C3AED);
  static const _sec2 = Color(0xFF6D28D9);

  bool get _isDoctor => role == 'doctor';
  bool get _isSecretary => role == 'secretary';

  Color get _color1 => _isDoctor
      ? _doc1
      : _isSecretary
      ? _sec1
      : _care1;
  Color get _color2 => _isDoctor
      ? _doc2
      : _isSecretary
      ? _sec2
      : _care2;
  IconData get _icon => _isDoctor
      ? Icons.medical_services_rounded
      : _isSecretary
      ? Icons.badge_rounded
      : Icons.favorite_rounded;

  String get _shortName {
    final first = displayName.split(' ').first;
    return first.isEmpty ? 'C' : first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Glow halo + avatar
            Container(
              width: avatarSize + 8,
              height: avatarSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color1.withValues(alpha: onTap != null ? 0.20 : 0.12),
              ),
              child: Center(
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_color1, _color2],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _color1.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _icon,
                    size: avatarSize * 0.45,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Palette.darkSurfaceContainerColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _color1.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _shortName,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _color1,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashed line painter  (patient node → caregiver node)
// ─────────────────────────────────────────────────────────────────────────────

class _CaregiverLinesPainter extends CustomPainter {
  final List<({Offset from, Offset to})> segments;

  const _CaregiverLinesPainter({required this.segments});

  static const _careColor = Color(0xFF0EA5E9);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _careColor.withValues(alpha: 0.50)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final seg in segments) {
      _drawDashed(canvas, paint, seg.from, seg.to);
    }
  }

  static void _drawDashed(Canvas canvas, Paint paint, Offset from, Offset to) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    const dashLen = 20.0;
    const gapLen = 6.0;
    double traveled = 0.0;
    while (traveled < dist) {
      final t0 = traveled / dist;
      final t1 = math.min((traveled + dashLen) / dist, 1.0);
      canvas.drawLine(
        Offset(from.dx + dx * t0, from.dy + dy * t0),
        Offset(from.dx + dx * t1, from.dy + dy * t1),
        paint,
      );
      traveled += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_CaregiverLinesPainter old) =>
      old.segments.length != segments.length;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashed line painter  (doctor node → secretary node, violet)
// ─────────────────────────────────────────────────────────────────────────────

class _SecretaryLinesPainter extends CustomPainter {
  final List<({Offset from, Offset to})> segments;

  const _SecretaryLinesPainter({required this.segments});

  static const _secColor = Color(0xFF7C3AED);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _secColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final seg in segments) {
      _drawDashed(canvas, paint, seg.from, seg.to);
    }
  }

  static void _drawDashed(Canvas canvas, Paint paint, Offset from, Offset to) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    const dashLen = 14.0;
    const gapLen = 5.0;
    double traveled = 0.0;
    while (traveled < dist) {
      final t0 = traveled / dist;
      final t1 = math.min((traveled + dashLen) / dist, 1.0);
      canvas.drawLine(
        Offset(from.dx + dx * t0, from.dy + dy * t0),
        Offset(from.dx + dx * t1, from.dy + dy * t1),
        paint,
      );
      traveled += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_SecretaryLinesPainter old) =>
      old.segments.length != segments.length;
}
