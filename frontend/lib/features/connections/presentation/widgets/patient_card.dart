import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:frontend/features/call/presentation/screens/call_screen.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/connections/controller/connection_controller.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientCard extends ConsumerWidget {
  const PatientCard({
    super.key,
    required this.patient,
    required this.connectionId,
  });

  final UserModel patient;
  final String connectionId;

  static const _green1 = Color(0xFF43A97A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = patient.displayName ?? patient.email ?? 'Patient';
    final initial = name.substring(0, 1).toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left accent bar ───────────────────────────────────────────
            Container(
              width: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_green1, Palette.greenColor],
                ),
              ),
            ),
            // ── Card body ─────────────────────────────────────────────────
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Palette.darkSurfaceContainerColor
                      : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: avatar + name/badge + more ──────────────
                    Row(
                      children: [
                        // ── Avatar ────────────────────────────────────────
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _green1.withValues(alpha: 0.85),
                                Palette.greenColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Palette.greenColor.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: patient.photoUrl != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: patient.photoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        // ── Name + badges ──────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Palette.darkOnSurfaceColor
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.greenColor.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Palette.greenColor.withValues(
                                          alpha: 0.28,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Patient',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Palette.greenColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Palette.greenColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Palette.greenColor.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Connected',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
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
                        // ── More options ───────────────────────────────────
                        GestureDetector(
                          onTap: () => _showOptions(context, ref),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: isDark
                                  ? Palette.darkOnSurfaceVariantColor
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // ── Action buttons ────────────────────────────────────
                    Row(
                      children: [
                        _ActionButton(
                          icon: Icons.message_rounded,
                          label: 'Message',
                          isDark: isDark,
                          onTap: () => _openChat(context, ref),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.call_rounded,
                          label: 'Call',
                          isDark: isDark,
                          onTap: () => _startCall(context, ref),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.folder_rounded,
                          label: 'Records',
                          isDark: isDark,
                          onTap: () => _openRecords(context),
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          icon: Icons.menu_book_rounded,
                          label: 'Journal',
                          isDark: isDark,
                          onTap: () => _openJournal(context, ref),
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
          calleeName: patient.displayName ?? patient.email ?? 'Patient',
          callerPhotoUrl: currentUser.photoUrl,
          calleePhotoUrl: patient.photoUrl,
        );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          otherName: patient.displayName ?? patient.email ?? 'Patient',
          otherPhotoUrl: patient.photoUrl,
        ),
      ),
    );
  }

  void _openRecords(BuildContext context) {
    context.push('/documents?patientUid=${patient.uid}');
  }

  void _openJournal(BuildContext context, WidgetRef ref) {
    final name = patient.displayName ?? patient.email ?? 'Patient';
    context.push(
      '/patients/${patient.uid}/journal',
      extra: {'patientName': name, 'viewerRole': 'doctor'},
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.only(bottom: 32),
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
                ref
                    .read(acceptedConnectionsProvider.notifier)
                    .remove(connectionId);
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Action button (Message / Call / Records / Journal)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Palette.darkSurfaceContainerColor.withValues(alpha: 0.6)
                : const Color(0xFFF3FAF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Palette.greenColor.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Palette.greenColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Palette.darkOnSurfaceVariantColor
                      : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
