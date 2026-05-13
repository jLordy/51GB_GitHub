import 'package:frontend/features/onboarding/presentation/widgets/multi_text_input.dart';
import 'package:frontend/features/onboarding/presentation/widgets/option_card.dart';
import 'package:flutter/material.dart';

/// Step 6 — allergy declaration and detail entry.
///
/// All three allergy lists and their add/remove callbacks are lifted to
/// [_OnboardingScreenState] because list mutations require [setState].
/// The three [TextEditingController]s are also owned and disposed by the
/// parent — they are passed down to keep this widget stateless.
class AllergiesStep extends StatelessWidget {
  const AllergiesStep({
    super.key,
    required this.hasAllergies,
    required this.onHasAllergiesChanged,
    required this.allergyMedications,
    required this.allergyFood,
    required this.allergyEnvironmental,
    required this.medController,
    required this.foodController,
    required this.envController,
    required this.onAddMed,
    required this.onRemoveMed,
    required this.onAddFood,
    required this.onRemoveFood,
    required this.onAddEnv,
    required this.onRemoveEnv,
  });

  final bool? hasAllergies;
  final void Function(bool value) onHasAllergiesChanged;
  // Read-only list views from parent state — do not mutate here.
  final List<String> allergyMedications;
  final List<String> allergyFood;
  final List<String> allergyEnvironmental;
  // Controllers owned and disposed by the parent.
  final TextEditingController medController;
  final TextEditingController foodController;
  final TextEditingController envController;
  final void Function(String) onAddMed;
  final void Function(int) onRemoveMed;
  final void Function(String) onAddFood;
  final void Function(int) onRemoveFood;
  final void Function(String) onAddEnv;
  final void Function(int) onRemoveEnv;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Allergies',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Do you have any known allergies?',
          style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        OptionCard(
          label: 'Yes',
          selected: hasAllergies == true,
          onTap: () => onHasAllergiesChanged(true),
        ),
        OptionCard(
          label: 'No',
          selected: hasAllergies == false,
          onTap: () => onHasAllergiesChanged(false),
        ),
        if (hasAllergies == true) ...[
          const SizedBox(height: 20),
          MultiTextInput(
            label: 'Medication Allergies',
            hint: 'e.g. Penicillin, Aspirin',
            items: allergyMedications,
            controller: medController,
            onAdd: onAddMed,
            onRemove: onRemoveMed,
          ),
          const SizedBox(height: 16),
          MultiTextInput(
            label: 'Food Allergies',
            hint: 'e.g. Peanuts, Shellfish',
            items: allergyFood,
            controller: foodController,
            onAdd: onAddFood,
            onRemove: onRemoveFood,
          ),
          const SizedBox(height: 16),
          MultiTextInput(
            label: 'Environmental Allergies',
            hint: 'e.g. Dust mites, Pollen',
            items: allergyEnvironmental,
            controller: envController,
            onAdd: onAddEnv,
            onRemove: onRemoveEnv,
          ),
        ],
      ],
    );
  }
}
