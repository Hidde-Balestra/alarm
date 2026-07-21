import 'package:alarm_app/models/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepeatType.none / daily', () {
    test('returns today when the time has not passed yet', () {
      final from = DateTime(2026, 7, 21, 6, 0); // Tuesday
      final rule = const RepeatRule.daily();
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 21, 7, 0));
    });

    test('returns tomorrow when the time already passed today', () {
      final from = DateTime(2026, 7, 21, 8, 0);
      final rule = const RepeatRule.daily();
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 22, 7, 0));
    });

    test('is exclusive at the exact trigger moment', () {
      final from = DateTime(2026, 7, 21, 7, 0);
      final rule = const RepeatRule.daily();
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 22, 7, 0));
    });

    test('none behaves like a single upcoming occurrence, same as daily', () {
      final from = DateTime(2026, 7, 21, 6, 0);
      final rule = const RepeatRule.none();
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 21, 7, 0));
    });
  });

  group('RepeatType.weekly', () {
    test('same day when the weekday matches and time has not passed', () {
      final from = DateTime(2026, 7, 21, 6, 0); // Tuesday
      final rule = const RepeatRule.weekly({DateTime.tuesday});
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 21, 7, 0));
    });

    test('rolls to next week when the only selected weekday already passed', () {
      final from = DateTime(2026, 7, 21, 8, 0); // Tuesday, after 07:00
      final rule = const RepeatRule.weekly({DateTime.tuesday});
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 28, 7, 0));
    });

    test('picks the nearest upcoming day among several selected weekdays', () {
      final from = DateTime(2026, 7, 21, 6, 0); // Tuesday
      final rule = const RepeatRule.weekly({DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 22, 7, 0)); // Wednesday
    });

    test('returns null when no weekdays are selected', () {
      final from = DateTime(2026, 7, 21, 6, 0);
      final rule = const RepeatRule.weekly({});
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), isNull);
    });
  });

  group('RepeatType.biweekly ("every other week")', () {
    test('fires on a selected weekday within the anchor ("on") week', () {
      final anchor = DateTime(2026, 7, 20); // Monday, the "on" week
      final from = DateTime(2026, 7, 21, 6, 0); // Tuesday, same week
      final rule = RepeatRule.biweekly({DateTime.monday, DateTime.wednesday, DateTime.friday}, anchor);
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 7, 22, 7, 0)); // Wednesday, still "on" week
    });

    test('skips the entire "off" week and lands two weeks later', () {
      final anchor = DateTime(2026, 7, 20); // Monday, "on" week
      // Friday of the "on" week, after that day's alarm time already passed.
      final from = DateTime(2026, 7, 24, 8, 0);
      final rule = RepeatRule.biweekly({DateTime.monday, DateTime.wednesday, DateTime.friday}, anchor);
      // Next "on" week starts two weeks after the anchor Monday.
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 8, 3, 7, 0));
    });

    test('the "off" week in between never produces an occurrence', () {
      final anchor = DateTime(2026, 7, 20);
      final rule = RepeatRule.biweekly({DateTime.monday, DateTime.wednesday, DateTime.friday}, anchor);
      // Wednesday of the "off" week (2026-07-29) should never be returned.
      final from = DateTime(2026, 7, 24, 8, 0);
      final next = rule.nextOccurrence(from, hour: 7, minute: 0)!;
      expect(next.isBefore(DateTime(2026, 7, 27)) || !next.isBefore(DateTime(2026, 8, 3)), isTrue);
    });

    test('anchor date is normalized to the Monday of its week', () {
      // Anchor given as a Wednesday should behave the same as its Monday.
      final anchorMonday = DateTime(2026, 7, 20);
      final anchorWednesday = DateTime(2026, 7, 22);
      final from = DateTime(2026, 7, 21, 6, 0);
      final ruleFromMonday = RepeatRule.biweekly({DateTime.wednesday}, anchorMonday);
      final ruleFromWednesday = RepeatRule.biweekly({DateTime.wednesday}, anchorWednesday);
      expect(
        ruleFromMonday.nextOccurrence(from, hour: 7, minute: 0),
        ruleFromWednesday.nextOccurrence(from, hour: 7, minute: 0),
      );
    });

    test('parity holds across a year boundary', () {
      final anchor = DateTime(2025, 12, 22); // Monday, "on" week
      final rule = RepeatRule.biweekly({DateTime.monday}, anchor);
      // 2025-12-22 (on), 2026-01-05 (on), 2026-01-19 (on) -- every other Monday.
      final from = DateTime(2026, 1, 1, 0, 0);
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), DateTime(2026, 1, 5, 7, 0));
    });

    test('returns null when no weekdays are selected', () {
      final anchor = DateTime(2026, 7, 20);
      final rule = RepeatRule.biweekly({}, anchor);
      final from = DateTime(2026, 7, 21, 6, 0);
      expect(rule.nextOccurrence(from, hour: 7, minute: 0), isNull);
    });
  });

  group('JSON round-trip', () {
    test('preserves equality for a biweekly rule', () {
      final rule = RepeatRule.biweekly({DateTime.monday, DateTime.friday}, DateTime(2026, 7, 20));
      final restored = RepeatRule.fromJson(rule.toJson());
      expect(restored, rule);
    });

    test('preserves equality for a rule with no repeat', () {
      const rule = RepeatRule.none();
      final restored = RepeatRule.fromJson(rule.toJson());
      expect(restored, rule);
    });
  });
}
