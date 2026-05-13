import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:frontend/features/call/model/call_model.dart';
import 'package:frontend/features/call/presentation/screens/call_screen.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen overlay shown when the current user receives a call.
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key, required this.call});

  final CallModel call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callControllerProvider.notifier);

    // Auto-dismiss when the caller cancels.
    ref.listen<CallState>(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.missed ||
          next.status == null) {
        if (context.mounted) Navigator.of(context).maybePop();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Caller info ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: Palette.darkSurfaceContainerColor,
                    child: call.callerPhotoUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: call.callerPhotoUrl!,
                              width: 128,
                              height: 128,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Text(
                                call.callerName.isNotEmpty
                                    ? call.callerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 44,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            call.callerName.isNotEmpty
                                ? call.callerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 44,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    call.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    call.isVideo
                        ? 'Incoming video call'
                        : 'Incoming audio call',
                    style: const TextStyle(color: Colors.white60, fontSize: 15),
                  ),
                ],
              ),
            ),

            // ── Action buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _ActionButton(
                    icon: Icons.call_end,
                    label: 'Decline',
                    color: const Color(0xFFD62828),
                    onTap: () async {
                      await controller.declineCall(call.callId);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                  ),

                  // Accept
                  _ActionButton(
                    icon: Icons.call,
                    label: 'Accept',
                    color: Palette.greenColor,
                    onTap: () async {
                      await controller.answerCall(call);
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              otherName: call.callerName,
                              otherPhotoUrl: call.callerPhotoUrl,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
