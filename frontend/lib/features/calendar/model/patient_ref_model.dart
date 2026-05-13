import 'package:flutter/foundation.dart';

@immutable
class PatientRefModel {
  const PatientRefModel({required this.uid, this.displayName, this.photoUrl});

  final String uid;
  final String? displayName;
  final String? photoUrl;

  factory PatientRefModel.fromJson(Map<String, dynamic> json) {
    return PatientRefModel(
      uid: json['uid'] as String? ?? '',
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'display_name': displayName,
      'photo_url': photoUrl,
    };
  }
}
