import 'package:alarm_app/models/alarm_stats.dart';
import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/missed_alarms.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry(String id, HistoryAction action, DateTime timestamp,
        {String refId = 'a1', RingingKind kind = RingingKind.alarm}) =>
    HistoryEntry(id: id, kind: kind, refId: refId, action: action, timestamp: timestamp);

void main() {
  final t0 = DateTime(2026, 7, 21, 7, 0);

  test('an empty history produces all-zero stats', () {
    final stats = computeAlarmStats(const []);
    expect(stats.rangCount, 0);
    expect(stats.dismissedWithoutSnoozeCount, 0);
    expect(stats.totalSnoozeCount, 0);
    expect(stats.missedCount, 0);
    expect(stats.averageTimeToDismiss, isNull);
  });

  test('a ring dismissed immediately counts as dismissed-without-snooze', () {
    final history = [
      _entry('1', HistoryAction.rang, t0),
      _entry('2', HistoryAction.dismissed, t0.add(const Duration(minutes: 3))),
    ];

    final stats = computeAlarmStats(history, now: t0.add(const Duration(hours: 1)));

    expect(stats.rangCount, 1);
    expect(stats.dismissedWithoutSnoozeCount, 1);
    expect(stats.totalSnoozeCount, 0);
    expect(stats.averageTimeToDismiss, const Duration(minutes: 3));
  });

  test('snoozes before a dismiss are counted and excluded from dismissedWithoutSnooze', () {
    final history = [
      _entry('1', HistoryAction.rang, t0),
      _entry('2', HistoryAction.snoozed, t0.add(const Duration(minutes: 1))),
      _entry('3', HistoryAction.snoozed, t0.add(const Duration(minutes: 10))),
      _entry('4', HistoryAction.dismissed, t0.add(const Duration(minutes: 20))),
    ];

    final stats = computeAlarmStats(history, now: t0.add(const Duration(hours: 1)));

    expect(stats.rangCount, 1);
    expect(stats.dismissedWithoutSnoozeCount, 0);
    expect(stats.totalSnoozeCount, 2);
    expect(stats.averageTimeToDismiss, const Duration(minutes: 20));
  });

  test('a ring never resolved counts as missed and is excluded from the dismiss average', () {
    final history = [_entry('1', HistoryAction.rang, t0)];

    final stats = computeAlarmStats(history, now: t0.add(missedAlarmWindow * 2));

    expect(stats.rangCount, 1);
    expect(stats.missedCount, 1);
    expect(stats.averageTimeToDismiss, isNull);
  });

  test('timer entries are excluded from alarm stats', () {
    final history = [
      _entry('1', HistoryAction.rang, t0, kind: RingingKind.timer),
      _entry('2', HistoryAction.dismissed, t0.add(const Duration(seconds: 5)), kind: RingingKind.timer),
    ];

    final stats = computeAlarmStats(history, now: t0.add(const Duration(hours: 1)));

    expect(stats.rangCount, 0);
  });

  group('no-snooze streak', () {
    /// One morning: a ring, optionally a snooze plus the re-ring it causes
    /// (logged as a fresh "rang", like the app does), then a dismiss.
    List<HistoryEntry> morning(int day, {bool snoozed = false}) {
      final rang = t0.add(Duration(days: day));
      final id = 'd$day';
      return [
        _entry('$id-r', HistoryAction.rang, rang),
        if (snoozed) ...[
          _entry('$id-s', HistoryAction.snoozed, rang.add(const Duration(minutes: 1))),
          _entry('$id-r2', HistoryAction.rang, rang.add(const Duration(minutes: 10))),
        ],
        _entry('$id-d', HistoryAction.dismissed, rang.add(const Duration(minutes: 11))),
      ];
    }

    test('counts consecutive clean dismissals up to now', () {
      final history = [...morning(0), ...morning(1), ...morning(2)];
      final stats = computeAlarmStats(history, now: t0.add(const Duration(days: 3)));
      expect(stats.currentNoSnoozeStreak, 3);
      expect(stats.bestNoSnoozeStreak, 3);
    });

    test('a snoozed morning resets the streak, including its re-ring', () {
      final history = [
        ...morning(0),
        ...morning(1),
        ...morning(2),
        ...morning(3, snoozed: true),
      ];
      final stats = computeAlarmStats(history, now: t0.add(const Duration(days: 4)));
      expect(stats.currentNoSnoozeStreak, 0);
      expect(stats.bestNoSnoozeStreak, 3);
    });

    test('a missed ring breaks the streak, a still-ringing one does not', () {
      final missed = [
        ...morning(0),
        _entry('m', HistoryAction.rang, t0.add(const Duration(days: 1))),
        ...morning(2),
      ];
      expect(
        computeAlarmStats(missed, now: t0.add(const Duration(days: 3))).currentNoSnoozeStreak,
        1,
      );

      final ringingNow = t0.add(const Duration(days: 2));
      final pending = [
        ...morning(0),
        ...morning(1),
        _entry('p', HistoryAction.rang, ringingNow),
      ];
      expect(
        computeAlarmStats(pending, now: ringingNow.add(const Duration(minutes: 1)))
            .currentNoSnoozeStreak,
        2,
      );
    });
  });
}
