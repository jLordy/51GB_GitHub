import 'dart:async';
import 'dart:convert';

import 'package:frontend/features/reminder/model/medication_reminder.dart';
import 'package:frontend/features/reminder/model/reminder_frequency.dart';
import 'package:frontend/features/reminder/model/reminder_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

// To enable real device alarms:
//   1. Add `flutter_local_notifications` to pubspec.yaml
//   2. Replace the Timer-based _alarmTimers map with NotificationsService calls
//   3. Call initializeNotifications() from main.dart before runApp()

class ReminderLocalService {
  static const _kStorageKey = 'medication_reminders_v1';

  final _alarmTimers = <String, Timer>{};

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<List<MedicationReminder>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kStorageKey) ?? [];
    return raw
        .map((s) => MedicationReminder.fromJson(
              Map<String, dynamic>.from(jsonDecode(s) as Map),
            ))
        .toList();
  }

  Future<void> saveAll(List<MedicationReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kStorageKey,
      reminders.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  // ── Timezone-aware alarm scheduling ─────────────────────────────────────────
  //
  // DateTime.now() is already in the device's local timezone; toLocal() is
  // called on deserialization so scheduledTime is always local.
  // For cross-timezone support, store UTC and use the `timezone` package.

  void scheduleAlarm(MedicationReminder reminder, void Function() onFire) {
    cancelAlarm(reminder.id);
    if (!reminder.isAlarmEnabled) return;

    final now = DateTime.now();
    var target = reminder.scheduledTime;

    // Advance to the next future occurrence (local time).
    while (!target.isAfter(now)) {
      target = _nextOccurrence(target, reminder.frequency);
      if (reminder.frequency == ReminderFrequency.asNeeded) break;
    }

    if (!target.isAfter(now)) return;

    final delay = target.difference(now);
    _alarmTimers[reminder.id] = Timer(delay, () {
      onFire();
      // Re-schedule recurring frequencies automatically.
      if (reminder.frequency != ReminderFrequency.asNeeded) {
        final next = reminder.copyWith(
          scheduledTime: _nextOccurrence(target, reminder.frequency),
        );
        scheduleAlarm(next, onFire);
      }
    });
  }

  void cancelAlarm(String id) {
    _alarmTimers.remove(id)?.cancel();
  }

  void cancelAll() {
    for (final t in _alarmTimers.values) {
      t.cancel();
    }
    _alarmTimers.clear();
  }

  DateTime _nextOccurrence(DateTime from, ReminderFrequency frequency) {
    switch (frequency) {
      case ReminderFrequency.daily:
        return from.add(const Duration(days: 1));
      case ReminderFrequency.twiceDaily:
        return from.add(const Duration(hours: 12));
      case ReminderFrequency.weekly:
        return from.add(const Duration(days: 7));
      case ReminderFrequency.asNeeded:
        return from;
    }
  }

  // ── Missed dose detection ────────────────────────────────────────────────────
  //
  // A dose is considered missed when 30 minutes have elapsed past the
  // scheduled time without the user marking it as taken.

  List<MedicationReminder> markMissedDoses(List<MedicationReminder> reminders) {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    return reminders.map((r) {
      if (r.status == ReminderStatus.upcoming &&
          r.scheduledTime.isBefore(cutoff)) {
        return r.copyWith(status: ReminderStatus.missed);
      }
      return r;
    }).toList();
  }
}
