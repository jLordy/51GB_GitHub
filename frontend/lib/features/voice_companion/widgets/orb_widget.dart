import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/palette.dart';
import '../models/companion_state.dart';
import 'ripple_painter.dart';

class OrbWidget extends StatefulWidget {
  final CompanionState state;
  final VoidCallback onTap;

  const OrbWidget({super.key, required this.state, required this.onTap});

  @override
  State<OrbWidget> createState() => _OrbWidgetState();
}

class _OrbWidgetState extends State<OrbWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  static const _orbSize = 120.0;
  static const _canvasSize = 240.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _durationFor(widget.state));
    _scaleAnim = _buildScaleAnim();
    _opacityAnim = _buildOpacityAnim();
    _startAnimation(widget.state);
  }

  @override
  void didUpdateWidget(OrbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.stop();
      _controller.duration = _durationFor(widget.state);
      _scaleAnim = _buildScaleAnim();
      _opacityAnim = _buildOpacityAnim();
      _controller.reset();
      _startAnimation(widget.state);
    }
  }

  Duration _durationFor(CompanionState s) {
    switch (s) {
      case CompanionState.idle:
        return const Duration(milliseconds: 2400);
      case CompanionState.listening:
        return const Duration(milliseconds: 900);
      case CompanionState.processing:
        return const Duration(milliseconds: 1800);
      case CompanionState.speaking:
        return const Duration(milliseconds: 1200);
    }
  }

  Animation<double> _buildScaleAnim() {
    final end = widget.state == CompanionState.listening ? 1.15 : 1.08;
    return Tween<double>(begin: 1.0, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Animation<double> _buildOpacityAnim() {
    final endOpacity = widget.state == CompanionState.idle ? 0.25 : 0.55;
    return Tween<double>(begin: 0.1, end: endOpacity).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _startAnimation(CompanionState s) {
    switch (s) {
      case CompanionState.idle:
      case CompanionState.listening:
        _controller.repeat(reverse: true);
        break;
      case CompanionState.processing:
      case CompanionState.speaking:
        _controller.repeat();
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: _canvasSize,
        height: _canvasSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ripple rings (listening + speaking)
                if (widget.state == CompanionState.listening ||
                    widget.state == CompanionState.speaking)
                  CustomPaint(
                    size: const Size(_canvasSize, _canvasSize),
                    painter: RipplePainter(
                      animValue: _controller.value,
                      color: Palette.greenColor,
                      ringCount:
                          widget.state == CompanionState.speaking ? 4 : 3,
                      mode: widget.state == CompanionState.speaking
                          ? RippleMode.pulse
                          : RippleMode.outward,
                      centerRadius: _orbSize / 2,
                      maxRadius: _canvasSize / 2 - 4,
                    ),
                  ),

                // Glow halo
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _orbSize + 30,
                  height: _orbSize + 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.greenColor.withValues(
                      alpha: _opacityAnim.value,
                    ),
                  ),
                ),

                // Processing shimmer arc
                if (widget.state == CompanionState.processing)
                  Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(_orbSize + 20, _orbSize + 20),
                      painter: _ShimmerArcPainter(
                        color: Palette.primaryContainerColor,
                      ),
                    ),
                  ),

                // Core orb
                Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: _orbSize,
                    height: _orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _centerColorFor(widget.state),
                          Palette.secondaryColor,
                        ],
                        stops: const [0.45, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.greenColor.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(child: _iconFor(widget.state)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _centerColorFor(CompanionState s) {
    switch (s) {
      case CompanionState.idle:
        return Palette.greenColor;
      case CompanionState.listening:
        return const Color(0xFF47C47E);
      case CompanionState.processing:
        return const Color(0xFF2A7A50);
      case CompanionState.speaking:
        return const Color(0xFF56D68A);
    }
  }

  Widget _iconFor(CompanionState s) {
    switch (s) {
      case CompanionState.idle:
        return const Icon(Icons.spa_outlined, color: Colors.white, size: 32);
      case CompanionState.listening:
        return const Icon(Icons.mic, color: Colors.white, size: 34);
      case CompanionState.processing:
        return const Icon(Icons.autorenew, color: Colors.white, size: 30);
      case CompanionState.speaking:
        return const Icon(Icons.volume_up_rounded, color: Colors.white, size: 32);
    }
  }
}

// ── Shimmer arc for processing state ─────────────────────────────────────────

class _ShimmerArcPainter extends CustomPainter {
  final Color color;
  const _ShimmerArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, math.pi * 1.1, false, paint);
  }

  @override
  bool shouldRepaint(_ShimmerArcPainter old) => old.color != color;
}
