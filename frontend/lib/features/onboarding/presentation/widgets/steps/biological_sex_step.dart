import 'package:frontend/features/onboarding/presentation/widgets/option_card.dart';
import 'package:flutter/material.dart';

/// Step 4 — biological sex selection.
///
/// [selected] and [onChanged] are lifted to the parent that owns
/// the [_biologicalSex] state field.
class BiologicalSexStep extends StatelessWidget {
  const BiologicalSexStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final void Function(String value) onChanged;

  static const _options = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('intersex', 'Intersex'),
    ('prefer_not_say', 'Prefer not to say'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Biological sex',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Used for clinically relevant health insights.',
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
