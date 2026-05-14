import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:frontend/features/reminder/data/reminder_local_service.dart';
import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ReminderState {
  const ReminderState({
    this.reminders = const [],
    this.isLoading = false,
    this.error,
  });

  final List<MedicationReminder> reminders;
  final bool isLoading;
  final String? error;

  ReminderState copyWith({
    List<MedicationReminder>? reminders,
    bool? isLoading,
    String? error,
  }) {
    return ReminderState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final reminderLocalServiceProvider = Provider<ReminderLocalService>((ref) {
  final service = ReminderLocalService();
  ref.onDispose(service.cancelAll);
  return service;
});

final reminderControllerProvider =
    StateNotifierProvider<ReminderController, ReminderState>((ref) {
  return ReminderController(ref.read(reminderLocalServiceProvider));
});

// ── Controller ────────────────────────────────────────────────────────────────

class ReminderController extends StateNotifier<ReminderState> {
  ReminderController(this._local) : super(const ReminderState()) {
    _init();
  }

  final ReminderLocalService _local;
  Timer? _missedDoseTimer;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final loaded = await _local.loadAll();
      final checked = _local.markMissedDoses(loaded);
      await _local.saveAll(checked);
      state = state.copyWith(reminders: checked, isLoading: false);
      _scheduleAll();
      _startMissedDoseWatcher();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _scheduleAll() {
    for (final r in state.reminders) {
      _local.scheduleAlarm(r, () => _onAlarmFired(r.id));
    }
  }

  // Checks every 5 minutes whether any upcoming dose has been missed.
  void _startMissedDoseWatcher() {
    _missedDoseTimer?.cancel();
    _missedDoseTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final checked = _local.markMissedDoses(state.reminders);
      state = state.copyWith(reminders: checked);
      await _local.saveAll(checked);
    });
  }

  void _onAlarmFired(String id) {
    // Alarm fired in-process (foreground only).
    // For background/killed-app alarms, plug in flutter_local_notifications here.
    state = state.copyWith(reminders: [...state.reminders]);
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> add(MedicationReminder reminder) async {
    final next = [...state.reminders, reminder];
    state = state.copyWith(reminders: next);
    await _local.saveAll(next);
    _local.scheduleAlarm(reminder, () => _onAlarmFired(reminder.id));
  }

  Future<void> update(MedicationReminder reminder) async {
    final next =
        state.reminders.map((r) => r.id == reminder.id ? reminder : r).toList();
    state = state.copyWith(reminders: next);
    await _local.saveAll(next);
    _local.cancelAlarm(reminder.id);
    _local.scheduleAlarm(reminder, () => _onAlarmFired(reminder.id));
  }

  Future<void> delete(String id) async {
    _local.cancelAlarm(id);
    final next = state.reminders.where((r) => r.id != id).toList();
    state = state.copyWith(reminders: next);
    await _local.saveAll(next);
  }

  Future<void> toggleAlarm(String id) async {
    final next = state.reminders.map((r) {
      if (r.id != id) return r;
      final toggled = r.copyWith(isAlarmEnabled: !r.isAlarmEnabled);
      if (toggled.isAlarmEnabled) {
        _local.scheduleAlarm(toggled, () => _onAlarmFired(id));
      } else {
        _local.cancelAlarm(id);
      }
      return toggled;
    }).toList();
    state = state.copyWith(reminders: next);
    await _local.saveAll(next);
  }

  Future<void> markStatus(String id, ReminderStatus status) async {
    final next =
        state.reminders.map((r) => r.id == id ? r.copyWith(status: status) : r).toList();
    state = state.copyWith(reminders: next);
    await _local.saveAll(next);
  }

  @override
  void dispose() {
    _missedDoseTimer?.cancel();
    _local.cancelAll();
    super.dispose();
  }
}
