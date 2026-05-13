import 'package:frontend/core/widgets/bottom_navbar.dart';
import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/core/widgets/left_sidebar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/calendar/controller/calendar_provider.dart';
import 'package:frontend/features/calendar/model/appointment_model.dart';
import 'package:frontend/features/calendar/presentation/widgets/appointment_list.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

class DoctorCalendarScreen extends ConsumerWidget {
  const DoctorCalendarScreen({super.key});

  Future<void> _openAddAppointmentSheet(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDay, {
    bool secretaryMode = false,
  }) async {
    ref.read(calendarMutationControllerProvider.notifier).clearState();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAppointmentSheet(
        initialDate: selectedDay,
        secretaryMode: secretaryMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final selectedDay = ref.watch(selectedCalendarDateProvider);
    final focusedDay = ref.watch(focusedCalendarDateProvider);
    final role = ref.watch(currentUserProvider)?.role.toLowerCase() ?? '';
    final bool isCaregiverRole = role == 'caregiver';
    final bool isSecretaryRole = role == 'secretary';
    final appointmentsAsync = isCaregiverRole
        ? ref.watch(caregiverAppointmentsBySelectedDateProvider)
        : isSecretaryRole
        ? ref.watch(secretaryAppointmentsBySelectedDateProvider)
        : ref.watch(appointmentsBySelectedDateProvider);

    final bool isWide = MediaQuery.of(context).size.width >= 900;

    if (authUser == null || authUser.isAnonymous) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      drawer: isWide ? null : const LeftSidebar(),
      appBar: AppBar(
        title: Text(
          'Calendar',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu_rounded, color: scheme.onSurface),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        actions: <Widget>[
          if (!isCaregiverRole)
            IconButton(
              tooltip: 'Add appointment',
              icon: Icon(Icons.add_rounded, color: scheme.onSurface),
              onPressed: () => _openAddAppointmentSheet(
                context,
                ref,
                selectedDay,
                secretaryMode: isSecretaryRole,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavbar(
              selectedIndex: -1,
              onHomeTap: () => context.go('/community'),
              onJournalTap: () => context.go('/journal'),
              onNotificationsTap: () => context.go('/notifications'),
            ),
      body: isWide
          ? Row(
              children: <Widget>[
                _CalendarRail(theme: theme),
                Expanded(
                  child: _CalendarContent(
                    selectedDay: selectedDay,
                    focusedDay: focusedDay,
                    appointmentsAsync: appointmentsAsync,
                    isCaregiverRole: isCaregiverRole,
                    isSecretaryRole: isSecretaryRole,
                  ),
                ),
              ],
            )
          : _CalendarContent(
              selectedDay: selectedDay,
              focusedDay: focusedDay,
              appointmentsAsync: appointmentsAsync,
              isCaregiverRole: isCaregiverRole,
              isSecretaryRole: isSecretaryRole,
            ),
    );
  }
}

class _AddAppointmentSheet extends ConsumerStatefulWidget {
  const _AddAppointmentSheet({
    required this.initialDate,
    this.secretaryMode = false,
    this.existingAppointment,
  });

  final DateTime initialDate;
  final bool secretaryMode;
  final AppointmentModel? existingAppointment;

  @override
  ConsumerState<_AddAppointmentSheet> createState() =>
      _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends ConsumerState<_AddAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _clinicNameController = TextEditingController();
  final _clinicPlaceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  UserModel? _selectedDoctor;
  UserModel? _selectedPatient;
  bool _isSpecialAppointment = false;
  bool _patientPreselected = false;
  bool _doctorPreselected = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAppointment;
    if (existing != null) {
      _isSpecialAppointment = existing.type == AppointmentType.special;
      _clinicNameController.text = existing.clinicName ?? '';
      _clinicPlaceController.text = existing.clinicPlace ?? '';
      _reasonController.text = existing.reason ?? '';
      _notesController.text = existing.notes ?? '';
      _startTime = _parseTime(existing.startTime);
      if (existing.endTime != null && existing.endTime!.isNotEmpty) {
        _endTime = _parseTime(existing.endTime!);
      }
    }
  }

  static TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String suffix = parts[1].toUpperCase();
      if (suffix == 'PM' && hour != 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _clinicPlaceController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 9, minute: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.secretaryMode &&
        _selectedDoctor == null &&
        widget.existingAppointment == null) {
      AppSnackBar.show(
        context,
        'Please select a doctor.',
        type: SnackBarType.error,
      );
      return;
    }
    if (!_isSpecialAppointment && _selectedPatient == null) {
      AppSnackBar.show(
        context,
        'Please select a patient.',
        type: SnackBarType.error,
      );
      return;
    }
    if (_startTime == null) {
      AppSnackBar.show(
        context,
        'Please choose a start time.',
        type: SnackBarType.error,
      );
      return;
    }

    final startLabel = _formatTime(_startTime!);
    final endLabel = _endTime == null ? null : _formatTime(_endTime!);

    final isEditing = widget.existingAppointment != null;
    if (widget.secretaryMode) {
      if (isEditing) {
        await ref
            .read(calendarMutationControllerProvider.notifier)
            .updateAppointmentAsSecretary(
              appointmentId: widget.existingAppointment!.appointmentId,
              patientUid: _isSpecialAppointment ? null : _selectedPatient?.uid,
              appointmentDate: widget.initialDate,
              startTime: startLabel,
              endTime: endLabel,
              type: _isSpecialAppointment
                  ? AppointmentType.special
                  : AppointmentType.patient,
              clinicName: _clinicNameController.text.trim().isEmpty
                  ? null
                  : _clinicNameController.text.trim(),
              clinicPlace: _clinicPlaceController.text.trim().isEmpty
                  ? null
                  : _clinicPlaceController.text.trim(),
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
      } else {
        await ref
            .read(calendarMutationControllerProvider.notifier)
            .createAppointmentAsSecretary(
              doctorUid: _selectedDoctor!.uid,
              patientUid: _isSpecialAppointment ? null : _selectedPatient!.uid,
              appointmentDate: widget.initialDate,
              startTime: startLabel,
              endTime: endLabel,
              type: _isSpecialAppointment
                  ? AppointmentType.special
                  : AppointmentType.patient,
              clinicName: _clinicNameController.text.trim().isEmpty
                  ? null
                  : _clinicNameController.text.trim(),
              clinicPlace: _clinicPlaceController.text.trim().isEmpty
                  ? null
                  : _clinicPlaceController.text.trim(),
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
      }
    } else {
      if (isEditing) {
        await ref
            .read(calendarMutationControllerProvider.notifier)
            .updateAppointment(
              appointmentId: widget.existingAppointment!.appointmentId,
              patientUid: _isSpecialAppointment ? null : _selectedPatient?.uid,
              appointmentDate: widget.initialDate,
              startTime: startLabel,
              endTime: endLabel,
              type: _isSpecialAppointment
                  ? AppointmentType.special
                  : AppointmentType.patient,
              clinicName: _clinicNameController.text.trim().isEmpty
                  ? null
                  : _clinicNameController.text.trim(),
              clinicPlace: _clinicPlaceController.text.trim().isEmpty
                  ? null
                  : _clinicPlaceController.text.trim(),
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
      } else {
        await ref
            .read(calendarMutationControllerProvider.notifier)
            .createAppointment(
              patientUid: _isSpecialAppointment ? null : _selectedPatient!.uid,
              appointmentDate: widget.initialDate,
              startTime: startLabel,
              endTime: endLabel,
              type: _isSpecialAppointment
                  ? AppointmentType.special
                  : AppointmentType.patient,
              clinicName: _clinicNameController.text.trim().isEmpty
                  ? null
                  : _clinicNameController.text.trim(),
              clinicPlace: _clinicPlaceController.text.trim().isEmpty
                  ? null
                  : _clinicPlaceController.text.trim(),
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
      }
    }

    final mutationState = ref.read(calendarMutationControllerProvider);
    if (mutationState.hasError) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        isEditing
            ? 'Failed to update appointment.'
            : 'Failed to add appointment.',
        type: SnackBarType.error,
      );
      return;
    }

    if (widget.secretaryMode) {
      ref.invalidate(secretaryAppointmentsBySelectedDateProvider);
    } else {
      ref.invalidate(appointmentsBySelectedDateProvider);
    }
    ref.read(calendarMutationControllerProvider.notifier).clearState();
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackBar.show(
      context,
      isEditing ? 'Appointment updated.' : 'Appointment added.',
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeNotifierProvider);
    final scheme = theme.colorScheme;
    final patientsAsync = widget.secretaryMode
        ? ref.watch(patientsForDoctorProvider(_selectedDoctor?.uid ?? ''))
        : ref.watch(connectedCalendarPatientsProvider);
    final mutationState = ref.watch(calendarMutationControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existingAppointment != null
                  ? 'Edit appointment'
                  : 'Add appointment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _prettyDate(widget.initialDate),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (widget.secretaryMode) ...<Widget>[
              Consumer(
                builder: (context, ref, _) {
                  final doctorsAsync = ref.watch(
                    connectedCalendarDoctorsProvider,
                  );
                  return doctorsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Could not load connected doctors.',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                    data: (doctors) {
                      if (widget.existingAppointment != null &&
                          !_doctorPreselected &&
                          doctors.isNotEmpty) {
                        _doctorPreselected = true;
                        final uid = widget.existingAppointment!.doctorUid;
                        final matches = doctors.where((d) => d.uid == uid);
                        final match = matches.isEmpty ? null : matches.first;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && match != null) {
                            setState(() => _selectedDoctor = match);
                          }
                        });
                      } else if (widget.existingAppointment == null &&
                          !_doctorPreselected &&
                          doctors.isNotEmpty) {
                        _doctorPreselected = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedDoctor == null) {
                            setState(() => _selectedDoctor = doctors.first);
                          }
                        });
                      }
                      return DropdownButtonFormField<UserModel>(
                        initialValue: _selectedDoctor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Doctor',
                          border: OutlineInputBorder(),
                        ),
                        items: doctors
                            .map(
                              (d) => DropdownMenuItem<UserModel>(
                                value: d,
                                child: Text(
                                  d.displayName ?? d.email ?? d.uid,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: mutationState.isLoading
                            ? null
                            : (value) => setState(() {
                                _selectedDoctor = value;
                                _selectedPatient = null;
                              }),
                        validator: (value) =>
                            value == null ? 'Please select a doctor' : null,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isSpecialAppointment,
              onChanged: mutationState.isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _isSpecialAppointment = value;
                        if (value) {
                          _selectedPatient = null;
                        }
                      });
                    },
              title: const Text('Special appointment'),
              subtitle: Text(
                'Use this for meetings, reminders, or doctor-only events.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            patientsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Could not load connected patients.',
                  style: TextStyle(color: scheme.error),
                ),
              ),
              data: (patients) {
                if (widget.existingAppointment != null &&
                    !_patientPreselected &&
                    patients.isNotEmpty &&
                    !_isSpecialAppointment) {
                  _patientPreselected = true;
                  final uid = widget.existingAppointment!.patientUid;
                  if (uid != null) {
                    final matches = patients.where((p) => p.uid == uid);
                    final match = matches.isEmpty ? null : matches.first;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && match != null) {
                        setState(() => _selectedPatient = match);
                      }
                    });
                  }
                }
                if (patients.isEmpty) {
                  if (_isSpecialAppointment) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      widget.secretaryMode && _selectedDoctor == null
                          ? 'Select a doctor first to load patients.'
                          : 'No connected patients found.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                if (_isSpecialAppointment) {
                  return const SizedBox.shrink();
                }
                return DropdownButtonFormField<UserModel>(
                  initialValue: _selectedPatient,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Patient',
                    border: OutlineInputBorder(),
                  ),
                  items: patients
                      .map(
                        (patient) => DropdownMenuItem<UserModel>(
                          value: patient,
                          child: Text(
                            patient.displayName ?? patient.email ?? patient.uid,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: mutationState.isLoading
                      ? null
                      : (value) => setState(() => _selectedPatient = value),
                  validator: (value) =>
                      value == null ? 'Please select a patient' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicNameController,
              enabled: !mutationState.isLoading,
              decoration: const InputDecoration(
                labelText: 'Clinic name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicPlaceController,
              enabled: !mutationState.isLoading,
              decoration: const InputDecoration(
                labelText: 'Clinic place',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              enabled: !mutationState.isLoading,
              decoration: InputDecoration(
                labelText: _isSpecialAppointment ? 'Event title' : 'Reason',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _isSpecialAppointment
                      ? 'Event title is required'
                      : 'Reason is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TimeField(
                    label: 'Start time',
                    value: _startTime == null ? null : _formatTime(_startTime!),
                    onTap: mutationState.isLoading
                        ? null
                        : () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'End time',
                    value: _endTime == null ? null : _formatTime(_endTime!),
                    onTap: mutationState.isLoading
                        ? null
                        : () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              enabled: !mutationState.isLoading,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: mutationState.isLoading ? null : _submit,
                icon: mutationState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.existingAppointment != null
                            ? Icons.save_rounded
                            : Icons.add_rounded,
                      ),
                label: Text(
                  mutationState.isLoading
                      ? 'Saving...'
                      : (widget.existingAppointment != null
                            ? 'Save changes'
                            : 'Add appointment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  static String _prettyDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: onTap != null,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                value ?? 'Select',
                style: TextStyle(
                  color: value == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.schedule_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _CalendarContent extends ConsumerWidget {
  const _CalendarContent({
    required this.selectedDay,
    required this.focusedDay,
    required this.appointmentsAsync,
    required this.isCaregiverRole,
    required this.isSecretaryRole,
  });

  final DateTime selectedDay;
  final DateTime focusedDay;
  final AsyncValue<List<AppointmentModel>> appointmentsAsync;
  final bool isCaregiverRole;
  final bool isSecretaryRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // ── Month-range markers ──────────────────────────────────────────────────
    final monthStart = DateTime(focusedDay.year, focusedDay.month, 1);
    final monthEnd = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final rangeArg = (start: monthStart, end: monthEnd);

    final monthAsync = isCaregiverRole
        ? ref.watch(caregiverMonthAppointmentsProvider(rangeArg))
        : isSecretaryRole
        ? ref.watch(secretaryMonthAppointmentsProvider(rangeArg))
        : ref.watch(doctorMonthAppointmentsProvider(rangeArg));

    final Map<DateTime, List<AppointmentType>> eventMap = {};
    for (final apt in monthAsync.asData?.value ?? const <AppointmentModel>[]) {
      final key = DateTime(
        apt.appointmentDate.year,
        apt.appointmentDate.month,
        apt.appointmentDate.day,
      );
      eventMap.putIfAbsent(key, () => []).add(apt.type);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: TableCalendar<AppointmentType>(
              key: ValueKey((
                focusedDay.year,
                focusedDay.month,
                monthAsync.hasValue,
              )),
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return eventMap[key] ?? const [];
              },
              onDaySelected: (selected, focused) {
                ref.read(selectedCalendarDateProvider.notifier).state =
                    DateTime(selected.year, selected.month, selected.day);
                ref.read(focusedCalendarDateProvider.notifier).state = focused;
                ref.invalidate(appointmentsBySelectedDateProvider);
              },
              onPageChanged: (focused) {
                ref.read(focusedCalendarDateProvider.notifier).state = focused;
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.30),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 2,
              ),
              calendarBuilders: CalendarBuilders<AppointmentType>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  final hasPatient = events.contains(AppointmentType.patient);
                  final hasSpecial = events.contains(AppointmentType.special);
                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (hasPatient) _appointmentDot(scheme.primary),
                        if (hasSpecial) _appointmentDot(Colors.orange),
                      ],
                    ),
                  );
                },
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text(
                'Appointments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _prettyDate(selectedDay),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AppointmentList(
              appointments: appointmentsAsync,
              onRetry: () {
                if (isCaregiverRole) {
                  ref.invalidate(caregiverAppointmentsBySelectedDateProvider);
                } else if (isSecretaryRole) {
                  ref.invalidate(secretaryAppointmentsBySelectedDateProvider);
                } else {
                  ref.invalidate(appointmentsBySelectedDateProvider);
                }
              },
              showDoctorName: isCaregiverRole || isSecretaryRole,
              onEditAppointment: isCaregiverRole
                  ? null
                  : (apt) {
                      ref
                          .read(calendarMutationControllerProvider.notifier)
                          .clearState();
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _AddAppointmentSheet(
                          initialDate: apt.appointmentDate,
                          secretaryMode: isSecretaryRole,
                          existingAppointment: apt,
                        ),
                      );
                    },
              onDeleteAppointment: isCaregiverRole
                  ? null
                  : (apt) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete appointment?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Palette.errorColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      if (isSecretaryRole) {
                        await ref
                            .read(calendarMutationControllerProvider.notifier)
                            .deleteAppointmentAsSecretary(apt.appointmentId);
                      } else {
                        await ref
                            .read(calendarMutationControllerProvider.notifier)
                            .deleteAppointment(apt.appointmentId);
                      }
                      if (!context.mounted) return;
                      AppSnackBar.show(
                        context,
                        'Appointment deleted.',
                        type: SnackBarType.success,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static Widget _appointmentDot(Color color) => Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _CalendarRail extends StatelessWidget {
  const _CalendarRail({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      width: 92,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? scheme.surfaceContainerHighest,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: NavigationRail(
        selectedIndex: 1,
        labelType: NavigationRailLabelType.all,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/community');
              return;
            case 1:
              context.go('/calendar');
              return;
            case 2:
              context.go('/notifications');
              return;
          }
        },
        selectedIconTheme: const IconThemeData(color: Palette.greenColor),
        selectedLabelTextStyle: const TextStyle(color: Palette.greenColor),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        destinations: const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Text('Calendar'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: Text('Alerts'),
          ),
        ],
      ),
    );
  }
}
