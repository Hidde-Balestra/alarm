import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/services/alarm_sync_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_alarm_scheduler_service.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('schedules every enabled alarm by default', () async {
    final scheduler = FakeAlarmSchedulerService();
    const alarms = [
      Alarm(id: 'a1', hour: 7, minute: 0, repeat: RepeatRule.daily()),
      Alarm(id: 'a2', hour: 8, minute: 0, repeat: RepeatRule.daily()),
    ];

    await syncAlarmsWithScheduler(
      alarms: alarms,
      customSounds: const [],
      scheduler: scheduler,
      l10n: l10n,
    );

    expect(scheduler.scheduledAlarmIds, containsAll(['a1', 'a2']));
  });

  test('does not touch an alarm that is currently ringing', () async {
    final scheduler = FakeAlarmSchedulerService();
    const alarms = [
      Alarm(id: 'a1', hour: 7, minute: 0, repeat: RepeatRule.daily()),
      Alarm(id: 'a2', hour: 8, minute: 0, repeat: RepeatRule.daily()),
    ];

    await syncAlarmsWithScheduler(
      alarms: alarms,
      customSounds: const [],
      scheduler: scheduler,
      l10n: l10n,
      ringingAlarmIds: const {'a1'},
    );

    expect(scheduler.scheduledAlarmIds, ['a2']);
    expect(scheduler.cancelledAlarmIds, isEmpty);
  });

  test('paused mode cancels non-ringing alarms but still leaves a ringing one alone', () async {
    final scheduler = FakeAlarmSchedulerService();
    const alarms = [
      Alarm(id: 'a1', hour: 7, minute: 0, repeat: RepeatRule.daily()),
      Alarm(id: 'a2', hour: 8, minute: 0, repeat: RepeatRule.daily()),
    ];

    await syncAlarmsWithScheduler(
      alarms: alarms,
      customSounds: const [],
      scheduler: scheduler,
      l10n: l10n,
      paused: true,
      ringingAlarmIds: const {'a1'},
    );

    expect(scheduler.cancelledAlarmIds, ['a2']);
    expect(scheduler.scheduledAlarmIds, isEmpty);
  });
}
