import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:flutter/material.dart';

class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    this.showDoctorName = false,
    this.onEdit,
    this.onDelete,
  });

  final AppointmentModel appointment;
  final bool showDoctorName;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: (onEdit != null || onDelete != null)
          ? () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => _AppointmentContextSheet(
                appointment: appointment,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: _accentColor(scheme, appointment),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _titleText(appointment, showDoctorName),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.reason ??
                        (appointment.type == AppointmentType.special
                            ? 'Doctor event'
                            : 'Consultation'),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (showDoctorName &&
                      appointment.type != AppointmentType.special) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'with Dr. ${appointment.doctor?.displayName ?? 'Unknown doctor'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                  if ((appointment.clinicName?.trim().isNotEmpty ?? false) ||
                      (appointment.clinicPlace?.trim().isNotEmpty ??
                          false)) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (appointment.clinicName?.trim().isNotEmpty == true)
                          appointment.clinicName!.trim(),
                        if (appointment.clinicPlace?.trim().isNotEmpty == true)
                          appointment.clinicPlace!.trim(),
                      ].join(' • '),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _timeRange(appointment),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor(
                      scheme,
                      appointment,
                    ).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    appointment.type == AppointmentType.special
                        ? 'Event'
                        : _statusLabel(appointment.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _accentColor(scheme, appointment),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _timeRange(AppointmentModel appointment) {
    if (appointment.endTime == null || appointment.endTime!.trim().isEmpty) {
      return appointment.startTime;
    }
    return '${appointment.startTime} - ${appointment.endTime}';
  }

  static String _statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.noShow:
        return 'No-show';
      case AppointmentStatus.scheduled:
        return 'Scheduled';
    }
  }

  static Color _statusColor(ColorScheme scheme, AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.completed:
        return Colors.teal;
      case AppointmentStatus.cancelled:
        return scheme.error;
      case AppointmentStatus.noShow:
        return Colors.orange;
      case AppointmentStatus.scheduled:
        return scheme.primary;
    }
  }

  static Color _accentColor(ColorScheme scheme, AppointmentModel appointment) {
    if (appointment.type == AppointmentType.special) {
      return Colors.deepPurple;
    }
    return _statusColor(scheme, appointment.status);
  }

  static String _titleText(AppointmentModel appointment, bool showDoctorName) {
    if (showDoctorName) {
      if (appointment.type == AppointmentType.special) {
        return appointment.doctor?.displayName ?? 'Doctor special event';
      }
      // Caregiver view: show who the appointment is FOR (the patient)
      return appointment.patient?.displayName ?? 'Patient';
    }
    if (appointment.type == AppointmentType.special) {
      return 'Special event';
    }
    return appointment.patient?.displayName ?? 'Patient';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppointmentContextSheet — long-press context menu
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentContextSheet extends StatelessWidget {
  const _AppointmentContextSheet({
    required this.appointment,
    this.onEdit,
    this.onDelete,
  });

  final AppointmentModel appointment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = appointment.type == AppointmentType.special
        ? (appointment.reason ?? 'Special event')
        : (appointment.patient?.displayName ?? 'Patient');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              appointment.startTime,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          if (onEdit != null)
            ListTile(
              leading: Icon(Icons.edit_rounded, color: scheme.onSurface),
              title: Text('Edit', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                onEdit!();
              },
            ),
          if (onDelete != null)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: Text('Delete', style: TextStyle(color: scheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                onDelete!();
              },
            ),
        ],
      ),
    );
  }
}
