import 'package:flutter/material.dart';

/// Bottom navigation row shared by every onboarding step.
///
/// [canNext] is computed by the parent (which owns validation logic) and
/// passed down — this widget is purely responsible for layout and visual state.
class OnboardingNavBar extends StatelessWidget {
  const OnboardingNavBar({
    super.key,
    required this.canNext,
    required this.isFirst,
    required this.isLast,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final bool canNext;
  final bool isFirst;
  final bool isLast;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          if (!isFirst)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              label: Text(
                'Back',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                side: BorderSide(color: scheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          submitting
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                )
              : FilledButton(
                  onPressed: canNext ? (isLast ? onSubmit : onNext) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    disabledForegroundColor: scheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLast ? 'Finish setup' : 'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: canNext
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      if (!isLast) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: canNext
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ],
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
