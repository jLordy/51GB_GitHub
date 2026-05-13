import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:frontend/features/call/presentation/screens/call_screen.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/connections/model/patient_profile_model.dart';
import 'package:frontend/features/journal/presentation/screens/patient_journal_screen.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Patient Connection Card
//  Shown at the bottom of the care-provider view when a patient node is tapped.
// ─────────────────────────────────────────────────────────────────────────────

class PatientConnectionCard extends ConsumerWidget {
  final UserModel patient;
  final PatientProfileModel? profile;
  final String? connectionId;
  final VoidCallback? onRemove;

  const PatientConnectionCard({
    super.key,
    required this.patient,
    this.profile,
    this.connectionId,
    this.onRemove,
  });

  static const _green1 = Color(0xFF43A97A);
  static const _accent = Palette.greenColor;

  String get _displayName => patient.displayName ?? patient.email ?? 'Patient';

  static String _roleLabel(String role) {
    if (role.isEmpty) return 'User';
    return role[0].toUpperCase() + role.substring(1);
  }

  void _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createOrFetchConversation(patient.uid);
      if (!context.mounted) return;
      context.push('/chat/${conv.conversationId}', extra: conv);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open conversation')),
      );
    }
  }

  void _startCall(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    final callState = ref.read(callControllerProvider);
    if (callState.hasActiveCall) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already in a call')));
      return;
    }
    await ref
        .read(callControllerProvider.notifier)
        .startCall(
          calleeUid: patient.uid,
          callerUid: currentUser.uid,
          callerName: currentUser.displayName ?? currentUser.email ?? 'Me',
          calleeName: _displayName,
          callerPhotoUrl: currentUser.photoUrl,
          calleePhotoUrl: patient.photoUrl,
        );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          otherName: _displayName,
          otherPhotoUrl: patient.photoUrl,
        ),
      ),
    );
  }

  void _openRecords(BuildContext context) {
    final encodedName = Uri.encodeComponent(_displayName);
    context.push(
      '/documents?patientUid=${patient.uid}&patientName=$encodedName',
    );
  }

  void _showConnectionOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.only(bottom: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 14, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Palette.darkOutlineColor
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onRemove?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFEF2F2),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Icon(
                        Icons.link_off_rounded,
                        size: 22,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remove Connection',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        Text(
                          'This action cannot be undone',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? Palette.darkOnSurfaceVariantColor
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Age + diagnosis chip builder ──────────────────────────────────────────
  static List<Widget> _buildPatientChips(
    PatientProfileModel profile,
    bool isDark,
  ) {
    final (diagLabel, diagIcon, diagColor) = switch (profile.illnessType) {
      'diabetes' => (
        'Diabetes',
        Icons.bloodtype_outlined,
        const Color(0xFFF59E0B),
      ),
      'oncology' => (
        'Cancer',
        Icons.monitor_heart_outlined,
        const Color(0xFF8B5CF6),
      ),
      _ => (
        // 'ckd' and any future values
        'CKD',
        Icons.water_drop_outlined,
        const Color(0xFF3B82F6),
      ),
    };

    Widget chip({
      required IconData icon,
      required String label,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return [
      const SizedBox(height: 7),
      Wrap(
        spacing: 6,
        children: [
          chip(
            icon: Icons.cake_outlined,
            label: '${profile.age} yrs',
            color: Palette.greenColor,
          ),
          chip(icon: diagIcon, label: diagLabel, color: diagColor),
        ],
      ),
    ];
  }

  // ── Caregiver chip builder ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewerRole = ref.watch(currentUserProvider)?.role == 'doctor'
        ? PatientJournalViewerRole.doctor
        : ref.watch(currentUserProvider)?.role == 'secretary'
        ? PatientJournalViewerRole.secretary
        : PatientJournalViewerRole.caregiver;
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _accent.withValues(alpha: 0.10),
                  _accent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_green1, _accent],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                // Name and role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: _accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _roleLabel(patient.role),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                          ),
                        ],
                      ),
                      // ── Age + diagnosis chips ────────────────────
                      if (profile != null)
                        ..._buildPatientChips(profile!, isDark),
                    ],
                  ),
                ),
                // Options button
                GestureDetector(
                  onTap: () => _showConnectionOptions(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Palette.darkSurfaceContainerColor.withValues(
                              alpha: 0.6,
                            )
                          : Colors.white.withValues(alpha: 0.70),
                      border: Border.all(
                        color: isDark
                            ? Palette.darkOutlineColor
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  color: _accent,
                  isDark: isDark,
                  onTap: () => _openChat(context, ref),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  color: _accent,
                  isDark: isDark,
                  onTap: () => _startCall(context, ref),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.medical_information_outlined,
                  label: 'Records',
                  color: _accent,
                  isDark: isDark,
                  onTap: () => _openRecords(context),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.menu_book_outlined,
                  label: 'Journal',
                  color: _accent,
                  isDark: isDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PatientJournalScreen(
                        patientUid: patient.uid,
                        patientName: _displayName,
                        viewerRole: viewerRole,
                      ),
                    ),
                  ),
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
//  Reusable action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
