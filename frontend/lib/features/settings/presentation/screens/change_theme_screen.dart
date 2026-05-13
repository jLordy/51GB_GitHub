import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangeThemeScreen extends ConsumerWidget {
  const ChangeThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = ref.watch(themeNotifierProvider);
    final ThemeNotifier notifier = ref.read(themeNotifierProvider.notifier);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = notifier.mode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Change Theme'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ThemeOptionCard(
                  label: 'Light Mode',
                  icon: Icons.light_mode_outlined,
                  isSelected: !isDark,
                  onTap: () {
                    if (isDark) notifier.toggleTheme();
                  },
                  scheme: scheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ThemeOptionCard(
                  label: 'Dark Mode',
                  icon: Icons.dark_mode_outlined,
                  isSelected: isDark,
                  onTap: () {
                    if (!isDark) notifier.toggleTheme();
                  },
                  scheme: scheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Your theme preference is saved and will persist across sessions.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : (Theme.of(context).cardTheme.color ??
                    scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.check_circle,
              size: 16,
              color: isSelected
                  ? scheme.onPrimaryContainer
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
