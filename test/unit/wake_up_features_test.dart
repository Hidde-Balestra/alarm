import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/holidays.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/screens/alarms/alarm_list_screen.dart';
import 'package:alarm_app/screens/ringing/sunrise_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/alarm_sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('holiday skipping', () {
    const daily = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      repeat: RepeatRule.daily(),
      skipHolidays: true,
    );

    test('a daily alarm skips Christmas Day and Boxing Day back to back', () {
      final next = daily.effectiveNextOccurrence(DateTime(2026, 12, 24, 8, 0));
      expect(next, DateTime(2026, 12, 27, 7, 0));
    });

    test('with skipHolidays off, holidays ring as normal', () {
      final alarm = daily.copyWith(skipHolidays: false);
      final next = alarm.effectiveNextOccurrence(DateTime(2026, 12, 24, 8, 0));
      expect(next, DateTime(2026, 12, 25, 7, 0));
    });

    test('a one-shot alarm ignores skipHolidays', () {
      const oneShot = Alarm(id: 'a1', hour: 7, minute: 0, skipHolidays: true);
      final next = oneShot.effectiveNextOccurrence(DateTime(2026, 12, 24, 8, 0));
      expect(next, DateTime(2026, 12, 25, 7, 0));
    });

    test('upcomingSkippedHoliday names the holiday being skipped', () {
      expect(
        daily.upcomingSkippedHoliday(DateTime(2026, 4, 26, 8, 0)),
        DutchHoliday.kingsDay,
      );
      expect(daily.upcomingSkippedHoliday(DateTime(2026, 4, 28, 8, 0)), isNull);
    });

    test('skip-next targets the first non-holiday occurrence', () {
      final target = daily.nextOccurrenceSkippingHolidays(DateTime(2026, 12, 24, 8, 0));
      expect(target, DateTime(2026, 12, 27, 7, 0));

      final skipped = daily.copyWith(skippedOccurrence: target);
      expect(
        skipped.effectiveNextOccurrence(DateTime(2026, 12, 24, 8, 0)),
        DateTime(2026, 12, 28, 7, 0),
      );
    });
  });

  test('new per-alarm fields survive a JSON round-trip', () {
    const alarm = Alarm(
      id: 'a1',
      hour: 6,
      minute: 45,
      sunriseMinutes: 20,
      wakeUpCheck: true,
      showGoodMorning: false,
      skipHolidays: true,
      isNap: true,
    );
    expect(Alarm.fromJson(alarm.toJson()), alarm);
  });

  test('alarms saved by an older version get sensible defaults', () {
    final restored = Alarm.fromJson({'id': 'x', 'hour': 6, 'minute': 0});
    expect(restored.sunriseMinutes, 0);
    expect(restored.wakeUpCheck, isFalse);
    expect(restored.showGoodMorning, isTrue);
    expect(restored.skipHolidays, isFalse);
    expect(restored.isNap, isFalse);
  });

  test('new settings defaults survive a JSON round-trip', () {
    const settings = AppSettings(
      defaultSunriseMinutes: 15,
      defaultWakeUpCheck: true,
      defaultShowGoodMorning: false,
      defaultSkipHolidays: true,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.defaultSunriseMinutes, 15);
    expect(restored.defaultWakeUpCheck, isTrue);
    expect(restored.defaultShowGoodMorning, isFalse);
    expect(restored.defaultSkipHolidays, isTrue);
  });

  group('activeSunrise', () {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0, sunriseMinutes: 20);

    test('is active inside the window before the alarm', () {
      final active = activeSunrise(const [alarm], DateTime(2026, 11, 2, 6, 50));
      expect(active?.alarm.id, 'a1');
      expect(active?.startsAt, DateTime(2026, 11, 2, 6, 40));
      expect(active?.ringsAt, DateTime(2026, 11, 2, 7, 0));
    });

    test('is not active before the window, when paused, or when disabled', () {
      expect(activeSunrise(const [alarm], DateTime(2026, 11, 2, 6, 30)), isNull);
      expect(activeSunrise(const [alarm], DateTime(2026, 11, 2, 6, 50), paused: true), isNull);
      expect(
        activeSunrise([alarm.copyWith(enabled: false)], DateTime(2026, 11, 2, 6, 50)),
        isNull,
      );
    });

    test('alarms without a sunrise never activate one', () {
      final plain = alarm.copyWith(sunriseMinutes: 0);
      expect(activeSunrise([plain], DateTime(2026, 11, 2, 6, 59)), isNull);
    });
  });

  test('sunriseProgress runs from 0 to 1 across the window', () {
    final start = DateTime(2026, 11, 2, 6, 40);
    final end = DateTime(2026, 11, 2, 7, 0);
    expect(sunriseProgress(start, end, DateTime(2026, 11, 2, 6, 30)), 0);
    expect(sunriseProgress(start, end, DateTime(2026, 11, 2, 6, 50)), closeTo(0.5, 1e-9));
    expect(sunriseProgress(start, end, DateTime(2026, 11, 2, 7, 5)), 1);
  });

  group('buildNapAlarm', () {
    test('rounds up to the next whole minute', () {
      final nap = buildNapAlarm(
        id: 'n1',
        now: DateTime(2026, 11, 2, 14, 3, 40),
        minutes: 20,
        label: 'Nap',
        settings: const AppSettings(),
      );
      expect((nap.hour, nap.minute), (14, 24));
      expect(nap.isNap, isTrue);
      expect(nap.repeat.repeats, isFalse);
      expect(nap.showGoodMorning, isFalse);
    });

    test('keeps an exact minute as-is and crosses midnight', () {
      final nap = buildNapAlarm(
        id: 'n1',
        now: DateTime(2026, 11, 2, 23, 30),
        minutes: 45,
        label: 'Nap',
        settings: const AppSettings(defaultAlarmSoundId: 'ocean'),
      );
      expect((nap.hour, nap.minute), (0, 15));
      expect(nap.soundId, 'ocean');
    });
  });

  test('RingingRef keeps the wake-check stage through encode/decode', () {
    const ref = RingingRef(RingingKind.alarm, 'a1', stage: RingingStage.wakeCheck);
    final decoded = RingingRef.tryDecode(ref.encode());
    expect(decoded?.isWakeCheck, isTrue);
    expect(decoded?.refId, 'a1');

    // Payloads from before stages existed still decode as a normal ring.
    final legacy = RingingRef.tryDecode('{"kind":"alarm","refId":"a1"}');
    expect(legacy?.stage, RingingStage.ring);
  });
}
