import 'package:flutter/material.dart';

/// Step-progress indicator displayed at the top of the onboarding wizard.
///
/// Renders a row of segmented pill segments — filled for completed/current
/// steps, muted for upcoming — and a small "Step X of Y" label below.
/// All colours are resolved from the active [ColorScheme] so the widget
/// adapts to both light and dark themes automatically.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(totalSteps, (i) {
              final filled = i < currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'Step $currentStep of $totalSteps',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
