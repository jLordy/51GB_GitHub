import 'package:frontend/features/onboarding/presentation/widgets/option_card.dart';
import 'package:flutter/material.dart';

/// Step 5 — ethnicity selection.
///
/// [selected] and [onChanged] are lifted to the parent that owns
/// the [_ethnicity] state field.
class EthnicityStep extends StatelessWidget {
  const EthnicityStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final void Function(String value) onChanged;

  static const _options = [
    ('filipino', 'Filipino'),
    ('chinese', 'Chinese'),
    ('malay', 'Malay'),
    ('indian', 'Indian'),
    ('caucasian', 'Caucasian'),
    ('black_african', 'Black / African'),
    ('middle_eastern', 'Middle Eastern'),
    ('other', 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Ethnicity',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Some conditions have higher prevalence in certain ethnic groups.',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        ..._options.map(
          (opt) => OptionCard(
            label: opt.$2,
            selected: selected == opt.$1,
            onTap: () => onChanged(opt.$1),
          ),
        ),
      ],
    );
  }
}
