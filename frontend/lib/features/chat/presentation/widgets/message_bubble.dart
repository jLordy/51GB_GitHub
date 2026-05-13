import 'package:frontend/features/chat/model/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.senderPhotoUrl,
    this.showSeen = false,
    this.onDelete,
  });

  final MessageModel message;
  final bool isMine;
  final String? senderPhotoUrl;
  final bool showSeen;
  final VoidCallback? onDelete;

  static bool _isEmojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    for (final r in trimmed.runes) {
      if (r == 0x20 || r == 0x0A) continue; // spaces between emojis
      if (_isEmojiCodePoint(r)) continue;
      return false;
    }
    return true;
  }

  static bool _isEmojiCodePoint(int r) {
    if (r == 0x200D || r == 0x20E3) return true; // ZWJ, keycap
    if (r >= 0xFE00 && r <= 0xFE0F) return true; // variation selectors
    if (r >= 0x1F3FB && r <= 0x1F3FF) return true; // skin tones
    if (r == 0x00A9 || r == 0x00AE) return true; // © ®
    if (r == 0x203C || r == 0x2049) return true; // ‼ ⁉
    if (r == 0x2122 || r == 0x2139) return true; // ™ ℹ
    if (r >= 0x2194 && r <= 0x27BF) return true; // arrows & symbols
    if (r >= 0x2934 && r <= 0x2935) return true;
    if (r >= 0x2B05 && r <= 0x2B07) return true;
    if (r >= 0x2B1B && r <= 0x2B1C) return true;
    if (r == 0x2B50 || r == 0x2B55) return true;
    if (r == 0x3030 || r == 0x303D) return true;
    if (r == 0x3297 || r == 0x3299) return true;
    if (r >= 0x1F1E0 && r <= 0x1F1FF) {
      return true; // regional indicators (flags)
    }
    if (r >= 0x1F004 && r <= 0x1FFFF) return true; // all supplemental emoji
    return false;
  }

  bool get _isEmojiOnlyMessage =>
      message.type == MessageType.text && _isEmojiOnly(message.text ?? '');

  void _showMessageOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canCopy =
        message.type == MessageType.text && (message.text?.isNotEmpty ?? false);
    if (!canCopy && onDelete == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canCopy)
                  ListTile(
                    leading: Icon(Icons.copy_rounded, color: scheme.onSurface),
                    title: const Text('Copy'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Clipboard.setData(ClipboardData(text: message.text!));
                    },
                  ),
                if (onDelete != null)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDelete!();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // ── Emoji-only message: no bubble, just large emoji ─────────────
    if (_isEmojiOnlyMessage) {
      return GestureDetector(
        onLongPress: () => _showMessageOptions(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: isMine
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMine) ...[
                    _SenderAvatar(photoUrl: senderPhotoUrl, scheme: scheme),
                    const SizedBox(width: 10),
                  ],
                  Text(message.text!, style: const TextStyle(fontSize: 40)),
                  if (isMine) const SizedBox(width: 4),
                ],
              ),
              if (isMine && showSeen)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4),
                  child: Text(
                    'Seen',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // ── Regular message bubble ───────────────────────────────────────
    final bubbleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        // ── Received: avatar ──────────────────────────────────────────
        if (!isMine) ...[
          _SenderAvatar(photoUrl: senderPhotoUrl, scheme: scheme),
          const SizedBox(width: 10),
        ],

        // ── Bubble ────────────────────────────────────────────────────
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding:
                (message.type == MessageType.image ||
                        message.type == MessageType.video) &&
                    (message.mediaUrl?.isNotEmpty ?? false)
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  (message.type == MessageType.image ||
                          message.type == MessageType.video) &&
                      (message.mediaUrl?.isNotEmpty ?? false)
                  ? Colors.transparent
                  : (isMine ? scheme.primary : scheme.surface),
              borderRadius: BorderRadius.circular(20),
              boxShadow:
                  (message.type == MessageType.image ||
                          message.type == MessageType.video) &&
                      (message.mediaUrl?.isNotEmpty ?? false)
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: _buildContent(context, scheme),
          ),
        ),

        if (isMine) const SizedBox(width: 4),
      ],
    );

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            bubbleRow,
            if (isMine && showSeen)
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 4),
                child: Text(
                  'Seen',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme scheme) {
    switch (message.type) {
      case MessageType.image:
        final imageUrl = message.mediaUrl;
        if (imageUrl == null || imageUrl.isEmpty) {
          return _MediaBubble(
            url: null,
            icon: Icons.image_rounded,
            label: 'Photo',
            isMine: isMine,
            scheme: scheme,
          );
        }
        return GestureDetector(
          onTap: () => _openFullscreen(context, imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: 220,
              height: 220,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (ctx, _, _) => _MediaBubble(
                url: imageUrl,
                icon: Icons.broken_image_rounded,
                label: 'Photo',
                isMine: isMine,
                scheme: scheme,
              ),
            ),
          ),
        );
      case MessageType.video:
        final videoUrl = message.mediaUrl;
        if (videoUrl == null || videoUrl.isEmpty) {
          return _MediaBubble(
            url: null,
            icon: Icons.videocam_rounded,
            label: 'Video',
            isMine: isMine,
            scheme: scheme,
          );
        }
        return _VideoBubble(url: videoUrl, scheme: scheme);
      case MessageType.text:
        return _buildTextContent(message.text ?? '', scheme);
      case MessageType.missedCall:
        return _buildMissedCallContent(scheme);
    }
  }

  Widget _buildMissedCallContent(ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.phone_missed_rounded,
          size: 16,
          color: isMine ? scheme.onPrimary : scheme.error,
        ),
        const SizedBox(width: 6),
        Text(
          'Missed call',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: isMine ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _openFullscreen(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => GestureDetector(
        onTap: () => Navigator.of(dialogCtx).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(String text, ColorScheme scheme) {
    // Matches both [label](url) and bare https?:// URLs
    final linkPattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)|(https?://\S+)');
    final matches = linkPattern.allMatches(text);
    final baseColor = isMine ? scheme.onPrimary : scheme.onSurface;
    final linkColor = isMine ? scheme.onPrimary : scheme.primary;

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(fontSize: 15, color: baseColor, height: 1.4),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final String label;
      final String url;

      if (match.group(1) != null) {
        // Markdown link: [label](url)
        label = match.group(1)!;
        url = match.group(2)!;
      } else {
        // Bare URL
        label = match.group(3)!;
        url = match.group(3)!;
      }

      spans.add(
        TextSpan(
          text: label,
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: linkColor,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 15, color: baseColor, height: 1.4),
        children: spans,
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.photoUrl, required this.scheme});

  final String? photoUrl;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.outlineVariant,
      child: CircleAvatar(
        radius: 18.5,
        backgroundColor: scheme.surfaceContainerHighest,
        child: photoUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photoUrl!,
                  width: 37,
                  height: 37,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

// ── Inline video bubble ─────────────────────────────────────────────────────

class _VideoBubble extends StatefulWidget {
  const _VideoBubble({required this.url, required this.scheme});
  final String url;
  final ColorScheme scheme;
  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _ctrl.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    _ctrl.pause();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPlayer(url: widget.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 220,
          height: 220,
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        ),
      );
    }

    final bool isPlaying = _ctrl.value.isPlaying;
    final Duration pos = _ctrl.value.position;
    final Duration total = _ctrl.value.duration;
    final bool ended = !isPlaying && total > Duration.zero && pos >= total;

    return GestureDetector(
      onTap: _openFullscreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          child: AspectRatio(
            aspectRatio: _ctrl.value.aspectRatio > 0
                ? _ctrl.value.aspectRatio
                : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_ctrl),
                Container(
                  color: Colors.black38,
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ended ? Icons.replay_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({required this.url});
  final String url;
  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      });
    _ctrl.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onUpdate);
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _showControls = true);
    if (_ctrl.value.isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && _ctrl.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isPlaying = _ctrl.value.isPlaying;
    final Duration pos = _ctrl.value.position;
    final Duration total = _ctrl.value.duration;
    final bool ended = !isPlaying && total > Duration.zero && pos >= total;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _ctrl.value.aspectRatio,
                    child: GestureDetector(
                      onTap: () {
                        if (!_showControls) {
                          setState(() => _showControls = true);
                          Future<void>.delayed(const Duration(seconds: 2), () {
                            if (mounted && _ctrl.value.isPlaying) {
                              setState(() => _showControls = false);
                            }
                          });
                        } else {
                          _togglePlay();
                        }
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_ctrl),
                          if (ended)
                            GestureDetector(
                              onTap: () {
                                _ctrl.seekTo(Duration.zero);
                                _ctrl.play();
                                setState(() => _showControls = false);
                              },
                              child: Container(
                                color: Colors.black45,
                                alignment: Alignment.center,
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.replay_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                            )
                          else if (_showControls || !isPlaying)
                            Container(
                              color: Colors.black26,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Spacer(),
                                  Center(
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      0,
                                      8,
                                      8,
                                    ),
                                    child: VideoProgressIndicator(
                                      _ctrl,
                                      allowScrubbing: true,
                                      colors: VideoProgressColors(
                                        playedColor: scheme.primary,
                                        bufferedColor: Colors.white38,
                                        backgroundColor: Colors.white24,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white54),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fallback icon+label bubble (used for broken/missing media) ────────────────

class _MediaBubble extends StatelessWidget {
  const _MediaBubble({
    required this.url,
    required this.icon,
    required this.label,
    required this.isMine,
    required this.scheme,
  });

  final String? url;
  final IconData icon;
  final String label;
  final bool isMine;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final textColor = isMine ? scheme.onPrimary : scheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: textColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        ),
      ],
    );
  }
}
