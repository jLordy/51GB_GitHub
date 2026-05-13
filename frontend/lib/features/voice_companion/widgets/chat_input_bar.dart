import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/palette.dart';
import '../controllers/companion_controller.dart';

class CompanionChatInputBar extends ConsumerStatefulWidget {
  const CompanionChatInputBar({super.key});

  @override
  ConsumerState<CompanionChatInputBar> createState() =>
      _CompanionChatInputBarState();
}

class _CompanionChatInputBarState
    extends ConsumerState<CompanionChatInputBar> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      final has = _textCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() => _hasText = false);
    ref.read(companionControllerProvider.notifier).sendChatMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ttsEnabled =
        ref.watch(companionControllerProvider).ttsEnabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? Palette.darkSurfaceColor : Palette.lightSurfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Palette.darkOutlineColor : const Color(0xFFE0E8E4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // TTS mute toggle
            IconButton(
              onPressed: () =>
                  ref.read(companionControllerProvider.notifier).toggleTts(),
              icon: Icon(
                ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: ttsEnabled ? Palette.greenColor : Colors.grey,
              ),
              tooltip: ttsEnabled ? 'Mute voice' : 'Unmute voice',
            ),
            const SizedBox(width: 4),
            // Text field
            Expanded(
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                maxLines: 4,
                minLines: 1,
                style: TextStyle(
                  color: isDark
                      ? Palette.darkOnSurfaceColor
                      : Palette.lightOnSurfaceColor,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'I-type ang mensahe mo...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? Palette.darkOnSurfaceVariantColor
                        : Palette.lightOnSurfaceVariantColor,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Palette.darkInputSurfaceColor
                      : Palette.lightSurfaceContainerColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Palette.greenColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button — same green when disabled, lower opacity (not grey)
            Material(
              color: _hasText
                  ? Palette.greenColor
                  : Palette.greenColor.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _hasText ? _send : null,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
