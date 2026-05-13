import 'package:frontend/features/onboarding/presentation/widgets/illness_card.dart';
import 'package:flutter/material.dart';

/// Step 1 — general health condition selection (multi-select).
///
/// Selecting "None / Apparently Well" clears all other picks.
/// Selecting any condition clears "None". An optional free-text
/// field captures conditions not in the list.
class IllnessTypeStep extends StatelessWidget {
  const IllnessTypeStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.otherController,
    required this.onOtherChanged,
  });

  final List<String> selected;
  final void Function(String value) onChanged;
  final TextEditingController otherController;
  final VoidCallback onOtherChanged;

  static const _illnesses = [
    Illness(
      value: 'hypertension',
      label: 'Hypertension',
      subtitle: 'High blood pressure (HPN)',
      icon: Icons.favorite_outline,
    ),
    Illness(
      value: 'diabetes',
      label: 'Diabetes Mellitus',
      subtitle: 'Type 1 or Type 2 (DM)',
      icon: Icons.bloodtype_outlined,
    ),
    Illness(
      value: 'heart_disease',
      label: 'Heart Disease',
      subtitle: 'Coronary artery disease, heart failure',
      icon: Icons.monitor_heart_outlined,
    ),
    Illness(
      value: 'asthma',
      label: 'Asthma / COPD',
      subtitle: 'Chronic respiratory condition',
      icon: Icons.air_outlined,
    ),
    Illness(
      value: 'tuberculosis',
      label: 'Tuberculosis',
      subtitle: 'PTB — active, completed treatment, or past',
      icon: Icons.coronavirus_outlined,
    ),
    Illness(
      value: 'cancer',
      label: 'Cancer',
      subtitle: 'Any type, during or after treatment',
      icon: Icons.science_outlined,
    ),
    Illness(
      value: 'ckd',
      label: 'Chronic Kidney Disease',
      subtitle: 'CKD — any stage',
      icon: Icons.water_drop_outlined,
    ),
    Illness(
      value: 'stroke',
      label: 'Stroke',
      subtitle: 'Cerebrovascular disease',
      icon: Icons.psychology_outlined,
    ),
    Illness(
      value: 'arthritis',
      label: 'Arthritis / Gout',
      subtitle: 'Joint or uric acid condition',
      icon: Icons.accessibility_new_outlined,
    ),
    Illness(
      value: 'mental_health',
      label: 'Mental Health Condition',
      subtitle: 'Depression, anxiety, and others',
      icon: Icons.self_improvement_outlined,
    ),
    Illness(
      value: 'none',
      label: 'None / Apparently Well',
      subtitle: 'No known chronic illness',
      icon: Icons.check_circle_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Do you have any known\nhealth conditions?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.3,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select all that apply. This helps Nurse Aga personalize your care.',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        ..._illnesses.map(
          (ill) => IllnessCard(
            illness: ill,
            selected: selected.contains(ill.value),
            onTap: () => onChanged(ill.value),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Other conditions (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: otherController,
          onChanged: (_) => onOtherChanged(),
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. Hepatitis B, Epilepsy, Thyroid disorder…',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.primary, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
