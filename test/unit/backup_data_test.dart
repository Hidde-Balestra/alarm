import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/backup_data.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a list of alarms through JSON', () {
    const alarms = [
      Alarm(id: 'a1', hour: 7, minute: 0, label: 'Werk', repeat: RepeatRule.daily()),
      Alarm(id: 'a2', hour: 9, minute: 30, requireMathToDismiss: true, maxSnoozes: 2),
    ];
    final data = BackupData(alarms: alarms);

    final restored = BackupData.fromJsonString(data.toJsonString());

    expect(restored.alarms, alarms);
  });

  test('an empty alarm list round-trips to an empty list', () {
    const data = BackupData(alarms: []);
    final restored = BackupData.fromJsonString(data.toJsonString());
    expect(restored.alarms, isEmpty);
  });

  test('missing alarms field decodes to an empty list rather than throwing', () {
    final restored = BackupData.fromJsonString('{"formatVersion": 1}');
    expect(restored.alarms, isEmpty);
  });
}
