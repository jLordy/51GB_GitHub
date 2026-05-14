enum ReminderFrequency {
  daily,
  twiceDaily,
  weekly,
  asNeeded;

  String get label {
    switch (this) {
      case ReminderFrequency.daily:
        return 'Daily';
      case ReminderFrequency.twiceDaily:
        return 'Twice daily';
      case ReminderFrequency.weekly:
        return 'Weekly';
      case ReminderFrequency.asNeeded:
        return 'As needed';
    }
  }

  String get value {
    switch (this) {
      case ReminderFrequency.daily:
        return 'daily';
      case ReminderFrequency.twiceDaily:
        return 'twice_daily';
      case ReminderFrequency.weekly:
        return 'weekly';
      case ReminderFrequency.asNeeded:
        return 'as_needed';
    }
  }

  static ReminderFrequency fromValue(String value) {
    switch (value) {
      case 'twice_daily':
        return ReminderFrequency.twiceDaily;
      case 'weekly':
        return ReminderFrequency.weekly;
      case 'as_needed':
        return ReminderFrequency.asNeeded;
      default:
        return ReminderFrequency.daily;
    }
  }
}
