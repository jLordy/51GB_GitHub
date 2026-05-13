import 'package:flutter/material.dart';

/// A reusable settings row with an icon, title, subtitle, and configurable
/// trailing widget (defaults to a chevron-right icon).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional override for the trailing widget. If provided, [showChevron]
  /// is ignored.
  final Widget? trailing;

  /// Whether to show the default chevron-right icon when [trailing] is null.
  final bool showChevron;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget? trailingWidget = trailing;
    if (trailingWidget == null && showChevron) {
      trailingWidget = Icon(
        Icons.chevron_right,
        color: scheme.onSurfaceVariant,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }
}
