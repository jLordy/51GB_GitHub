import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/features/call/controller/call_controller.dart';
import 'package:frontend/features/call/model/call_model.dart';
import 'package:frontend/features/call/presentation/screens/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A persistent green banner that floats at the top of the screen whenever a
/// call is in progress but [CallScreen] is not currently open.
/// Tapping it navigates back to [CallScreen].
class ActiveCallBanner extends ConsumerWidget {
  const ActiveCallBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callControllerProvider);
    final callScreenVisible = ref.watch(callScreenVisibleProvider);

    final showBanner = callState.hasActiveCall && !callScreenVisible;

    return Column(
      children: [
        if (showBanner) _CallBannerTile(callState: callState),
        Expanded(
          child: showBanner
              ? MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: MediaQuery.of(context).padding.copyWith(top: 0),
                  ),
                  child: child,
                )
              : child,
        ),
      ],
    );
  }
}

class _CallBannerTile extends ConsumerWidget {
  const _CallBannerTile({required this.callState});

  final CallState callState;

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = callState.callModel!;
    final isActive = callState.status == CallStatus.active;

    return GestureDetector(
      onTap: () {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CallScreen(
              otherName: callState.otherName,
              otherPhotoUrl: callState.otherPhotoUrl,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          // Top padding ensures content clears the status bar.
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          color: const Color(0xFF2D6A35),
          child: Row(
            children: [
              const Icon(Icons.call, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      callState.otherName.isNotEmpty
                          ? callState.otherName
                          : model.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isActive
                          ? _formatDuration(callState.elapsedSeconds)
                          : 'Connecting…',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
