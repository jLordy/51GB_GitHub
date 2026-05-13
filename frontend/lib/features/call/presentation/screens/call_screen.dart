import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:frontend/features/call/model/call_model.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.otherName, this.otherPhotoUrl});

  final String otherName;
  final String? otherPhotoUrl;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;
  bool _callEnded = false;
  // Captured in didChangeDependencies so it's safe to use in dispose().
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context);
  }

  @override
  void initState() {
    super.initState();
    _initRenderers();
    // Mark call screen as visible so the floating banner is hidden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(callScreenVisibleProvider.notifier).state = true;
      }
    });
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _renderersInitialized = true);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    // Schedule after the current frame so state is updated outside build/dispose
    // — updating Riverpod state synchronously in dispose() triggers listeners
    // while the tree is still tearing down, causing an exception.
    final container = _container;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container?.read(callScreenVisibleProvider.notifier).state = false;
    });
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);

    // Sync streams to renderers.
    if (_renderersInitialized) {
      _localRenderer.srcObject = callState.localStream;
      _remoteRenderer.srcObject = callState.remoteStream;
    }

    // Show "Call Ended" briefly, then pop.
    ref.listen<CallState>(callControllerProvider, (previous, next) {
      if (previous?.status != next.status &&
          (next.status == CallStatus.ended ||
              next.status == CallStatus.declined ||
              next.status == null)) {
        if (mounted && !_callEnded) {
          setState(() => _callEnded = true);
          final nav = Navigator.of(context);
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) nav.pop();
          });
        }
      }
    });

    final isVideo = callState.isVideoOn;
    final status = callState.status;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isVideo ? Colors.black : const Color(0xFF1B5E20),
        body: _callEnded
            ? _CallEndedOverlay(
                name: widget.otherName,
                photoUrl: widget.otherPhotoUrl,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Remote video / audio fallback
                  if (isVideo &&
                      _renderersInitialized &&
                      callState.remoteStream != null)
                    ColoredBox(
                      color: Colors.black,
                      child: RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    )
                  else
                    _AudioCallBackground(
                      name: widget.otherName,
                      photoUrl: widget.otherPhotoUrl,
                      status: status,
                      elapsed: callState.elapsedSeconds,
                      formatDuration: _formatDuration,
                    ),

                  // Local PiP (video only)
                  if (isVideo &&
                      _renderersInitialized &&
                      callState.localStream != null)
                    Positioned(
                      top: 48,
                      right: 16,
                      width: 100,
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                          color: Colors.black,
                          child: RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    ),

                  // Duration overlay (video mode)
                  if (isVideo && status == CallStatus.active)
                    Positioned(
                      top: 52,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          _formatDuration(callState.elapsedSeconds),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  // Back button
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),

                  // Controls
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: _ControlsRow(
                      isMuted: callState.isMuted,
                      isVideoOn: isVideo,
                      isSpeakerOn: callState.isSpeakerOn,
                      onMicToggle: controller.toggleMic,
                      onCameraToggle: controller.toggleCamera,
                      onSpeakerToggle: controller.toggleSpeaker,
                      onSwitchCamera: controller.switchCamera,
                      onEnd: controller.endCall,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Call ended overlay ───────────────────────────────────────────────────────

class _CallEndedOverlay extends StatelessWidget {
  const _CallEndedOverlay({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        color: const Color(0xFF1B5E20),
        child: Stack(
          children: [
            // Centered content — Positioned.fill constrains the Column to the
            // full Stack width so crossAxisAlignment.center works correctly.
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Palette.darkSurfaceContainerColor,
                    child: photoUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: photoUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Call Ended',
                    style: TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                ],
              ),
            ),
            // Back button top-left
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Audio‑call background ────────────────────────────────────────────────────

class _AudioCallBackground extends StatelessWidget {
  const _AudioCallBackground({
    required this.name,
    required this.photoUrl,
    required this.status,
    required this.elapsed,
    required this.formatDuration,
  });

  final String name;
  final String? photoUrl;
  final CallStatus? status;
  final int elapsed;
  final String Function(int) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B5E20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Palette.darkSurfaceContainerColor,
            child: photoUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: photoUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 40, color: Colors.white70),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status == CallStatus.active ? formatDuration(elapsed) : 'Calling…',
            style: const TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Controls row ─────────────────────────────────────────────────────────────

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.isMuted,
    required this.isVideoOn,
    required this.isSpeakerOn,
    required this.onMicToggle,
    required this.onCameraToggle,
    required this.onSpeakerToggle,
    required this.onSwitchCamera,
    required this.onEnd,
  });

  final bool isMuted;
  final bool isVideoOn;
  final bool isSpeakerOn;
  final VoidCallback onMicToggle;
  final VoidCallback onCameraToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onSwitchCamera;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Unmute' : 'Mute',
          onTap: onMicToggle,
        ),
        if (isVideoOn)
          _ControlButton(
            icon: Icons.cameraswitch,
            label: 'Flip',
            onTap: onSwitchCamera,
          ),
        _ControlButton(
          icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
          label: isVideoOn ? 'Cam off' : 'Cam on',
          onTap: onCameraToggle,
        ),
        _ControlButton(
          icon: isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: 'Speaker',
          onTap: onSpeakerToggle,
        ),
        _ControlButton(
          icon: Icons.call_end,
          label: 'End',
          color: const Color(0xFFD62828),
          onTap: onEnd,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Colors.white24;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: bg,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
