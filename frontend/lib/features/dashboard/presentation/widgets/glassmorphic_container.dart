import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable frosted-glass container used by every dashboard card.
///
/// The [BackdropFilter] blurs whatever is rendered behind this widget
/// (decorative orbs, gradient bg), giving the glassmorphism effect that
/// matches the existing BottomNavbar style in bottom_navbar.dart.
class GlassmorphicContainer extends StatelessWidget {
  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16),
    this.blurSigma = 14.0,
    this.margin,
    this.width,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final EdgeInsetsGeometry? margin;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // Two-stop gradient: brighter top-left fades to near-transparent
              // bottom-right, simulating reflected light on frosted glass.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: isDark ? 0.10 : 0.65),
                  Colors.white.withValues(alpha: isDark ? 0.04 : 0.30),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.45),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
