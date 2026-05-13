import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Custom controller that renders markdown links inline:
/// - `[label](url)` → shows *label* in blue + underline; collapses `[`, `](url)`
/// - bare `https://…` URLs → shows in blue + underline
class _LinkAwareController extends TextEditingController {
  static final _pattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)|(https?://\S+)');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final matches = _pattern.allMatches(text);

    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final linkStyle = (style ?? const TextStyle()).copyWith(
      color: Colors.blue,
      decoration: TextDecoration.underline,
      decorationColor: Colors.blue,
    );
    // Near-zero size so syntax chars occupy essentially no space.
    final hiddenStyle = (style ?? const TextStyle()).copyWith(
      fontSize: 0.01,
      letterSpacing: 0,
      color: Colors.transparent,
    );

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final m in matches) {
      if (m.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, m.start), style: style),
        );
      }

      if (m.group(1) != null) {
        // Markdown link: [label](url)
        final label = m.group(1)!;
        final url = m.group(2)!;
        spans.add(TextSpan(text: '[', style: hiddenStyle));
        spans.add(TextSpan(text: label, style: linkStyle));
        spans.add(TextSpan(text: ']($url)', style: hiddenStyle));
      } else {
        // Bare URL
        spans.add(TextSpan(text: m.group(3)!, style: linkStyle));
      }

      lastEnd = m.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return TextSpan(style: style, children: spans);
  }
}

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onLike,
    this.onAttachLink,
    this.onAttachImage,
    this.onAttachVideo,
    this.isLoading = false,
  });

  final void Function(String text) onSend;
  final VoidCallback? onLike;
  final VoidCallback? onAttachLink;
  final Future<void> Function(XFile image)? onAttachImage;
  final Future<void> Function(XFile video)? onAttachVideo;
  final bool isLoading;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = _LinkAwareController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _hideAttachmentMenu();
    _controller.dispose();
    super.dispose();
  }

  void _showAttachmentMenu() {
    _hideAttachmentMenu();
    final scheme = Theme.of(context).colorScheme;
    _overlayEntry = OverlayEntry(
      builder: (_) => _AttachMenu(
        layerLink: _layerLink,
        scheme: scheme,
        onDismiss: _hideAttachmentMenu,
        onLink: () {
          _hideAttachmentMenu();
          _handleLinkTap();
        },
        onPhoto: () {
          _hideAttachmentMenu();
          _handleImageTap();
        },
        onVideo: () {
          _hideAttachmentMenu();
          _handleVideoTap();
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideAttachmentMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    _controller.clear();
    widget.onSend(text);
  }

  static const int _maxImageBytes = 25 * 1024 * 1024; // 25 MB

  Future<void> _handleImageTap() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image exceeds the 25 MB limit.')),
      );
      return;
    }
    if (!mounted) return;

    // Show preview sheet — user confirms before uploading.
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Send photo?',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: 280,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(true),
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && widget.onAttachImage != null) {
      await widget.onAttachImage!(picked);
    }
  }

  Future<void> _handleVideoTap() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final size = await picked.length();
    if (size > _maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video exceeds the 25 MB limit.')),
      );
      return;
    }
    if (!mounted) return;

    // Show confirmation sheet before uploading.
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetCtx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Send video?',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      size: 36,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      picked.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(true),
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && widget.onAttachVideo != null) {
      await widget.onAttachVideo!(picked);
    }
  }

  Future<void> _handleLinkTap() async {
    final urlController = TextEditingController();
    final labelController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Embed a link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Display text (optional)',
                  hintText: 'Click here',
                  prefixIcon: Icon(Icons.text_fields_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );

    final rawUrl = urlController.text.trim();
    final label = labelController.text.trim();

    if (!mounted) return;
    if (confirmed != true || rawUrl.isEmpty) return;

    // Auto-prepend https:// when the user omits the scheme.
    final url = rawUrl.startsWith(RegExp(r'https?://'))
        ? rawUrl
        : 'https://$rawUrl';

    final insertion = label.isNotEmpty ? '[$label]($url)' : url;
    final current = _controller.value;
    final offset = current.selection.isValid
        ? current.selection.extentOffset
        : current.text.length;
    final before = current.text.substring(0, offset);
    final after = current.text.substring(offset);
    final separator = before.isNotEmpty && !before.endsWith(' ') ? ' ' : '';

    _controller.value = current.copyWith(
      text: '$before$separator$insertion$after',
      selection: TextSelection.collapsed(
        offset: offset + separator.length + insertion.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pillColor = scheme.surfaceContainerHighest;

    return Container(
      color: scheme.surface,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Attachment button ────────────────────────────────────────
          CompositedTransformTarget(
            link: _layerLink,
            child: GestureDetector(
              onTap: _showAttachmentMenu,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pillColor,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Text input pill ─────────────────────────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140, minHeight: 52),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(26),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // ── Send / Like button ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _hasText
                  ? GestureDetector(
                      key: const ValueKey('send'),
                      onTap: widget.isLoading ? null : _submit,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Palette.greenColor,
                        ),
                        child: widget.isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size: 22,
                                color: Colors.white,
                              ),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('like'),
                      onTap: widget.onLike,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Palette.greenColor,
                        ),
                        child: const Icon(
                          Icons.thumb_up_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  const _AttachMenu({
    required this.layerLink,
    required this.scheme,
    required this.onDismiss,
    required this.onLink,
    required this.onPhoto,
    required this.onVideo,
  });

  final LayerLink layerLink;
  final ColorScheme scheme;
  final VoidCallback onDismiss;
  final VoidCallback onLink;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Transparent tap-barrier to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
          ),
        ),
        // Floating card anchored above the + button
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: Material(
            color: Colors.transparent,
            child: IntrinsicWidth(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AttachMenuRow(
                      icon: Icons.link_rounded,
                      label: 'Link',
                      scheme: scheme,
                      onTap: onLink,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    _AttachMenuRow(
                      icon: Icons.image_outlined,
                      label: 'Photo',
                      scheme: scheme,
                      onTap: onPhoto,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    _AttachMenuRow(
                      icon: Icons.videocam_outlined,
                      label: 'Video',
                      scheme: scheme,
                      onTap: onVideo,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachMenuRow extends StatelessWidget {
  const _AttachMenuRow({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 32),
            Icon(icon, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
