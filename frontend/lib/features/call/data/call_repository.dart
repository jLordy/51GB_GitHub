import 'dart:async';

import 'package:frontend/features/call/model/call_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallRepository {
  CallRepository(this._firestore);

  final FirebaseFirestore _firestore;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamController<RTCIceCandidate>? _localCandidateController;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  // ---- Stream access -------------------------------------------------

  MediaStream? get localStream => _localStream;

  // ---- Peer connection -----------------------------------------------

  Future<RTCPeerConnection> _buildPeerConnection({
    required String callId,
    required bool isCaller,
  }) async {
    final pc = await createPeerConnection(_iceServers);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _firestore
          .collection('calls')
          .doc(callId)
          .collection(isCaller ? 'callerCandidates' : 'calleeCandidates')
          .add(candidate.toMap());
    };

    _peerConnection = pc;
    return pc;
  }

  Future<MediaStream> _getUserMedia({required bool isVideo}) async {
    final constraints = {
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    };
    final stream = await navigator.mediaDevices.getUserMedia(constraints);
    _localStream = stream;
    return stream;
  }

  // ---- Caller side ---------------------------------------------------

  Future<CallModel> createCall({
    required String callId,
    required String callerId,
    required String calleeId,
    required String callerName,
    String? callerPhotoUrl,
    required bool isVideo,
  }) async {
    final pc = await _buildPeerConnection(callId: callId, isCaller: true);
    final localStream = await _getUserMedia(isVideo: isVideo);

    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    final call = CallModel(
      callId: callId,
      callerId: callerId,
      calleeId: calleeId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      isVideo: isVideo,
      status: CallStatus.ringing,
      offerSdp: offer.sdp,
    );

    await _firestore.collection('calls').doc(callId).set(call.toMap());
    return call;
  }

  // ---- Callee side ---------------------------------------------------

  Future<void> answerCall({
    required String callId,
    required void Function(MediaStream) onRemoteStream,
  }) async {
    final doc = await _firestore.collection('calls').doc(callId).get();
    final data = doc.data()!;
    final isVideo = data['isVideo'] as bool? ?? false;

    final pc = await _buildPeerConnection(callId: callId, isCaller: false);
    final localStream = await _getUserMedia(isVideo: isVideo);

    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams[0]);
      }
    };

    final offerSdp = data['offerSdp'] as String;
    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await _firestore.collection('calls').doc(callId).update({
      'answerSdp': answer.sdp,
      'status': CallStatus.active.name,
    });
  }

  // Listen for answer on caller side.
  Future<void> listenForAnswer({
    required String callId,
    required void Function(MediaStream) onRemoteStream,
  }) async {
    final pc = _peerConnection;
    if (pc == null) return;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams[0]);
      }
    };

    _firestore.collection('calls').doc(callId).snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;
      final answerSdp = data['answerSdp'] as String?;
      if (answerSdp != null &&
          pc.signalingState != RTCSignalingState.RTCSignalingStateStable) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answerSdp, 'answer'),
        );
      }
    });
  }

  // ---- ICE candidate exchange ----------------------------------------

  StreamSubscription<QuerySnapshot> listenForRemoteCandidates({
    required String callId,
    required bool isCaller,
  }) {
    final collection = isCaller ? 'calleeCandidates' : 'callerCandidates';
    return _firestore
        .collection('calls')
        .doc(callId)
        .collection(collection)
        .snapshots()
        .listen((snapshot) async {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data()!;
              final candidate = RTCIceCandidate(
                data['candidate'] as String,
                data['sdpMid'] as String,
                data['sdpMLineIndex'] as int,
              );
              await _peerConnection?.addCandidate(candidate);
            }
          }
        });
  }

  // ---- Call state stream ---------------------------------------------

  Stream<CallModel> watchCall(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .where((s) => s.exists)
        .map((s) => CallModel.fromMap(callId, s.data()!));
  }

  // ---- End / decline -------------------------------------------------

  Future<void> endCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': CallStatus.ended.name,
    });
    await dispose();
  }

  Future<void> declineCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': CallStatus.declined.name,
    });
    await dispose();
  }

  // ---- Camera / mic toggles ------------------------------------------

  void toggleMic(bool enabled) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  }

  void toggleCamera(bool enabled) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  // ---- Cleanup -------------------------------------------------------

  Future<void> dispose() async {
    await _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    await _localCandidateController?.close();
    _localCandidateController = null;
  }
}
