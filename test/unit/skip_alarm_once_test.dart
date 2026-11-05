import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/services/reminder_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 5, 6, 0);

  test('a repeating alarm skips only its next ring', () {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0, repeat: RepeatRule.daily());

    final updated = skipAlarmOnce(const [alarm], 'a1', now)!.single;

    expect(updated.enabled, isTrue);
    expect(updated.skippedOccurrence, DateTime(2026, 11, 5, 7, 0));
    expect(updated.effectiveNextOccurrence(now), DateTime(2026, 11, 6, 7, 0));
  });

  test('a one-shot alarm is switched off instead of moving to tomorrow', () {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0);

    final updated = skipAlarmOnce(const [alarm], 'a1', now)!.single;

    expect(updated.enabled, isFalse);
    expect(updated.skippedOccurrence, isNull);
  });

  test('a nap is removed', () {
    const nap = Alarm(id: 'n1', hour: 6, minute: 45, isNap: true);
    const other = Alarm(id: 'a1', hour: 7, minute: 0);

    expect(skipAlarmOnce(const [nap, other], 'n1', now), [other]);
  });

  test('an unknown id changes nothing', () {
    expect(skipAlarmOnce(const [], 'missing', now), isNull);
  });

  test('the reminder comes an hour ahead and the awake prompt after a minute', () {
    expect(reminderLeadTime, const Duration(hours: 1));
    expect(wakeCheckPromptDelay, const Duration(minutes: 1));
    expect(wakeCheckPromptDelay < wakeCheckRingDelay, isTrue);
  });
}
