enum CallStatus { ringing, active, ended, declined, missed }

class CallModel {
  final String callId;
  final String callerId;
  final String calleeId;
  final String callerName;
  final String? callerPhotoUrl;
  final bool isVideo;
  final CallStatus status;
  final String? offerSdp;
  final String? answerSdp;

  const CallModel({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.isVideo,
    required this.status,
    this.offerSdp,
    this.answerSdp,
  });

  factory CallModel.fromMap(String id, Map<String, dynamic> map) {
    return CallModel(
      callId: id,
      callerId: map['callerId'] as String,
      calleeId: map['calleeId'] as String,
      callerName: map['callerName'] as String? ?? '',
      callerPhotoUrl: map['callerPhotoUrl'] as String?,
      isVideo: map['isVideo'] as bool? ?? false,
      status: _statusFromString(map['status'] as String? ?? 'ringing'),
      offerSdp: map['offerSdp'] as String?,
      answerSdp: map['answerSdp'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'callerId': callerId,
    'calleeId': calleeId,
    'callerName': callerName,
    'callerPhotoUrl': callerPhotoUrl,
    'isVideo': isVideo,
    'status': status.name,
    'offerSdp': offerSdp,
    'answerSdp': answerSdp,
  };

  CallModel copyWith({
    CallStatus? status,
    String? offerSdp,
    String? answerSdp,
    bool? isVideo,
  }) {
    return CallModel(
      callId: callId,
      callerId: callerId,
      calleeId: calleeId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      isVideo: isVideo ?? this.isVideo,
      status: status ?? this.status,
      offerSdp: offerSdp ?? this.offerSdp,
      answerSdp: answerSdp ?? this.answerSdp,
    );
  }

  static CallStatus _statusFromString(String s) {
    return CallStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CallStatus.ringing,
    );
  }
}
