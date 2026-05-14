import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shown once to users who signed in via Google (or another OAuth provider)
/// and whose Firestore role is still "pending". They pick their role here and
/// are then redirected to the main app.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isSubmitting = false;

  static const _roles = [
    _RoleOption(
      value: 'patient',
      label: 'Patient',
      description: 'I am receiving care and want to track my health.',
      icon: Icons.personal_injury_outlined,
    ),
    _RoleOption(
      value: 'doctor',
      label: 'Doctor',
      description: 'I am a licensed physician monitoring patients.',
      icon: Icons.medical_services_outlined,
    ),
  ];

  Future<void> _submit() async {
    final role = _selectedRole;
    if (role == null) {
      AppSnackBar.show(
        context,
        'Please select your role before continuing.',
        type: SnackBarType.error,
      );
      return;
    }

    // Find the label for the selected role.
    final roleOption = _roles.firstWhere((r) => r.value == role);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm your role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to join as a ${roleOption.label}.',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This cannot be changed later.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(backendSessionRepositoryProvider);
      final updatedUser = await repo.selectRole(role);

      // Push the new role into the global user state so the router guard
      // immediately sees the change and redirects away from this screen.
      ref.read(currentUserProvider.notifier).state = updatedUser;
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'Could not save your role. Please try again.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final signedInLanding = kIsWeb ? '/home' : '/community';

    // If role was set successfully (state updated), the router redirect will
    // navigate away automatically. But also imperatively navigate as a fallback.
    ref.listen(currentUserProvider, (_, user) {
      final role = user?.role.toLowerCase();
      if (role != null && role != 'pending' && mounted) {
        // New patients go straight to onboarding so they fill their health
        // profile before accessing any feature — avoids the jarring error UX.
        if (role == 'patient') {
          context.go('/onboarding');
        } else {
          context.go(signedInLanding);
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Icon(
                    Icons.health_and_safety_outlined,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Who are you?',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the role that best describes you. This helps us personalise your experience.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ..._roles.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RoleCard(
                        option: option,
                        isSelected: _selectedRole == option.value,
                        onTap: () =>
                            setState(() => _selectedRole = option.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _RoleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? colorScheme.primaryContainer.withAlpha(120)
              : colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 28,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}
