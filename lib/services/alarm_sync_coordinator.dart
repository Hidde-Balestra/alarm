import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';

/// Pushes the current in-app alarm list to the OS-level scheduler.
///
/// Safe to call any time the alarm list changes (add/edit/delete/toggle) and
/// on app start: [AlarmSchedulerService.scheduleNext] always (re)computes the
/// next future occurrence and replaces whatever was previously scheduled for
/// that alarm's id, so calling this repeatedly is a no-op for alarms that
/// haven't changed.
Future<void> syncAlarmsWithScheduler({
  required List<Alarm> alarms,
  required AlarmSchedulerService scheduler,
  required AppLocalizations l10n,
  DateTime? now,
}) async {
  final from = now ?? DateTime.now();
  for (final alarm in alarms) {
    await scheduler.scheduleNext(
      alarm,
      from: from,
      notificationTitle: l10n.alarmRingingTitle,
      notificationBody: alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label,
      stopButtonLabel: l10n.dismiss,
    );
  }
}
