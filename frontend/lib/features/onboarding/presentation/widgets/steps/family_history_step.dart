import 'package:flutter/material.dart';
import 'package:frontend/features/onboarding/presentation/widgets/option_card.dart';

/// Step 9 — family history of chronic illness.
///
/// If the user answers Yes, a multi-select checklist of common conditions
/// appears. [familyConditions] is the list of selected condition keys and
/// is lifted to the parent screen.
class FamilyHistoryStep extends StatelessWidget {
  const FamilyHistoryStep({
    super.key,
    required this.hasFamilyHistory,
    required this.onHasFamilyHistoryChanged,
    required this.familyConditions,
    required this.onConditionToggled,
  });

  final bool? hasFamilyHistory;
  final void Function(bool value) onHasFamilyHistoryChanged;
  final List<String> familyConditions;
  final void Function(String key) onConditionToggled;

  static const _conditions = [
    ('hypertension', 'Hypertension / High Blood Pressure'),
    ('diabetes', 'Diabetes'),
    ('heart_disease', 'Heart Disease'),
    ('cancer', 'Cancer'),
    ('kidney_disease', 'Kidney Disease'),
    ('stroke', 'Stroke'),
    ('asthma', 'Asthma / Respiratory Illness'),
    ('mental_health', 'Mental Health Condition'),
    ('tuberculosis', 'Tuberculosis (PTB)'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Family History',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Does anyone in your immediate family (parents, siblings, grandparents) have a history of a chronic illness?',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        OptionCard(
          label: 'Yes',
          selected: hasFamilyHistory == true,
          onTap: () => onHasFamilyHistoryChanged(true),
        ),
        OptionCard(
          label: 'No',
          selected: hasFamilyHistory == false,
          onTap: () => onHasFamilyHistoryChanged(false),
        ),
        if (hasFamilyHistory == true) ...[
          const SizedBox(height: 20),
          Text(
            'Which conditions? (select all that apply)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ..._conditions.map(
            (cond) => _ConditionCheckRow(
              label: cond.$2,
              selected: familyConditions.contains(cond.$1),
              onTap: () => onConditionToggled(cond.$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConditionCheckRow extends StatelessWidget {
  const _ConditionCheckRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1.0 : 0.0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
