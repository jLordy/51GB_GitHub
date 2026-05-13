import 'package:flutter/material.dart';
import 'package:frontend/features/dashboard/presentation/widgets/glassmorphic_container.dart';
import 'package:frontend/theme/palette.dart';
import 'package:go_router/go_router.dart';

/// Four shortcut buttons that navigate directly to the daily monitoring form.
///
/// Tapping any action calls [context.go('/monitoring')] so the monitoring
/// screen handles which section to focus — extend with a query param when
/// the monitoring screen supports deep-linking to a specific section.
class JournalQuickLog extends StatelessWidget {
  const JournalQuickLog({super.key});

  static const _actions = <({IconData icon, String label})>[
    (icon: Icons.monitor_heart_outlined, label: 'Vitals'),
    (icon: Icons.sick_outlined,          label: 'Symptoms'),
    (icon: Icons.restaurant_outlined,    label: 'Food'),
    (icon: Icons.mood_outlined,          label: 'Mood'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GlassmorphicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Quick Log',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: _actions.map((a) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/monitoring'),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: <Widget>[
                      // Icon pill
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Palette.greenColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Palette.greenColor.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Icon(a.icon, color: Palette.greenColor, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.label,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
