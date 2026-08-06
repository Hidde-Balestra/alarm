import 'package:alarm_app/models/alarm.dart';

/// The earliest occurrence found by [nextUpcomingAlarm], paired with the
/// alarm it belongs to.
class UpcomingAlarm {
  final Alarm alarm;
  final DateTime at;

  const UpcomingAlarm(this.alarm, this.at);
}

/// The soonest enabled alarm across [alarms], accounting for skipped
/// occurrences, or null if none are enabled (or none can ever fire).
UpcomingAlarm? nextUpcomingAlarm(List<Alarm> alarms, DateTime from) {
  UpcomingAlarm? earliest;
  for (final alarm in alarms) {
    if (!alarm.enabled) continue;
    final next = alarm.effectiveNextOccurrence(from);
    if (next == null) continue;
    if (earliest == null || next.isBefore(earliest.at)) {
      earliest = UpcomingAlarm(alarm, next);
    }
  }
  return earliest;
}
