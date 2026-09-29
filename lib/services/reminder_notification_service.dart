import 'dart:async';

import 'package:alarm/alarm.dart' as plugin;
import 'package:alarm_app/l10n/gen/app_localizations.dart';
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
const _channelId = 'alarm_reminder_channel';
const _channelName = 'Alarm reminder';
const _channelDescription =
    'A quiet heads-up shortly before an alarm rings, with an option to skip it.';

/// How long before an alarm is due to ring the silent reminder notification
/// (with its "skip once" action) is shown.
const reminderLeadTime = Duration(minutes: 12);

/// Schedules a quiet, no-sound notification [reminderLeadTime] before an
/// alarm is due to ring, with an action to skip that one occurrence without
/// having to open the app. Android-only: the `alarm` plugin's own
/// full-screen ringing UI already covers iOS's more limited notification
/// model.
///
/// The "skip once" action is handled by [_onNotificationResponse] below,
/// which works whether the app is in the foreground, backgrounded, or fully
/// killed — it re-derives everything it needs (the alarm list, the locale,
/// the scheduler) from storage each time rather than relying on any
/// in-memory app state, since a killed app has none.
class ReminderNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          silent: true,
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
}

/// Runs for both the foreground and background notification-response
/// callbacks (the background one must be a top-level or static function).
/// Only reacts to the "skip once" action; a plain tap on the reminder just
/// opens the app like any other notification.
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  if (response.actionId != _skipOnceActionId) return;
  final alarmId = response.payload;
  if (alarmId == null || alarmId.isEmpty) return;
  unawaited(_skipAlarmOnce(alarmId));
}

Future<void> _skipAlarmOnce(String alarmId) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required before touching AlarmStorage (via plugin.Alarm.set/stop) in a
  // fresh isolate that hasn't run the app's normal startup.
  await plugin.Alarm.init();

  final storage = StorageService();
  final alarms = await storage.loadAlarms();
  final index = alarms.indexWhere((a) => a.id == alarmId);
  if (index == -1) return;

  final alarm = alarms[index];
  final next = alarm.nextOccurrence(DateTime.now());
  if (next == null) return;

  final updatedAlarms = List.of(alarms);
  updatedAlarms[index] = alarm.copyWith(skippedOccurrence: next);
  await storage.saveAlarms(updatedAlarms);

  final settings = await storage.loadSettings();
  final customSounds = await storage.loadCustomSounds();
  final l10n = lookupAppLocalizations(resolveEffectiveLocale(settings));

  final reminders = ReminderNotificationService();
  await reminders.init();

  await syncAlarmsWithScheduler(
    alarms: updatedAlarms,
    customSounds: customSounds,
    scheduler: AlarmSchedulerService(),
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
