import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/bedtime.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/models/upcoming_alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final from = DateTime(2026, 7, 21, 20, 0);

  group('nextUpcomingAlarm', () {
    test('returns null when there are no alarms', () {
      expect(nextUpcomingAlarm(const [], from), isNull);
    });

    test('ignores disabled alarms', () {
      const alarm = Alarm(id: 'a', hour: 21, minute: 0, enabled: false, repeat: RepeatRule.daily());
      expect(nextUpcomingAlarm([alarm], from), isNull);
    });

    test('picks the soonest occurrence across multiple alarms', () {
      const early = Alarm(id: 'early', hour: 21, minute: 0, repeat: RepeatRule.daily());
      const late = Alarm(id: 'late', hour: 23, minute: 0, repeat: RepeatRule.daily());

      final result = nextUpcomingAlarm([late, early], from);

      expect(result?.alarm.id, 'early');
      expect(result?.at, DateTime(2026, 7, 21, 21, 0));
    });

    test('accounts for a skipped occurrence', () {
      const rule = RepeatRule.daily();
      final skipped = rule.nextOccurrence(from, hour: 21, minute: 0)!;
      final alarm = Alarm(id: 'a', hour: 21, minute: 0, repeat: rule, skippedOccurrence: skipped);

      final result = nextUpcomingAlarm([alarm], from);

      expect(result?.at, DateTime(2026, 7, 22, 21, 0));
    });
  });

  group('computeBedtime', () {
    test('returns null when there is no upcoming alarm', () {
      expect(computeBedtime(null, 8), isNull);
    });

    test('subtracts the desired sleep duration from the alarm time', () {
      const alarm = Alarm(id: 'a', hour: 6, minute: 30);
      final upcoming = UpcomingAlarm(alarm, DateTime(2026, 7, 22, 6, 30));

      expect(computeBedtime(upcoming, 8), DateTime(2026, 7, 21, 22, 30));
    });

    test('supports fractional hours', () {
      const alarm = Alarm(id: 'a', hour: 7, minute: 0);
      final upcoming = UpcomingAlarm(alarm, DateTime(2026, 7, 22, 7, 0));

      expect(computeBedtime(upcoming, 7.5), DateTime(2026, 7, 21, 23, 30));
    });
  });
}
