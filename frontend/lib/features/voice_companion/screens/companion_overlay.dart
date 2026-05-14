import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/companion_controller.dart';
import 'chat_screen.dart';
import 'voice_screen.dart';

/// Entry point — the ONLY symbol imported by bottom_navbar.dart.
void showCompanionOverlay(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim, secAnim) => const _CompanionOverlayRoot(),
      transitionsBuilder: (ctx, animation, secAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    ),
  );
}

// ── Root widget ───────────────────────────────────────────────────────────────

class _CompanionOverlayRoot extends StatelessWidget {
  const _CompanionOverlayRoot();

  @override
  Widget build(BuildContext context) {
    // Fresh ProviderScope override so state is scoped to overlay lifetime
    return ProviderScope(
      overrides: [
        companionControllerProvider.overrideWith(
          (ref) => CompanionController(),
        ),
      ],
      child: const _CompanionOverlayShell(),
    );
  }
}

class _CompanionOverlayShell extends ConsumerStatefulWidget {
  const _CompanionOverlayShell();

  @override
  ConsumerState<_CompanionOverlayShell> createState() =>
      _CompanionOverlayShellState();
}

class _CompanionOverlayShellState
    extends ConsumerState<_CompanionOverlayShell> {
  @override
  void initState() {
    super.initState();
    // Kick off the greeting as soon as the overlay appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(companionControllerProvider.notifier).initialize();
      }
    });
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isChatMode = ref.watch(
      companionControllerProvider.select((s) => s.isChatMode),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final isChat = child.key == const ValueKey('chat');
        final slideOffset = isChat
            ? const Offset(1.0, 0.0)
            : const Offset(-1.0, 0.0);
        return SlideTransition(
          position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
              .animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: isChatMode
          ? ChatScreen(key: const ValueKey('chat'), onClose: _close)
          : VoiceScreen(key: const ValueKey('voice'), onClose: _close),
    );
  }
}
