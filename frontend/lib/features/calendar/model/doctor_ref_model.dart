import 'package:flutter/foundation.dart';

@immutable
class DoctorRefModel {
  const DoctorRefModel({
    required this.uid,
    this.displayName,
    this.photoUrl,
    this.specialization,
  });

  final String uid;
  final String? displayName;
  final String? photoUrl;
  final String? specialization;

  factory DoctorRefModel.fromJson(Map<String, dynamic> json) {
    return DoctorRefModel(
      uid: json['uid'] as String? ?? '',
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      specialization: json['specialization'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'display_name': displayName,
      'photo_url': photoUrl,
      'specialization': specialization,
    };
  }
}
