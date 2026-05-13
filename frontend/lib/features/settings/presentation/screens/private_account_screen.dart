import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// null = not yet overridden by user; widget falls back to currentUserProvider value.
final _privateAccountProvider = StateProvider<bool?>((ref) => null);

class PrivateAccountScreen extends ConsumerWidget {
  const PrivateAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = ref.watch(themeNotifierProvider).colorScheme;
    final serverValue = ref.watch(currentUserProvider)?.isPrivate ?? false;
    final isPrivate = ref.watch(_privateAccountProvider) ?? serverValue;

    Future<void> handleToggle(bool val) async {
      ref.read(_privateAccountProvider.notifier).state = val;
      try {
        await ref
            .read(backendSessionRepositoryProvider)
            .updateAccountSettings(isPrivate: val);
        if (context.mounted) {
          AppSnackBar.show(
            context,
            val ? 'Account set to private.' : 'Account set to public.',
          );
        }
      } catch (_) {
        ref.read(_privateAccountProvider.notifier).state = !val;
        if (context.mounted) {
          AppSnackBar.show(
            context,
            'Failed to update account settings.',
            type: SnackBarType.error,
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Private Account'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).cardTheme.color ??
                  scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              secondary: Icon(
                Icons.lock_person_outlined,
                color: scheme.onSurface,
              ),
              title: Text(
                'Private Account',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Make your account private and not public',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              value: isPrivate,
              activeThumbColor: scheme.primary,
              onChanged: handleToggle,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'When your account is private, only people you approve can see your '
              'posts and profile information. Your existing connections will not be '
              'affected.',
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
