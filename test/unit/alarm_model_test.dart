import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Alarm JSON round-trip preserves all fields', () {
    final alarm = Alarm(
      id: 'abc-123',
      hour: 7,
      minute: 30,
      label: 'Werk',
      enabled: false,
      repeat: RepeatRule.biweekly({DateTime.monday, DateTime.thursday}, DateTime(2026, 7, 20)),
      vibrate: false,
      snoozeMinutes: 5,
    );

    final restored = Alarm.fromJson(alarm.toJson());

    expect(restored, alarm);
  });

  test('Alarm.fromJson fills in defaults for missing optional fields', () {
    final restored = Alarm.fromJson({'id': 'x', 'hour': 6, 'minute': 0});

    expect(restored.label, '');
    expect(restored.enabled, isTrue);
    expect(restored.vibrate, isTrue);
    expect(restored.snoozeMinutes, 9);
    expect(restored.repeat, const RepeatRule.none());
  });

  test('copyWith only changes the specified fields', () {
    const alarm = Alarm(id: 'x', hour: 6, minute: 0, label: 'Old');
    final updated = alarm.copyWith(label: 'New', enabled: false);

    expect(updated.label, 'New');
    expect(updated.enabled, isFalse);
    expect(updated.hour, alarm.hour);
    expect(updated.minute, alarm.minute);
  });

  test('nextOccurrence delegates to the repeat rule using the alarm time', () {
    const alarm = Alarm(id: 'x', hour: 7, minute: 0, repeat: RepeatRule.daily());
    final from = DateTime(2026, 7, 21, 6, 0);

    expect(alarm.nextOccurrence(from), DateTime(2026, 7, 21, 7, 0));
  });
}
