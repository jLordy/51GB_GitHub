import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/palette.dart';
import '../controllers/companion_controller.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/mode_toggle_button.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const ChatScreen({super.key, required this.onClose});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companionControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-scroll when messages or typing state changes
    ref.listen<CompanionControllerState>(companionControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.isTyping != next.isTyping) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? Palette.darkSurfaceColor : Palette.lightSurfaceColor,
      appBar: AppBar(
        backgroundColor:
            isDark ? Palette.darkSurfaceColor : Palette.lightSurfaceColor,
        elevation: 0,
        leading: const BackToVoiceButton(),
        leadingWidth: 100,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFF47C47E), Palette.secondaryColor],
                ),
              ),
              child: const Icon(Icons.spa_outlined, color: Colors.white, size: 13),
            ),
            const SizedBox(width: 8),
            Text(
              'AI Companion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Palette.darkOnSurfaceColor
                    : Palette.lightOnSurfaceColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? Palette.darkOutlineColor : const Color(0xFFE0E8E4),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty && !state.isTyping
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    itemCount:
                        state.messages.length + (state.isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.isTyping && index == state.messages.length) {
                        return const CompanionTypingIndicator();
                      }
                      return CompanionChatBubble(
                        message: state.messages[index],
                      );
                    },
                  ),
          ),
          const CompanionChatInputBar(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.greenColor.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Palette.greenColor,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start the conversation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Palette.greenColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'I-type ang gusto mong sabihin.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
