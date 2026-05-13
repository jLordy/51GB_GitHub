import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/companion_controller.dart';
import '../models/companion_state.dart';
import '../widgets/mode_toggle_button.dart';
import '../widgets/orb_widget.dart';

class VoiceScreen extends ConsumerWidget {
  final VoidCallback onClose;
  const VoiceScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(companionControllerProvider);
    final orbState = state.orbState;
    final transcript = state.liveTranscript;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main content — no backdrop, floats over the underlying screen
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'AI Companion',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // State label
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _labelFor(orbState),
                    key: ValueKey(orbState),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Orb
                OrbWidget(
                  state: orbState,
                  onTap: () =>
                      ref.read(companionControllerProvider.notifier).orbTapped(),
                ),

                const SizedBox(height: 28),

                _SpotifyTranscript(text: transcript),

                const Spacer(flex: 3),

                // Hint text
                if (orbState == CompanionState.listening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tap the orb when done speaking',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Talk in Chat button
                const TalkInChatButton(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(CompanionState s) {
    switch (s) {
      case CompanionState.idle:
        return 'READY';
      case CompanionState.listening:
        return 'LISTENING...';
      case CompanionState.processing:
        return 'THINKING...';
      case CompanionState.speaking:
        return 'SPEAKING';
    }
  }
}

/// Last few words with a left-edge fade and cross-fade updates (lyrics-style).
class _SpotifyTranscript extends StatelessWidget {
  final String text;

  const _SpotifyTranscript({required this.text});

  String get _truncated {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length <= 7) {
      return words.join(' ');
    }
    return words.sublist(words.length - 7).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox(height: 56);
    }
    final show = _truncated;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (Widget child, Animation<double> anim) {
        return FadeTransition(opacity: anim, child: child);
      },
      child: ShaderMask(
        key: ValueKey(show),
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [Color(0x00000000), Color(0xFFFFFFFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.0, 0.28],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            show,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 1.3,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
