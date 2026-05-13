import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:frontend/features/calendar/presentation/widgets/appointment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppointmentList extends StatelessWidget {
  const AppointmentList({
    super.key,
    required this.appointments,
    required this.onRetry,
    this.showDoctorName = false,
    this.onEditAppointment,
    this.onDeleteAppointment,
  });

  final AsyncValue<List<AppointmentModel>> appointments;
  final VoidCallback onRetry;
  final bool showDoctorName;
  final void Function(AppointmentModel)? onEditAppointment;
  final void Function(AppointmentModel)? onDeleteAppointment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return appointments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.calendar_today_outlined, color: scheme.error),
              const SizedBox(height: 10),
              Text(
                'Failed to load appointments',
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No appointments for this date.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return AppointmentTile(
              appointment: items[index],
              showDoctorName: showDoctorName,
              onEdit: onEditAppointment != null
                  ? () => onEditAppointment!(items[index])
                  : null,
              onDelete: onDeleteAppointment != null
                  ? () => onDeleteAppointment!(items[index])
                  : null,
            );
          },
        );
      },
    );
  }
}
