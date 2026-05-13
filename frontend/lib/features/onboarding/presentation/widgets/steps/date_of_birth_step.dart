import 'package:flutter/material.dart';

/// Step 2 — date of birth picker.
///
/// [dob] and [onChanged] are lifted to the parent that owns [_dob].
/// The async date-picker is triggered from within this StatelessWidget —
/// valid because [BuildContext] is captured synchronously before the await.
class DateOfBirthStep extends StatelessWidget {
  const DateOfBirthStep({
    super.key,
    required this.dob,
    required this.onChanged,
  });

  final DateTime? dob;
  final void Function(DateTime date) onChanged;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String? get _displayDob => dob != null
      ? '${_months[dob!.month - 1]} ${dob!.day}, ${dob!.year}'
      : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = _displayDob;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'When were you born?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your date of birth is used for age-appropriate health insights.',
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 40),
        Center(
          child: OutlinedButton.icon(
            icon: Icon(Icons.calendar_today_outlined, color: scheme.primary),
            label: Text(
              display ?? 'Select your date of birth',
              style: TextStyle(
                color: display != null
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: scheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dob ?? DateTime(1990),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(
                      ctx,
                    ).colorScheme.copyWith(primary: scheme.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onChanged(picked);
            },
          ),
        ),
      ],
    );
  }
}
