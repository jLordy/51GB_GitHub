import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

/// Shows the next confirmed appointment or a "Book" CTA.
///
/// Wire up a calendarProvider / appointmentProvider to display real data:
///   final appointment = ref.watch(nextAppointmentProvider);
///   Then conditionally render the appointment details row vs. empty state.
class DoctorAvailabilityWidget extends ConsumerWidget {
  const DoctorAvailabilityWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GlassmorphicContainer(
      child: Row(
        children: <Widget>[
          // Category icon
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

          // Empty-state copy
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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

          // Book CTA
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
      ),
    );
  }
}
