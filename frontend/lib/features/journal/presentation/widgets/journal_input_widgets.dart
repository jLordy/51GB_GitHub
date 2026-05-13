import 'package:frontend/features/journal/model/question_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Private helpers ───────────────────────────────────────────────────────────

OutlineInputBorder _accentBorder(ColorScheme scheme, [double width = 1.4]) =>
    OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: scheme.primary, width: width),
    );

Color _surfaceCard(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.surfaceContainerLow
      : theme.colorScheme.surfaceContainerLowest;
}

String _formatStoredDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    const months = [
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return isoDate;
  }
}

// ── Input dispatcher ──────────────────────────────────────────────────────────

/// Routes a [Question] to the correct input widget based on [question.uiComponent].
///
/// All input widgets are stateless and communicate back via [onAnswerChanged].
/// Controller lifecycle is owned by the parent; [getController] returns the
/// correct [TextEditingController] for controller-based inputs.
class JournalInputDispatcher extends StatelessWidget {
  const JournalInputDispatcher({
    super.key,
    required this.question,
    required this.answers,
    required this.getController,
    required this.onAnswerChanged,
  });

  final Question question;
  final Map<String, dynamic> answers;
  final TextEditingController Function(String key, {String seed}) getController;
  final void Function(String key, dynamic value) onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    return switch (question.uiComponent) {
      'slider' => _buildSlider(),
      'bp_input' => _buildBp(),
      'number_input' => _buildNumber(),
      'weight_input' => _buildWeight(),
      'radio' => _buildRadio(),
      'chip_selector' => _buildChips(),
      'multi_text_input' => _buildMultiText(),
      'toggle' => _buildToggle(),
      'date_picker' => _buildDate(),
      'select' => _buildSelect(),
      _ => _buildNumber(),
    };
  }

  Widget _buildSlider() {
    final mn = question.validation?.min ?? 1.0;
    final mx = question.validation?.max ?? 5.0;
    final stp = question.validation?.step ?? 1.0;
    final val = (answers[question.id] as double?) ?? mn;
    // Seed the default so "untouched" sliders still submit a value.
    if (answers[question.id] == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onAnswerChanged(question.id, val),
      );
    }
    return JournalSliderInput(
      min: mn,
      max: mx,
      step: stp,
      value: val,
      onChanged: (v) => onAnswerChanged(question.id, v),
    );
  }

  Widget _buildBp() {
    final existing = answers[question.id] as Map<String, dynamic>?;
    final sysCtrl = getController(
      '${question.id}_systolic',
      seed: existing?['systolic'] != null ? '${existing!['systolic']}' : '',
    );
    final diaCtrl = getController(
      '${question.id}_diastolic',
      seed: existing?['diastolic'] != null ? '${existing!['diastolic']}' : '',
    );
    return JournalBpInput(
      sysCtrl: sysCtrl,
      diaCtrl: diaCtrl,
      onAnswerChanged: (sys, dia) =>
          onAnswerChanged(question.id, {'systolic': sys, 'diastolic': dia}),
    );
  }

  Widget _buildNumber() {
    final existing = answers[question.id];
    final ctrl = getController(
      question.id,
      seed: existing != null ? '$existing' : '',
    );
    return JournalNumberInput(
      ctrl: ctrl,
      unit: question.validation?.unit,
      onChanged: (v) => onAnswerChanged(question.id, v),
    );
  }

  Widget _buildWeight() {
    final existing = answers[question.id] as Map<String, dynamic>?;
    final unit = existing?['unit'] as String? ?? 'kg';
    final ctrl = getController(
      question.id,
      seed: existing?['value'] != null ? '${existing!['value']}' : '',
    );
    return JournalWeightInput(
      ctrl: ctrl,
      unit: unit,
      onAnswerChanged: (value, u) =>
          onAnswerChanged(question.id, {'value': value, 'unit': u}),
    );
  }

  Widget _buildRadio() {
    final selected = answers[question.id] as String?;
    return JournalRadioInput(
      options: question.options ?? const [],
      selected: selected,
      onChanged: (v) => onAnswerChanged(question.id, v),
    );
  }

  Widget _buildChips() {
    final selectedSet =
        ((answers[question.id] as List<dynamic>?) ?? <dynamic>[])
            .map((e) => e.toString())
            .toSet();
    return JournalChipSelector(
      options: question.options ?? const [],
      selectedSet: selectedSet,
      onChanged: (list) => onAnswerChanged(question.id, list),
    );
  }

  Widget _buildMultiText() {
    final draftCtrl = getController('${question.id}_draft');
    final existing = ((answers[question.id] as List<dynamic>?) ?? <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return JournalMultiTextInput(
      ctrl: draftCtrl,
      values: existing,
      onChanged: (list) => onAnswerChanged(question.id, list),
    );
  }

  Widget _buildToggle() {
    final val = answers[question.id] as bool? ?? false;
    return JournalToggleInput(
      value: val,
      onChanged: (v) => onAnswerChanged(question.id, v),
    );
  }

  Widget _buildDate() {
    final stored = answers[question.id] as String?;
    return JournalDateInput(
      stored: stored,
      onDateSelected: (iso) => onAnswerChanged(question.id, iso),
    );
  }

  Widget _buildSelect() {
    final selected = answers[question.id] as String?;
    return JournalSelectInput(
      options: question.options ?? const [],
      selected: selected,
      onChanged: (v) => onAnswerChanged(question.id, v),
    );
  }
}

// ── Slider ────────────────────────────────────────────────────────────────────

class JournalSliderInput extends StatelessWidget {
  const JournalSliderInput({
    super.key,
    required this.min,
    required this.max,
    required this.step,
    required this.value,
    required this.onChanged,
  });

  final double min;
  final double max;
  final double step;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    return Column(
      children: [
        Text(
          '${value.toInt()}',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: scheme.primary,
          ),
        ),
        Slider(
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          value: value,
          activeColor: scheme.primary,
          inactiveColor: scheme.outlineVariant.withValues(alpha: 0.45),
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.toInt()}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              Text(
                '${max.toInt()}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Blood pressure ────────────────────────────────────────────────────────────

class JournalBpInput extends StatelessWidget {
  const JournalBpInput({
    super.key,
    required this.sysCtrl,
    required this.diaCtrl,
    required this.onAnswerChanged,
  });

  final TextEditingController sysCtrl;
  final TextEditingController diaCtrl;
  final void Function(int systolic, int diastolic) onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final card = _surfaceCard(context);
    final border = _accentBorder(scheme);

    void update() {
      final sys = int.tryParse(sysCtrl.text);
      final dia = int.tryParse(diaCtrl.text);
      if (sys != null && dia != null) onAnswerChanged(sys, dia);
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: sysCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: '120',
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                fontSize: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              enabledBorder: border,
              focusedBorder: border,
              border: border,
              filled: true,
              fillColor: card,
            ),
            onChanged: (_) => update(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '/',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: diaCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: '80',
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                fontSize: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              enabledBorder: border,
              focusedBorder: border,
              border: border,
              filled: true,
              fillColor: card,
            ),
            onChanged: (_) => update(),
          ),
        ),
      ],
    );
  }
}

// ── Generic number field ──────────────────────────────────────────────────────

class JournalNumberInput extends StatelessWidget {
  const JournalNumberInput({
    super.key,
    required this.ctrl,
    required this.onChanged,
    this.unit,
  });

  final TextEditingController ctrl;
  final String? unit;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final border = _accentBorder(scheme);

    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontSize: 18, color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Enter value',
        suffixText: unit,
        enabledBorder: border,
        focusedBorder: border,
        border: border,
        filled: true,
        fillColor: _surfaceCard(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      onChanged: (v) => onChanged(double.tryParse(v)),
    );
  }
}

// ── Weight field with kg / lb toggle ─────────────────────────────────────────

class JournalWeightInput extends StatelessWidget {
  const JournalWeightInput({
    super.key,
    required this.ctrl,
    required this.unit,
    required this.onAnswerChanged,
  });

  final TextEditingController ctrl;
  final String unit;
  final void Function(double? value, String unit) onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final card = _surfaceCard(context);
    final border = _accentBorder(scheme);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 18, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: '0.0',
              enabledBorder: border,
              focusedBorder: border,
              border: border,
              filled: true,
              fillColor: card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            onChanged: (v) => onAnswerChanged(double.tryParse(v), unit),
          ),
        ),
        const SizedBox(width: 12),
        // kg / lb toggle
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.primary, width: 1.4),
            borderRadius: BorderRadius.circular(16),
            color: card,
          ),
          child: Row(
            children: ['kg', 'lb'].map((u) {
              final isSelected = unit == u;
              return GestureDetector(
                onTap: () {
                  final parsed = double.tryParse(ctrl.text);
                  onAnswerChanged(parsed, u);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    u,
                    style: TextStyle(
                      color: isSelected ? scheme.onPrimary : scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Radio options ─────────────────────────────────────────────────────────────

class JournalRadioInput extends StatelessWidget {
  const JournalRadioInput({
    super.key,
    required this.options,
    required this.onChanged,
    this.selected,
  });

  final List<QuestionOption> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final card = _surfaceCard(context);

    return Column(
      children: options.map((opt) {
        final isSelected = selected == opt.value;
        return GestureDetector(
          onTap: () => onChanged(opt.value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : card,
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: isSelected ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    color: isSelected ? scheme.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    opt.label,
                    style: TextStyle(fontSize: 15, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Multi-select chips ────────────────────────────────────────────────────────

class JournalChipSelector extends StatelessWidget {
  const JournalChipSelector({
    super.key,
    required this.options,
    required this.selectedSet,
    required this.onChanged,
  });

  final List<QuestionOption> options;
  final Set<String> selectedSet;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final card = _surfaceCard(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selectedSet.contains(opt.value);
        return FilterChip(
          label: Text(opt.label),
          selected: isSelected,
          selectedColor: scheme.primaryContainer.withValues(alpha: 0.35),
          checkmarkColor: scheme.primary,
          side: BorderSide(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (val) {
            final newSet = Set<String>.from(selectedSet);
            val ? newSet.add(opt.value) : newSet.remove(opt.value);
            onChanged(newSet.toList());
          },
        );
      }).toList(),
    );
  }
}

// ── Multi text input (list[str]) ─────────────────────────────────────────────

class JournalMultiTextInput extends StatelessWidget {
  const JournalMultiTextInput({
    super.key,
    required this.ctrl,
    required this.values,
    required this.onChanged,
  });

  final TextEditingController ctrl;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final border = _accentBorder(scheme);

    void addEntry() {
      final text = ctrl.text.trim();
      if (text.isEmpty) return;
      final next = List<String>.from(values);
      if (!next.contains(text)) {
        next.add(text);
        onChanged(next);
      }
      ctrl.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Type and tap Add',
                  enabledBorder: border,
                  focusedBorder: border,
                  border: border,
                  filled: true,
                  fillColor: _surfaceCard(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => addEntry(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: addEntry,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (values.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((entry) {
              return Chip(
                label: Text(entry),
                onDeleted: () {
                  final next = List<String>.from(values)..remove(entry);
                  onChanged(next);
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Boolean toggle ────────────────────────────────────────────────────────────

class JournalToggleInput extends StatelessWidget {
  const JournalToggleInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceCard(context),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ? 'Yes' : 'No',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: scheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Date picker button ────────────────────────────────────────────────────────

class JournalDateInput extends StatelessWidget {
  const JournalDateInput({
    super.key,
    required this.onDateSelected,
    this.stored,
  });

  final String? stored;
  final ValueChanged<String> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final theme = Theme.of(context);
    final display = stored != null ? _formatStoredDate(stored!) : 'Select date';

    return OutlinedButton.icon(
      icon: Icon(Icons.calendar_today_outlined, color: scheme.primary),
      label: Text(display, style: TextStyle(color: scheme.onSurface)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        side: BorderSide(color: scheme.primary),
        backgroundColor: _surfaceCard(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: theme.copyWith(colorScheme: scheme),
            child: child!,
          ),
        );
        if (picked != null && context.mounted) {
          onDateSelected(
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
          );
        }
      },
    );
  }
}

// ── Dropdown select ───────────────────────────────────────────────────────────

class JournalSelectInput extends StatelessWidget {
  const JournalSelectInput({
    super.key,
    required this.options,
    required this.onChanged,
    this.selected,
  });

  final List<QuestionOption> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final border = _accentBorder(scheme);

    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: border,
        enabledBorder: border,
        filled: true,
        fillColor: _surfaceCard(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      hint: Text(
        'Select an option',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      items: options.map((opt) {
        return DropdownMenuItem(value: opt.value, child: Text(opt.label));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
