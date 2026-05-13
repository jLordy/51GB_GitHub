import 'package:frontend/features/onboarding/presentation/widgets/slider_input.dart';
import 'package:flutter/material.dart';

/// Step 7 — tobacco and alcohol lifestyle inputs.
///
/// [onTobaccoChanged] and [onAlcoholChanged] are lifted to the parent
/// that owns [_tobaccoPackYears] and [_alcoholWeekly].
class LifestyleStep extends StatelessWidget {
  const LifestyleStep({
    super.key,
    required this.tobaccoPackYears,
    required this.alcoholWeekly,
    required this.onTobaccoChanged,
    required this.onAlcoholChanged,
  });

  final double tobaccoPackYears;
  final double alcoholWeekly;
  final ValueChanged<double> onTobaccoChanged;
  final ValueChanged<double> onAlcoholChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Lifestyle',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter 0 if not applicable.',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        Text(
          'Tobacco pack-years',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '1 pack-year = smoking 1 pack/day for 1 year. Enter 0 if non-smoker.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SliderInput(
          value: tobaccoPackYears,
          min: 0,
          max: 100,
          divisions: 200,
          unit: 'pack-years',
          onChanged: onTobaccoChanged,
        ),
        const SizedBox(height: 28),
        Text(
          'Weekly alcohol consumption',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Count each standard drink separately. Enter 0 if non-drinker.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SliderInput(
          value: alcoholWeekly,
          min: 0,
          max: 50,
          divisions: 50,
          unit: 'drinks/week',
          onChanged: onAlcoholChanged,
        ),
      ],
    );
  }
}
