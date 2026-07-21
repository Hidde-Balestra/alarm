import 'dart:convert';

import 'package:alarm/alarm.dart' as plugin;
import 'package:alarm/utils/alarm_set.dart' as plugin;
import 'package:alarm_app/models/alarm.dart' as model;

/// What kind of ringing entity an [plugin.AlarmSettings.payload] refers to.
enum RingingKind { alarm, timer }

/// Decoded identity of a ringing/scheduled entity, recovered from the
/// `payload` field so the UI can look up the right [model.Alarm] or timer by
/// its own string id instead of the numeric id the OS scheduler needs.
class RingingRef {
  final RingingKind kind;
  final String refId;

  const RingingRef(this.kind, this.refId);

  String encode() => jsonEncode({'kind': kind.name, 'refId': refId});

  static RingingRef? tryDecode(String? payload) {
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final kind = RingingKind.values.byName(json['kind'] as String);
      return RingingRef(kind, json['refId'] as String);
    } catch (_) {
      return null;
    }
  }
}

/// Wraps the `alarm` plugin: turns our [model.Alarm]/timer entities into
/// scheduled OS-level alarms that ring at full volume through Do Not
/// Disturb, and keeps them advancing to their next occurrence.
///
/// Kept as an instance (not static calls) so it can be swapped for a fake in
/// widget tests via Riverpod provider overrides.
class AlarmSchedulerService {
  Future<void> init() => plugin.Alarm.init();

  Stream<plugin.AlarmSet> get ringing => plugin.Alarm.ringing;

  int _numericId(RingingKind kind, String refId) =>
      ('${kind.name}-$refId').hashCode & 0x7fffffff;

  /// Schedules [alarm]'s next occurrence, replacing whatever was previously
  /// scheduled for it. Cancels instead if the alarm is disabled or has no
  /// future occurrence.
  Future<void> scheduleNext(
    model.Alarm alarm, {
    required DateTime from,
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final next = alarm.enabled ? alarm.nextOccurrence(from) : null;
    if (next == null) {
      await cancelAlarm(alarm.id);
      return;
    }
    await plugin.Alarm.set(
      alarmSettings: plugin.AlarmSettings(
        id: _numericId(RingingKind.alarm, alarm.id),
        dateTime: next,
        assetAudioPath: 'assets/sounds/alarm_beep.wav',
        loopAudio: true,
        vibrate: alarm.vibrate,
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
        volumeSettings: const plugin.VolumeSettings.fixed(
          volume: 1,
          volumeEnforced: true,
        ),
        notificationSettings: plugin.NotificationSettings(
          title: notificationTitle,
          body: notificationBody,
          stopButton: stopButtonLabel,
        ),
        payload: RingingRef(RingingKind.alarm, alarm.id).encode(),
      ),
    );
  }

  /// Re-schedules a currently-ringing alarm to ring again in
  /// [alarm.snoozeMinutes], instead of its normal repeat-rule occurrence.
  Future<void> snooze(
    model.Alarm alarm, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    await plugin.Alarm.set(
      alarmSettings: plugin.AlarmSettings(
        id: _numericId(RingingKind.alarm, alarm.id),
        dateTime: DateTime.now().add(Duration(minutes: alarm.snoozeMinutes)),
        assetAudioPath: 'assets/sounds/alarm_beep.wav',
        loopAudio: true,
        vibrate: alarm.vibrate,
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
        volumeSettings: const plugin.VolumeSettings.fixed(
          volume: 1,
          volumeEnforced: true,
        ),
        notificationSettings: plugin.NotificationSettings(
          title: notificationTitle,
          body: notificationBody,
          stopButton: stopButtonLabel,
        ),
        payload: RingingRef(RingingKind.alarm, alarm.id).encode(),
      ),
    );
  }

  Future<void> cancelAlarm(String alarmId) =>
      plugin.Alarm.stop(_numericId(RingingKind.alarm, alarmId));

  /// Schedules a one-shot timer alarm at [end].
  Future<void> scheduleTimer(
    String timerId,
    DateTime end, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    await plugin.Alarm.set(
      alarmSettings: plugin.AlarmSettings(
        id: _numericId(RingingKind.timer, timerId),
        dateTime: end,
        assetAudioPath: 'assets/sounds/timer_beep.wav',
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
        volumeSettings: const plugin.VolumeSettings.fixed(
          volume: 1,
          volumeEnforced: true,
        ),
        notificationSettings: plugin.NotificationSettings(
          title: notificationTitle,
          body: notificationBody,
          stopButton: stopButtonLabel,
        ),
        payload: RingingRef(RingingKind.timer, timerId).encode(),
      ),
    );
  }

  Future<void> cancelTimer(String timerId) =>
      plugin.Alarm.stop(_numericId(RingingKind.timer, timerId));

  Future<void> stopRingingByPayload(String? payload) async {
    final ref = RingingRef.tryDecode(payload);
    if (ref == null) return;
    final id = _numericId(ref.kind, ref.refId);
    await plugin.Alarm.stop(id);
  }
}
