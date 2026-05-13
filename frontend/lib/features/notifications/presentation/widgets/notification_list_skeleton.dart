import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shimmer-animated placeholder list that mirrors the shape of [NotificationTile].
class NotificationListSkeleton extends ConsumerStatefulWidget {
  const NotificationListSkeleton({super.key, this.tileCount = 8});

  final int tileCount;

  @override
  ConsumerState<NotificationListSkeleton> createState() =>
      _NotificationListSkeletonState();
}

class _NotificationListSkeletonState
    extends ConsumerState<NotificationListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        ref.watch(themeNotifierProvider).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => _NotifSkeletonBody(
        isDark: isDark,
        shimmerValue: _anim.value,
        tileCount: widget.tileCount,
      ),
    );
  }
}

class _NotifSkeletonBody extends StatelessWidget {
  const _NotifSkeletonBody({
    required this.isDark,
    required this.shimmerValue,
    required this.tileCount,
  });

  final bool isDark;
  final double shimmerValue;
  final int tileCount;

  Color get _base => isDark ? const Color(0xFF2C333A) : const Color(0xFFE8E8E8);
  Color get _highlight =>
      isDark ? const Color(0xFF3D4552) : const Color(0xFFF4F4F4);
  Color get _shimmerColor => Color.lerp(_base, _highlight, shimmerValue)!;

  Widget _box({double? width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _shimmerColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _shimmerColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tileCount,
      itemBuilder: (_, int i) => _NotifTileSkeleton(
        box: _box,
        circle: _circle,
        // Vary the main text line width so tiles look distinct.
        textWidth: i % 3 == 0 ? 200.0 : (i % 3 == 1 ? 160.0 : 180.0),
      ),
    );
  }
}

class _NotifTileSkeleton extends StatelessWidget {
  const _NotifTileSkeleton({
    required this.box,
    required this.circle,
    required this.textWidth,
  });

  final Widget Function({double? width, required double height, double radius})
  box;
  final Widget Function(double size) circle;
  final double textWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // ── Avatar circle (radius 28 → diameter 56) ───────────────────
          circle(56),
          const SizedBox(width: 12),

          // ── Text column ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // First line: actor name (bold, shorter) + action text
                Row(
                  children: <Widget>[
                    box(width: 90, height: 13),
                    const SizedBox(width: 6),
                    box(width: textWidth - 96, height: 13),
                  ],
                ),
                const SizedBox(height: 5),
                // Second line: rest of the message
                box(width: textWidth, height: 13),
                const SizedBox(height: 6),
                // Timestamp
                box(width: 68, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Three-dot icon placeholder ─────────────────────────────────
          box(width: 22, height: 8, radius: 4),
        ],
      ),
    );
  }
}
