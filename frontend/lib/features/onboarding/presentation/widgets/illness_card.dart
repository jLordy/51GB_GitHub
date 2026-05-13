import 'package:flutter/material.dart';

/// Data model for a chronic-illness option shown during onboarding step 1.
class Illness {
  const Illness({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
}

/// Selectable card representing a single [Illness].
/// [selected] drives the highlight; [onTap] is lifted to the parent
/// that owns the [illnessType] state field.
class IllnessCard extends StatelessWidget {
  const IllnessCard({
    super.key,
    required this.illness,
    required this.selected,
    required this.onTap,
  });

  final Illness illness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.8 : 1.0,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.14)
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    illness.icon,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        illness.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        illness.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.75)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1.0 : 0.0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
