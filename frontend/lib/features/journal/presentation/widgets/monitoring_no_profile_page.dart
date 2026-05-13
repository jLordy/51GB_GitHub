import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown when the patient has no health profile yet. Prompts them to complete
/// onboarding before they can submit a journal entry.
class MonitoringNoProfilePage extends StatelessWidget {
  const MonitoringNoProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 26,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Image.asset(
                    'assets/images/agapay_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Welcome to AGAPAY!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Before Nurse Aga can check in with you, we need a few details about your health — it only takes a minute.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => context.push('/onboarding'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text(
                  'Set up my health profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
