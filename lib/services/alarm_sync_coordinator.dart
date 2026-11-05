import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/models/custom_sound.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/reminder_notification_service.dart';

/// Pushes the current in-app alarm list to the OS-level scheduler.
///
/// Safe to call any time the alarm list (or the custom sound catalog, since
/// that affects which asset path a soundId resolves to) changes, and on app
/// start: [AlarmSchedulerService.scheduleNext] always (re)computes the next
/// future occurrence and replaces whatever was previously scheduled for that
/// alarm's id, so calling this repeatedly is a no-op for alarms that haven't
/// changed. It also refuses to touch an alarm that's currently ringing (see
/// [AlarmSchedulerService.isRinging]) — this matters because a sync can run
/// right as the app cold-starts from that very alarm's own full-screen
/// intent, and replacing its native schedule would cut the live ring short.
///
/// When [paused] is true (the "pause all alarms" setting), every
/// *non-ringing* alarm is cancelled at the OS level regardless of its own
/// `enabled` flag — but that flag itself is left untouched, so turning the
/// pause back off restores exactly the alarms that were on before. A
/// currently-ringing alarm is left alone even while paused, for the same
/// reason `scheduleNext` leaves it alone: the user can still dismiss it
/// normally, pausing shouldn't silently cut it off mid-ring.
Future<void> syncAlarmsWithScheduler({
  required List<Alarm> alarms,
  required List<CustomSound> customSounds,
  required AlarmSchedulerService scheduler,
  required AppLocalizations l10n,
  bool paused = false,
  DateTime? now,
}) async {
  final from = now ?? DateTime.now();
  for (final alarm in alarms) {
    if (paused) {
      if (!await scheduler.isRinging(alarm.id)) {
        await scheduler.cancelAlarm(alarm.id);
      }
      continue;
    }
    await scheduler.scheduleNext(
      alarm,
      from: from,
      soundAssetPath: resolveSoundAssetPath(alarm.soundId, customSounds),
      notificationTitle: l10n.alarmRingingTitle,
      notificationBody: alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label,
      stopButtonLabel: l10n.dismiss,
    );
  }
}

/// Pushes the current in-app alarm list to the reminder notifications, the
/// same way [syncAlarmsWithScheduler] does for the real OS-level alarm: a
/// silent heads-up [reminderLeadTime] before each alarm's next occurrence,
/// with a "just this once" action, plus the silent sunrise trigger for alarms
/// that have one. Safe to call any time the alarm list changes.
Future<void> syncReminderNotifications({
  required List<Alarm> alarms,
  required ReminderNotificationService reminders,
  required AppLocalizations l10n,
  bool paused = false,
  DateTime? now,
}) async {
  final from = now ?? DateTime.now();
  for (final alarm in alarms) {
    final next = paused || !alarm.enabled ? null : alarm.effectiveNextOccurrence(from);
    if (next == null) {
      await reminders.cancelReminder(alarm.id);
      await reminders.cancelSunrise(alarm.id);
      continue;
    }
    final body = alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label;
    await reminders.scheduleReminder(
      alarmId: alarm.id,
      occurrence: next,
      title: l10n.alarmReminderTitle(_formatTime(next)),
      body: body,
      skipActionLabel: l10n.reminderSkipOnceAction,
    );
    await reminders.scheduleSunrise(
      alarmId: alarm.id,
      occurrence: next,
      minutes: alarm.sunriseMinutes,
      title: l10n.sunriseTitle,
      body: body,
    );
  }
}

/// Plain "07:00". Deliberately not `DateFormat`: this also runs from the
/// notification-action isolate, where intl's locale data isn't loaded.
String _formatTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// An alarm whose sunrise window (`sunriseMinutes` before it rings) is
/// running right now.
class ActiveSunrise {
  final Alarm alarm;
  final DateTime startsAt;
  final DateTime ringsAt;

  const ActiveSunrise(this.alarm, this.startsAt, this.ringsAt);
}

/// The alarm (if any) whose sunrise should be showing at [now]. Picks the
/// soonest-ringing one if windows overlap.
ActiveSunrise? activeSunrise(List<Alarm> alarms, DateTime now, {bool paused = false}) {
  if (paused) return null;
  ActiveSunrise? best;
  for (final alarm in alarms) {
    if (!alarm.enabled || alarm.sunriseMinutes <= 0) continue;
    final ringsAt = alarm.effectiveNextOccurrence(now);
    if (ringsAt == null) continue;
    final startsAt = ringsAt.subtract(Duration(minutes: alarm.sunriseMinutes));
    if (now.isBefore(startsAt)) continue;
    if (best == null || ringsAt.isBefore(best.ringsAt)) {
      best = ActiveSunrise(alarm, startsAt, ringsAt);
    }
  }
  return best;
}
