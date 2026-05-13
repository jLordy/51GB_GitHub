import 'dart:async';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/call/data/call_repository.dart';
import 'package:frontend/features/call/model/call_model.dart';
import 'package:frontend/features/chat/data/chat_repository.dart';
import 'package:frontend/features/chat/model/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' hide MessageType;

// ─── State ────────────────────────────────────────────────────────────────────

class CallState {
  const CallState({
    this.callModel,
    this.localStream,
    this.remoteStream,
    this.isVideoOn = false,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.elapsedSeconds = 0,
    this.otherName = '',
    this.otherPhotoUrl,
    this.error,
  });

  final CallModel? callModel;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final bool isVideoOn;
  final bool isMuted;
  final bool isSpeakerOn;
  final int elapsedSeconds;
  final String otherName;
  final String? otherPhotoUrl;
  final String? error;

  CallStatus? get status => callModel?.status;
  bool get hasActiveCall => callModel != null;

  CallState copyWith({
    CallModel? callModel,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool? isVideoOn,
    bool? isMuted,
    bool? isSpeakerOn,
    int? elapsedSeconds,
    String? otherName,
    String? otherPhotoUrl,
    String? error,
  }) {
    return CallState(
      callModel: callModel ?? this.callModel,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      otherName: otherName ?? this.otherName,
      otherPhotoUrl: otherPhotoUrl ?? this.otherPhotoUrl,
      error: error,
    );
  }

  CallState clearCall() => const CallState();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// True while CallScreen is mounted — used to hide the floating banner.
final callScreenVisibleProvider = StateProvider<bool>((ref) => false);

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(FirebaseFirestore.instance);
});

final callControllerProvider = StateNotifierProvider<CallController, CallState>(
  (ref) => CallController(
    ref.read(callRepositoryProvider),
    ref.read(apiClientProvider),
    ref.read(chatRepositoryProvider),
  ),
);

// ─── Controller ───────────────────────────────────────────────────────────────

class CallController extends StateNotifier<CallState> {
  CallController(this._repo, this._apiClient, this._chatRepo)
    : super(const CallState());

  final CallRepository _repo;
  final ApiClient _apiClient;
  final ChatRepository _chatRepo;

  StreamSubscription<CallModel>? _callSub;
  StreamSubscription? _candidateSub;
  Timer? _durationTimer;

  // ---- Outgoing call -------------------------------------------------------

  Future<void> startCall({
    required String calleeUid,
    required String callerUid,
    required String callerName,
    String calleeName = '',
    String? callerPhotoUrl,
    String? calleePhotoUrl,
    bool isVideo = false,
  }) async {
    final callId = FirebaseFirestore.instance.collection('calls').doc().id;

    try {
      final call = await _repo.createCall(
        callId: callId,
        callerId: callerUid,
        calleeId: calleeUid,
        callerName: callerName,
        callerPhotoUrl: callerPhotoUrl,
        isVideo: isVideo,
      );

      state = CallState(
        callModel: call,
        localStream: _repo.localStream,
        isVideoOn: isVideo,
        otherName: calleeName,
        otherPhotoUrl: calleePhotoUrl,
      );

      // Tell callee via FCM (best-effort)
      try {
        await _apiClient.post(
          '/api/call/notify',
          body: {
            'callee_uid': calleeUid,
            'call_id': callId,
            'caller_name': callerName,
            'caller_photo_url': callerPhotoUrl,
            'call_type': isVideo ? 'video' : 'audio',
          },
        );
      } catch (_) {
        // FCM failure is non-fatal — callee still sees Firestore update.
      }

      // Listen for callee's answer and their ICE candidates.
      await _repo.listenForAnswer(
        callId: callId,
        onRemoteStream: (stream) {
          state = state.copyWith(remoteStream: stream);
        },
      );

      _candidateSub = _repo.listenForRemoteCandidates(
        callId: callId,
        isCaller: true,
      );

      _watchCallStatus(callId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await _repo.dispose();
    }
  }

  // ---- Incoming call -------------------------------------------------------

  Future<void> answerCall(CallModel incomingCall) async {
    try {
      await _repo.answerCall(
        callId: incomingCall.callId,
        onRemoteStream: (stream) {
          state = state.copyWith(remoteStream: stream);
        },
      );

      _candidateSub = _repo.listenForRemoteCandidates(
        callId: incomingCall.callId,
        isCaller: false,
      );

      state = state.copyWith(
        callModel: incomingCall.copyWith(status: CallStatus.active),
        localStream: _repo.localStream,
        isVideoOn: incomingCall.isVideo,
        otherName: incomingCall.callerName,
        otherPhotoUrl: incomingCall.callerPhotoUrl,
      );

      _watchCallStatus(incomingCall.callId);
      _startDurationTimer();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await _repo.dispose();
    }
  }

  Future<void> declineCall(String callId) async {
    await _repo.declineCall(callId);
    await _cleanup();
  }

  // ---- In-call controls ---------------------------------------------------

  Future<void> endCall() async {
    final call = state.callModel;
    final callId = call?.callId;
    final wasMissed = call?.status == CallStatus.ringing;

    if (callId != null) await _repo.endCall(callId);

    // Caller hung up while still ringing → send a missed call message.
    if (wasMissed && call != null) {
      try {
        final conv = await _chatRepo.createOrFetchConversation(call.calleeId);
        await _chatRepo.sendMessage(
          conversationId: conv.conversationId,
          text: '📞 Missed call',
          type: MessageType.missedCall,
        );
      } catch (_) {
        // Non-fatal — missed call message is best-effort.
      }
    }

    await _cleanup();
  }

  void toggleMic() {
    final muted = !state.isMuted;
    _repo.toggleMic(!muted);
    state = state.copyWith(isMuted: muted);
  }

  void toggleCamera() {
    final enabled = !state.isVideoOn;
    _repo.toggleCamera(enabled);
    state = state.copyWith(isVideoOn: enabled);
  }

  Future<void> switchCamera() async {
    await _repo.switchCamera();
  }

  void toggleSpeaker() {
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
    // flutter_webrtc Helper.setSpeakerphoneOn is not available on all
    // platforms — best‑effort call.
    try {
      Helper.setSpeakerphoneOn(state.isSpeakerOn);
    } catch (_) {}
  }

  // ---- Internal helpers ---------------------------------------------------

  void _watchCallStatus(String callId) {
    _callSub?.cancel();
    _callSub = _repo.watchCall(callId).listen((updatedCall) {
      state = state.copyWith(callModel: updatedCall);

      if (updatedCall.status == CallStatus.active && _durationTimer == null) {
        _startDurationTimer();
      }

      if (updatedCall.status == CallStatus.ended ||
          updatedCall.status == CallStatus.declined ||
          updatedCall.status == CallStatus.missed) {
        _cleanup();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  Future<void> _cleanup() async {
    _callSub?.cancel();
    _callSub = null;
    _candidateSub?.cancel();
    _candidateSub = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    await _repo.dispose();
    state = const CallState();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
