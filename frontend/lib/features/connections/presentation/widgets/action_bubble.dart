import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';

class ActionBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const ActionBubble({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // HitTestBehavior.opaque ensures the full 28×28 bounding box responds to
    // taps, not just the visible painted circle pixels.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.greenColor.withValues(alpha: 0.13),
          border: Border.all(
            color: Palette.greenColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.greenColor.withValues(alpha: 0.22),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, size: 13, color: Palette.greenColor),
      ),
    );
  }
}
