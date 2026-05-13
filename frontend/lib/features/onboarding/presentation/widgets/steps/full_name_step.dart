import 'package:flutter/material.dart';

/// Step 3 — full name entry.
///
/// [controller] is owned and disposed by [_OnboardingScreenState]; passing
/// it down avoids duplicating state while keeping this widget stateless.
/// [onChanged] notifies the parent to re-evaluate the "canNext" guard and
/// clear any lingering error message.
class FullNameStep extends StatelessWidget {
  const FullNameStep({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  // Owned by parent — do NOT dispose here.
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          "What's your name?",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nurse Aga will use this to greet you.',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 18, color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Full name',
            hintStyle: TextStyle(color: scheme.onSurfaceVariant),
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.primary, width: 1.6),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
