import 'package:alarm_app/models/upcoming_alarm.dart';

/// When to go to sleep to get [desiredSleepHours] before [upcoming] rings,
/// or null if there's no upcoming alarm to count back from.
DateTime? computeBedtime(UpcomingAlarm? upcoming, double desiredSleepHours) {
  if (upcoming == null) return null;
  final sleepMinutes = (desiredSleepHours * 60).round();
  return upcoming.at.subtract(Duration(minutes: sleepMinutes));
}
