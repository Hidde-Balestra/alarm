import 'dart:async';

import 'package:alarm/alarm.dart' as plugin;
import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/alarm_sync_coordinator.dart';
import 'package:alarm_app/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _skipOnceActionId = 'skip_once';
const _awakeActionId = 'awake';
const _sunrisePayloadPrefix = 'sunrise:';

// A new id (not `alarm_reminder_channel`): Android fixes a channel's
// importance once created, and the old low-importance one kept the
// reminder off the lock screen.
const _channelId = 'alarm_reminder_lockscreen_channel';
const _channelName = 'Alarm reminder';
const _channelDescription =
    'A silent heads-up an hour before an alarm rings, with an option to turn it off just once.';

const _sunriseChannelId = 'sunrise_channel';
const _sunriseChannelName = 'Sunrise';
const _sunriseChannelDescription =
    'Silently wakes the screen to start the sunrise light before an alarm.';

const _wakeCheckChannelId = 'wake_check_channel';
const _wakeCheckChannelName = 'Are you awake?';
const _wakeCheckChannelDescription =
    'Asks for confirmation shortly after an alarm is dismissed, before it rings again.';

/// How long before an alarm is due to ring the silent reminder notification
/// (with its "skip once" action) is shown.
const reminderLeadTime = Duration(hours: 1);

/// How long after dismissing (with `Alarm.wakeUpCheck` on) the "are you
/// awake?" notification appears…
const wakeCheckPromptDelay = Duration(minutes: 1);

/// …and how long after dismissing the alarm rings again if that
/// notification wasn't confirmed by then.
const wakeCheckRingDelay = Duration(minutes: 5);

/// Owns the app's `flutter_local_notifications` notifications (as opposed to
/// the `alarm` plugin's own ringing notifications). Android-only: the
/// `alarm` plugin's full-screen ringing UI already covers iOS's more limited
/// notification model.
///
/// - A silent reminder [reminderLeadTime] before an alarm, visible on the
///   lock screen, with an action to turn it off for just that one ring
///   without opening the app (see [skipAlarmOnce]).
/// - A silent full-screen-intent "sunrise" trigger `Alarm.sunriseMinutes`
///   before an alarm. It only wakes the screen and brings the app up; the
///   app itself decides to show the sunrise (see `activeSunrise`). This is
///   deliberately *not* an `alarm` plugin alarm: the plugin drops a new
///   alarm while another one is still ringing, so a "ringing" silent
///   sunrise could swallow the real alarm.
/// - The "are you awake?" prompt after dismissing, with an "I'm awake"
///   action that cancels the follow-up ring.
///
/// Actions are handled by [_onNotificationResponse] below, which works
/// whether the app is in the foreground, backgrounded, or fully killed — it
/// re-derives everything it needs from storage each time rather than
/// relying on in-memory app state, since a killed app has none.
class ReminderNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Set by the running app so a tap on a sunrise notification while it's
  /// already open can show the sunrise right away.
  static VoidCallback? onSunriseTapped;

  /// Set by the running app so confirming from the notification also
  /// clears the in-app "I'm awake" banner.
  static void Function(String alarmId)? onAwakeConfirmed;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_isAndroid || _initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // Falls back to UTC if the platform timezone can't be resolved; the
      // reminder will still fire, just possibly off by the local UTC offset.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationResponse,
    );
  }

  int _notificationId(String alarmId) => ('reminder-$alarmId').hashCode & 0x7fffffff;
  int _sunriseNotificationId(String alarmId) => ('sunrise-$alarmId').hashCode & 0x7fffffff;
  int _wakeCheckNotificationId(String alarmId) => ('wakecheck-$alarmId').hashCode & 0x7fffffff;

  Future<void> scheduleReminder({
    required String alarmId,
    required DateTime occurrence,
    required String title,
    required String body,
    required String skipActionLabel,
  }) async {
    if (!_isAndroid) return;
    final reminderTime = occurrence.subtract(reminderLeadTime);
    if (reminderTime.isBefore(DateTime.now())) {
      // Too close to (or past) the ring time for the reminder to make sense.
      await cancelReminder(alarmId);
      return;
    }
    await _plugin.zonedSchedule(
      id: _notificationId(alarmId),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
          silent: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.reminder,
          timeoutAfter: reminderLeadTime.inMilliseconds,
          actions: [
            AndroidNotificationAction(_skipOnceActionId, skipActionLabel, showsUserInterface: false),
          ],
        ),
      ),
      payload: alarmId,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder(String alarmId) async {
    if (!_isAndroid) return;
    await _plugin.cancel(id: _notificationId(alarmId));
  }

  /// Schedules the silent sunrise trigger [minutes] before [occurrence].
  /// Cancels instead if that start time has already passed — if the app is
  /// open during the window anyway, it shows the sunrise by itself.
  Future<void> scheduleSunrise({
    required String alarmId,
    required DateTime occurrence,
    required int minutes,
    required String title,
    required String body,
  }) async {
    if (!_isAndroid) return;
    final start = occurrence.subtract(Duration(minutes: minutes));
    if (minutes <= 0 || start.isBefore(DateTime.now())) {
      await cancelSunrise(alarmId);
      return;
    }
    await _plugin.zonedSchedule(
      id: _sunriseNotificationId(alarmId),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(start, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _sunriseChannelId,
          _sunriseChannelName,
          channelDescription: _sunriseChannelDescription,
          // Full-screen intents need a high-importance channel; it stays
          // silent through playSound/enableVibration instead.
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: false,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          timeoutAfter: Duration(minutes: minutes).inMilliseconds,
        ),
      ),
      payload: '$_sunrisePayloadPrefix$alarmId',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelSunrise(String alarmId) async {
    if (!_isAndroid) return;
    await _plugin.cancel(id: _sunriseNotificationId(alarmId));
  }

  /// Shows the "are you awake?" prompt at [at], until [expiresAt] (when the
  /// follow-up ring takes over).
  Future<void> scheduleWakeCheckPrompt({
    required String alarmId,
    required DateTime at,
    required DateTime expiresAt,
    required String title,
    required String body,
    required String awakeActionLabel,
  }) async {
    if (!_isAndroid) return;
    await _plugin.zonedSchedule(
      id: _wakeCheckNotificationId(alarmId),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _wakeCheckChannelId,
          _wakeCheckChannelName,
          channelDescription: _wakeCheckChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          // Shown in full on the lock screen, so "I'm awake" works without
          // unlocking first.
          visibility: NotificationVisibility.public,
          timeoutAfter: expiresAt.difference(at).inMilliseconds,
          actions: [
            AndroidNotificationAction(_awakeActionId, awakeActionLabel, showsUserInterface: false),
          ],
        ),
      ),
      payload: alarmId,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelWakeCheckPrompt(String alarmId) async {
    if (!_isAndroid) return;
    await _plugin.cancel(id: _wakeCheckNotificationId(alarmId));
  }
}

/// Runs for both the foreground and background notification-response
/// callbacks (the background one must be a top-level or static function).
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  switch (response.actionId) {
    case _skipOnceActionId:
      unawaited(_skipAlarmOnce(payload));
    case _awakeActionId:
      unawaited(_confirmAwake(payload));
    case null:
      // A plain tap opens the app like any other notification; for the
      // sunrise one, an already-open app also needs a nudge to show it.
      if (payload.startsWith(_sunrisePayloadPrefix)) {
        ReminderNotificationService.onSunriseTapped?.call();
      }
  }
}

Future<void> _confirmAwake(String alarmId) async {
  final inApp = ReminderNotificationService.onAwakeConfirmed;
  if (inApp != null) {
    inApp(alarmId);
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await plugin.Alarm.init();
  await AlarmSchedulerService().cancelWakeCheck(alarmId);
  await ReminderNotificationService().cancelWakeCheckPrompt(alarmId);
}

/// The alarm list after turning [alarmId] off for just its next ring, or
/// null if there's nothing to skip. A repeating alarm skips that one
/// occurrence; a one-shot alarm (whose "next time" is the only time) is
/// switched off instead of being pushed to tomorrow, and a nap is removed.
List<Alarm>? skipAlarmOnce(List<Alarm> alarms, String alarmId, DateTime now) {
  final index = alarms.indexWhere((a) => a.id == alarmId);
  if (index == -1) return null;
  final alarm = alarms[index];
  if (alarm.isNap) return [...alarms]..removeAt(index);
  if (!alarm.repeat.repeats) {
    return [...alarms]..[index] = alarm.copyWith(enabled: false);
  }
  final next = alarm.nextOccurrenceSkippingHolidays(now);
  if (next == null) return null;
  return [...alarms]..[index] = alarm.copyWith(skippedOccurrence: next);
}

Future<void> _skipAlarmOnce(String alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required before touching AlarmStorage (via plugin.Alarm.set/stop) in a
  // fresh isolate that hasn't run the app's normal startup.
  await plugin.Alarm.init();

  final storage = StorageService();
  final alarms = await storage.loadAlarms();
  final updatedAlarms = skipAlarmOnce(alarms, alarmId, DateTime.now());
  if (updatedAlarms == null) return;
  await storage.saveAlarms(updatedAlarms);

  final scheduler = AlarmSchedulerService();
  final reminders = ReminderNotificationService();
  await reminders.init();
  if (!updatedAlarms.any((a) => a.id == alarmId)) {
    // A removed nap is no longer in the list for the sync below to cancel.
    await scheduler.cancelAlarm(alarmId);
    await reminders.cancelReminder(alarmId);
    await reminders.cancelSunrise(alarmId);
  }

  final settings = await storage.loadSettings();
  final customSounds = await storage.loadCustomSounds();
  final l10n = lookupAppLocalizations(resolveEffectiveLocale(settings));

  await syncAlarmsWithScheduler(
    alarms: updatedAlarms,
    customSounds: customSounds,
    scheduler: scheduler,
    l10n: l10n,
    paused: settings.alarmsPaused,
  );
  await syncReminderNotifications(
    alarms: updatedAlarms,
    reminders: reminders,
    l10n: l10n,
    paused: settings.alarmsPaused,
  );
}
