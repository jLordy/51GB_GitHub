import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Determines which care-team member's info is displayed in the details card.
enum ConnectionType { doctor, caregiver, patient }

class ConnectionDetailsCard extends StatelessWidget {
  final ConnectionType connectionType;
  final String displayName;
  final String roleLabel;
  final String? connectionId;
  final VoidCallback onMessageTap;
  final VoidCallback onCallTap;
  final VoidCallback onThirdButtonTap;
  final VoidCallback? onRemove;
  final IconData? thirdButtonIcon;
  final String? thirdButtonLabel;

  const ConnectionDetailsCard({
    super.key,
    required this.connectionType,
    required this.displayName,
    required this.roleLabel,
    required this.onMessageTap,
    required this.onCallTap,
    required this.onThirdButtonTap,
    this.connectionId,
    this.onRemove,
    this.thirdButtonIcon,
    this.thirdButtonLabel,
  });

  Color get _accentColor => switch (connectionType) {
    ConnectionType.doctor  => const Color(0xFF3B82F6),
    ConnectionType.patient => const Color(0xFF0D9488),
    _                      => const Color(0xFF7C3AED),
  };

  List<Color> get _gradientColors => switch (connectionType) {
    ConnectionType.doctor  => [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
    ConnectionType.patient => [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
    _                      => [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
  };

  IconData get _roleIcon => switch (connectionType) {
    ConnectionType.doctor  => Icons.medical_services_rounded,
    ConnectionType.patient => Icons.people_rounded,
    _                      => Icons.favorite_rounded,
  };

  String get _roleShortLabel => switch (connectionType) {
    ConnectionType.doctor  => 'Primary Physician',
    ConnectionType.patient => 'Peer Patient',
    _                      => 'Family Caregiver',
  };

  void _showFullBio(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textDark = isDark
        ? Palette.darkOnSurfaceColor
        : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 14, bottom: 24),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Palette.darkOutlineColor
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              displayName,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(_roleIcon, size: 14, color: _accentColor),
                const SizedBox(width: 5),
                Text(
                  _roleShortLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              switch (connectionType) {
                ConnectionType.doctor  => 'A dedicated physician committed to your care and well-being. Always available to support your health journey and ensure the best outcomes.',
                ConnectionType.patient => 'A fellow patient in your health circle. Share experiences, offer support, and stay connected on your journey to wellness.',
                _                      => 'Your family caregiver who supports your daily health needs and ensures your well-being at all times.',
              },
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textMid,
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);
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
                            color: textMid,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: _accentColor.withValues(alpha: 0.12),
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
          // â”€â”€ Gradient header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _accentColor.withValues(alpha: 0.10),
                  _accentColor.withValues(alpha: 0.03),
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _gradientColors,
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 27,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                // Name + role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(_roleIcon, size: 12, color: _accentColor),
                          const SizedBox(width: 4),
                          Text(
                            _roleShortLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showConnectionOptions(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: textMid,
                  height: 1.55,
                ),
                children: [
                  TextSpan(
                    text: switch (connectionType) {
                      ConnectionType.doctor  => 'A dedicated physician committed to your care and well-being...',
                      ConnectionType.patient => 'A fellow patient in your health circle. Share experiences and support...',
                      _                      => 'Your family caregiver who supports your daily health needs...',
                    },
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => _showFullBio(context),
                      child: Text(
                        ' More',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Row(
              children: [
                _CardAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  bg: Palette.greenColor,
                  fg: Colors.white,
                  flex: 3,
                  onTap: onMessageTap,
                ),
                const SizedBox(width: 8),
                _CardAction(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  bg: _accentColor,
                  fg: Colors.white,
                  flex: 2,
                  onTap: onCallTap,
                ),
                const SizedBox(width: 8),
                _CardAction(
                  icon: thirdButtonIcon ?? switch (connectionType) {
                    ConnectionType.doctor  => Icons.calendar_month_rounded,
                    ConnectionType.patient => Icons.chat_bubble_outline_rounded,
                    _                      => Icons.checklist_rounded,
                  },
                  label: thirdButtonLabel ?? switch (connectionType) {
                    ConnectionType.doctor  => 'Schedule',
                    ConnectionType.patient => 'Connect',
                    _                      => 'Tasks',
                  },
                  bg: isDark
                      ? Palette.darkInputSurfaceColor
                      : const Color(0xFFF3F4F6),
                  fg: isDark
                      ? Palette.darkOnSurfaceColor
                      : const Color(0xFF374151),
                  flex: 3,
                  onTap: onThirdButtonTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//  Card Action Button

// Keep public alias for any external usage
typedef CardActionButton = _CardAction;

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final int flex;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.flex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: fg, size: 21),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
