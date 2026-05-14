import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/assistance/model/emergency_hotline.dart';
import 'package:frontend/features/assistance/model/financial_assistance.dart';

final assistanceRepositoryProvider = Provider<AssistanceRepository>((ref) {
  return AssistanceRepository(ref.read(apiClientProvider));
});

class AssistanceData {
  const AssistanceData({
    required this.programs,
    required this.hotlines,
  });

  final List<FinancialAssistance> programs;
  final List<EmergencyHotline> hotlines;
}

class AssistanceRepository {
  AssistanceRepository(this._api);

  final ApiClient _api;

  Future<AssistanceData> fetchAll() async {
    try {
      final res = await _api.get(
        '/api/assistance',
        requiresAuth: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw DioException(
          requestOptions: RequestOptions(path: '/api/assistance'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final body = res.data as Map<String, dynamic>;
      final programs = (body['programs'] as List)
          .map((e) => FinancialAssistance.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      final hotlines = (body['hotlines'] as List)
          .map((e) => EmergencyHotline.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      return AssistanceData(programs: programs, hotlines: hotlines);
    } catch (_) {
      // Backend endpoint not yet available — return curated local data.
      return AssistanceData(
        programs: _localPrograms,
        hotlines: _localHotlines,
      );
    }
  }

  // ── Local fallback data — Philippine healthcare assistance programs ──────────

  static const _localPrograms = <FinancialAssistance>[
    FinancialAssistance(
      providerName: 'PhilHealth',
      amount: 'Up to ₱40,000',
      distance: '0.8 km',
      category: 'Health Insurance',
    ),
    FinancialAssistance(
      providerName: 'PCSO IMAP',
      amount: 'Up to ₱20,000',
      distance: '1.2 km',
      category: 'Medical Aid',
    ),
    FinancialAssistance(
      providerName: 'Malasakit Center',
      amount: 'Up to ₱100,000',
      distance: '2.0 km',
      category: 'Integrated Aid',
    ),
    FinancialAssistance(
      providerName: 'DSWD AICS',
      amount: 'Up to ₱10,000',
      distance: '1.5 km',
      category: 'Social Welfare',
    ),
    FinancialAssistance(
      providerName: 'DOH MAFP',
      amount: 'Up to ₱50,000',
      distance: '3.1 km',
      category: 'Government Aid',
    ),
  ];

  static final _localHotlines = <EmergencyHotline>[
    EmergencyHotline(
      label: 'National Emergency',
      phoneNumber: '911',
      icon: Icons.local_police_outlined,
    ),
    EmergencyHotline(
      label: 'DOH Healthline',
      phoneNumber: '1555',
      icon: Icons.health_and_safety_outlined,
    ),
    EmergencyHotline(
      label: 'Philippine Red Cross',
      phoneNumber: '143',
      icon: Icons.emergency_outlined,
    ),
    EmergencyHotline(
      label: 'PhilHealth Hotline',
      phoneNumber: '02-8441-7442',
      icon: Icons.medical_services_outlined,
    ),
    EmergencyHotline(
      label: 'DSWD Crisis Hotline',
      phoneNumber: '8888',
      icon: Icons.support_agent_outlined,
    ),
    EmergencyHotline(
      label: 'PCSO Medical Aid',
      phoneNumber: '02-8241-4244',
      icon: Icons.volunteer_activism_outlined,
    ),
    EmergencyHotline(
      label: 'NDRRMC',
      phoneNumber: '117',
      icon: Icons.warning_amber_rounded,
    ),
  ];
}
