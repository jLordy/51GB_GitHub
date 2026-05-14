enum ReminderStatus {
  upcoming,
  taken,
  missed;

  String get value {
    switch (this) {
      case ReminderStatus.upcoming:
        return 'upcoming';
      case ReminderStatus.taken:
        return 'taken';
      case ReminderStatus.missed:
        return 'missed';
    }
  }

  static ReminderStatus fromValue(String value) {
    switch (value) {
      case 'taken':
        return ReminderStatus.taken;
      case 'missed':
        return ReminderStatus.missed;
      default:
        return ReminderStatus.upcoming;
    }
  }
}
