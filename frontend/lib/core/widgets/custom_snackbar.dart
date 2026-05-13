import 'dart:async';

import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';

enum SnackBarType { info, success, error }

/// Utility class for showing consistently styled snackbars across the app.
///
/// Usage:
/// ```dart
/// AppSnackBar.show(context, 'Post published.', type: SnackBarType.success);
/// ```
class AppSnackBar {
  AppSnackBar._();

  static OverlayEntry? _activeEntry;

  /// Immediately removes the currently visible custom snackbar, if any.
  static void dismiss() {
    if (_activeEntry?.mounted == true) _activeEntry!.remove();
    _activeEntry = null;
  }

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    double bottomOffset = 0.0,
  }) {
    // Remove any existing snackbar immediately.
    if (_activeEntry?.mounted == true) _activeEntry!.remove();
    _activeEntry = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SnackBarOverlay(
        message: message,
        type: type,
        bottomOffset: bottomOffset,
        onDismiss: () {
          if (entry.mounted) entry.remove();
          if (identical(_activeEntry, entry)) _activeEntry = null;
        },
      ),
    );

    _activeEntry = entry;
    Overlay.of(context).insert(entry);
  }
}

class _SnackBarOverlay extends StatefulWidget {
  const _SnackBarOverlay({
    required this.message,
    required this.type,
    required this.bottomOffset,
    required this.onDismiss,
  });

  final String message;
  final SnackBarType type;
  final double bottomOffset;
  final VoidCallback onDismiss;

  @override
  State<_SnackBarOverlay> createState() => _SnackBarOverlayState();
}

class _SnackBarOverlayState extends State<_SnackBarOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _displayDuration = Duration(milliseconds: 3800);
  static const Duration _fadeInDuration = Duration(milliseconds: 280);
  static const Duration _fadeOutDuration = Duration(milliseconds: 380);

  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  Timer? _fadeOutTimer;
  bool _dismissed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _fadeInDuration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _fadeOutTimer = Timer(_displayDuration, _startFadeOut);
  }

  void _startFadeOut() {
    if (_dismissed || _disposed) return;
    _dismissed = true;
    _fadeOutTimer?.cancel();
    _ctrl.reverseDuration = _fadeOutDuration;
    _ctrl.reverse().then((_) {
      if (!_disposed) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _fadeOutTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color _accentColor() => switch (widget.type) {
    SnackBarType.info => const Color(0xFF4A90D9),
    SnackBarType.success => Palette.greenColor,
    SnackBarType.error => const Color(0xFFE05252),
  };

  IconData _icon() => switch (widget.type) {
    SnackBarType.info => Icons.info_outline_rounded,
    SnackBarType.success => Icons.check_circle_outline_rounded,
    SnackBarType.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = _accentColor();
    final Color bg = isDark ? const Color(0xFF1E252C) : const Color(0xFFF8F9FB);
    final Color textColor = isDark
        ? const Color(0xFFF0F0F0)
        : const Color(0xFF1A1A2E);
    final double sysPad = MediaQuery.of(context).padding.bottom;
    final double bottomPadding = sysPad + 16.0 + widget.bottomOffset;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: FadeTransition(
            opacity: _opacity,
            child: GestureDetector(
              onTap: _startFadeOut,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.08,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                        ),
                        child: Icon(_icon(), color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Utility class for showing consistently styled snackbars across the app.
///
/// Usage:
/// ```dart
/// AppSnackBar.show(context, 'Post published.', type: SnackBarType.success);
/// ```

class _SnackBarContent extends StatefulWidget {
  const _SnackBarContent({
    required this.message,
    required this.type,
    required this.displayDuration,
    required this.fadeInDuration,
    required this.fadeOutDuration,
  });

  final String message;
  final SnackBarType type;
  final Duration displayDuration;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  @override
  State<_SnackBarContent> createState() => _SnackBarContentState();
}

class _SnackBarContentState extends State<_SnackBarContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  Timer? _fadeOutTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.fadeInDuration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // Fade in immediately.
    _ctrl.forward();

    // Start fade-out just before the snackbar auto-dismisses.
    _fadeOutTimer = Timer(widget.displayDuration, _startFadeOut);
  }

  void _startFadeOut() {
    if (!mounted) return;
    _ctrl.reverseDuration = widget.fadeOutDuration;
    _ctrl.reverse().then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _fadeOutTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color _accentColor() => switch (widget.type) {
    SnackBarType.info => const Color(0xFF4A90D9),
    SnackBarType.success => Palette.greenColor,
    SnackBarType.error => const Color(0xFFE05252),
  };

  IconData _icon() => switch (widget.type) {
    SnackBarType.info => Icons.info_outline_rounded,
    SnackBarType.success => Icons.check_circle_outline_rounded,
    SnackBarType.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = _accentColor();
    final Color bg = isDark ? const Color(0xFF1E252C) : const Color(0xFFF8F9FB);
    final Color textColor = isDark
        ? const Color(0xFFF0F0F0)
        : const Color(0xFF1A1A2E);

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(_icon(), color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}