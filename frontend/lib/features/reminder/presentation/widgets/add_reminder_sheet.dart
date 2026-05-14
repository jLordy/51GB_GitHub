import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/reminder/controller/reminder_controller.dart';
import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_frequency.dart';
import 'package:frontend/theme/palette.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showAddReminderSheet(
  BuildContext context, {
  MedicationReminder? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddReminderSheet(existing: existing),
  );
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet({this.existing});
  final MedicationReminder? existing;

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _medNameCtrl;
  late final TextEditingController _dosageCtrl;

  late DateTime _scheduledTime;
  late ReminderFrequency _frequency;
  late bool _isAlarmEnabled;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _medNameCtrl = TextEditingController(text: e?.medName ?? '');
    _dosageCtrl = TextEditingController(text: e?.dosage ?? '');
    _scheduledTime = e?.scheduledTime ?? _defaultTime();
    _frequency = e?.frequency ?? ReminderFrequency.daily;
    _isAlarmEnabled = e?.isAlarmEnabled ?? true;
  }

  @override
  void dispose() {
    _medNameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  DateTime _defaultTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 8, 0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _scheduledTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
    );
    if (picked == null) return;
    setState(() {
      _scheduledTime = DateTime(
        _scheduledTime.year,
        _scheduledTime.month,
        _scheduledTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final controller = ref.read(reminderControllerProvider.notifier);
    if (_isEditing) {
      await controller.update(widget.existing!.copyWith(
        medName: _medNameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        scheduledTime: _scheduledTime,
        frequency: _frequency,
        isAlarmEnabled: _isAlarmEnabled,
      ));
    } else {
      await controller.add(MedicationReminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        medName: _medNameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        scheduledTime: _scheduledTime,
        frequency: _frequency,
        isAlarmEnabled: _isAlarmEnabled,
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? Palette.darkSurfaceContainerColor : Colors.white;
    final textDark =
        isDark ? Palette.darkOnSurfaceColor : const Color(0xFF1A1A2E);
    final textMid = isDark
        ? Palette.darkOnSurfaceVariantColor
        : const Color(0xFF6B7280);
    final inputFill =
        isDark ? Palette.darkInputSurfaceColor : const Color(0xFFF5F9F7);
    final border =
        isDark ? Palette.darkOutlineColor : const Color(0xFFE5E7EB);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _isEditing ? 'Edit Reminder' : 'Add Reminder',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 20),

                // Medication name
                _FieldLabel('Medication name', textMid),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _medNameCtrl,
                  style: GoogleFonts.inter(fontSize: 14, color: textDark),
                  decoration: _inputDeco(
                      'e.g. Metformin', inputFill, border, textMid),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Dosage
                _FieldLabel('Dosage', textMid),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _dosageCtrl,
                  style: GoogleFonts.inter(fontSize: 14, color: textDark),
                  decoration:
                      _inputDeco('e.g. 500mg', inputFill, border, textMid),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Date + Time row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Date', textMid),
                          const SizedBox(height: 6),
                          _PickerTile(
                            icon: Icons.calendar_today_rounded,
                            label: _formatDate(_scheduledTime),
                            inputFill: inputFill,
                            border: border,
                            textDark: textDark,
                            onTap: _pickDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Time', textMid),
                          const SizedBox(height: 6),
                          _PickerTile(
                            icon: Icons.access_time_rounded,
                            label: _formatTime(_scheduledTime),
                            inputFill: inputFill,
                            border: border,
                            textDark: textDark,
                            onTap: _pickTime,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Frequency chips
                _FieldLabel('Frequency', textMid),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReminderFrequency.values.map((f) {
                    final selected = _frequency == f;
                    return GestureDetector(
                      onTap: () => setState(() => _frequency = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? Palette.greenColor : inputFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? Palette.greenColor : border,
                          ),
                        ),
                        child: Text(
                          f.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : textMid,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Alarm toggle row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAlarmEnabled
                            ? Icons.alarm_rounded
                            : Icons.alarm_off_rounded,
                        color: _isAlarmEnabled ? Palette.greenColor : textMid,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alarm',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                            Text(
                              "Get notified when it's time",
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: textMid),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAlarmEnabled,
                        onChanged: (v) => setState(() => _isAlarmEnabled = v),
                        activeThumbColor: Palette.greenColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.greenColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Palette.greenColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save changes' : 'Add reminder',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(
      String hint, Color fill, Color border, Color hintColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: hintColor),
      filled: true,
      fillColor: fill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Palette.greenColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.errorColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.errorColor),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.inputFill,
    required this.border,
    required this.textDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color inputFill;
  final Color border;
  final Color textDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Palette.greenColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
