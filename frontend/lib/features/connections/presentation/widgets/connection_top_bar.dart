import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ConnectionTopBar extends StatelessWidget {
  const ConnectionTopBar({
    super.key,
    required this.onAdd,
    this.title = 'My Health Circle',
  });

  final VoidCallback onAdd;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          _NavButton(onTap: () => context.go('/home')),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Palette.darkOnSurfaceColor
                      : const Color(0xFF1A1A2E),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Palette.greenColor, Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const Spacer(),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 17,
          color: isDark ? Palette.darkOnSurfaceColor : const Color(0xFF374151),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF43A97A), Palette.greenColor],
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.greenColor.withValues(alpha: 0.40),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
      ),
    );
  }
}

// Kept for backward compatibility
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const RoundIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Palette.darkSurfaceContainerColor : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: isDark ? Palette.darkOnSurfaceColor : const Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}
