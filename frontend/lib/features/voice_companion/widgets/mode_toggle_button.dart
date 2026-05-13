import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/palette.dart';
import '../controllers/companion_controller.dart';

/// "Talk in Chat" button — shown at the bottom of voice mode.
class TalkInChatButton extends ConsumerWidget {
  const TalkInChatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: ElevatedButton.icon(
        onPressed: () =>
            ref.read(companionControllerProvider.notifier).toggleMode(),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text(
          'Talk in Chat',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.greenColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

/// "← Back to Voice" — used as leading widget in chat mode AppBar.
class BackToVoiceButton extends ConsumerWidget {
  const BackToVoiceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () =>
          ref.read(companionControllerProvider.notifier).toggleMode(),
      icon: const Icon(Icons.graphic_eq_rounded, size: 18),
      label: const Text('Voice', style: TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(foregroundColor: Palette.greenColor),
    );
  }
}
