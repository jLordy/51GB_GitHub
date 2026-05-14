import 'package:flutter/material.dart';

class EmergencyHotline {
  const EmergencyHotline({
    required this.label,
    required this.phoneNumber,
    required this.icon,
  });

  final String label;
  final String phoneNumber;
  final IconData icon;

  factory EmergencyHotline.fromJson(Map<String, dynamic> json) {
    return EmergencyHotline(
      label: json['label'] as String,
      phoneNumber: json['phone_number'] as String,
      icon: Icons.phone_outlined,
    );
  }
}
