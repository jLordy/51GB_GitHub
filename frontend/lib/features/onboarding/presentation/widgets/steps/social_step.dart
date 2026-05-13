import 'package:frontend/features/onboarding/presentation/widgets/option_card.dart';
import 'package:flutter/material.dart';

/// Step 8 — social determinants of health.
///
/// Both [livingSituation] and [supportSystemStrength] selections and their
/// callbacks are lifted to the parent that owns those state fields.
class SocialStep extends StatelessWidget {
  const SocialStep({
    super.key,
    required this.livingSituation,
    required this.supportSystemStrength,
    required this.onLivingChanged,
    required this.onSupportChanged,
  });

  final String? livingSituation;
  final String? supportSystemStrength;
  final void Function(String value) onLivingChanged;
  final void Function(String value) onSupportChanged;

  static const _livingOptions = [
    ('alone', 'Alone'),
    ('with_family', 'With Family'),
    ('with_partner', 'With Partner / Spouse'),
    ('assisted_living', 'Assisted Living Facility'),
    ('other', 'Other'),
  ];

  static const _supportOptions = [
    ('strong', 'Strong — I have reliable people I can count on'),
    ('moderate', 'Moderate — Some support, but gaps exist'),
    ('minimal', 'Minimal — Very little support available'),
    ('none', 'None — I feel largely unsupported'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Social & Living',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Current living situation',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ..._livingOptions.map(
          (opt) => OptionCard(
            label: opt.$2,
            selected: livingSituation == opt.$1,
            onTap: () => onLivingChanged(opt.$1),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Perceived support system',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How supported do you feel by your social network?',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        ..._supportOptions.map(
          (opt) => OptionCard(
            label: opt.$2,
            selected: supportSystemStrength == opt.$1,
            onTap: () => onSupportChanged(opt.$1),
          ),
        ),
      ],
    );
  }
}
