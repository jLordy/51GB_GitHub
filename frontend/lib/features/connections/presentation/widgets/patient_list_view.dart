import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/connections/model/connection_model.dart';
import 'package:frontend/features/connections/presentation/widgets/patient_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientListView extends StatelessWidget {
  const PatientListView({
    super.key,
    required this.patients,
    required this.connections,
    required this.currentUid,
  });

  final List<UserModel> patients;
  final List<ConnectionModel> connections;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A97A).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF359361).withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    '${patients.length} patient${patients.length == 1 ? '' : 's'} connected',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF359361),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: patients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final patient = patients[i];
                final conn = connections.firstWhere(
                  (c) =>
                      c.requesterUid == patient.uid ||
                      c.recipientUid == patient.uid,
                  orElse: () => connections[i],
                );
                return PatientCard(
                  patient: patient,
                  connectionId: conn.connectionId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
