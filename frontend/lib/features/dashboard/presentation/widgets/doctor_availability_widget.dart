import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/calendar/controller/calendar_provider.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

class DoctorAvailabilityWidget extends ConsumerWidget {
  const DoctorAvailabilityWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    final appointmentAsync = ref.watch(nextPatientAppointmentProvider);

    return GlassmorphicContainer(
      child: appointmentAsync.when(
        loading: () => Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Palette.greenColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                color: Palette.greenColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading appointments...',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        error: (err, _) => Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: cs.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load appointments',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (appointment) {
          if (appointment == null) {
            // No upcoming appointments
            return Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Palette.greenColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: Palette.greenColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No upcoming appointments',
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'View doctor availability',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/calendar'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Palette.greenColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      'Check',
                      style: tt.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Show next appointment
          final dateStr = _formatDate(appointment.appointmentDate);
          final doctorName = appointment.doctor?.displayName ?? 'Doctor';

          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Palette.greenColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_outlined,
                  color: Palette.greenColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Appointment',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$dateStr • Dr. $doctorName',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/calendar'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Palette.greenColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    'View',
                    style: tt.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final appointmentDay = DateTime(date.year, date.month, date.day);

    if (appointmentDay == today) return 'Today';
    if (appointmentDay == tomorrow) return 'Tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }
}