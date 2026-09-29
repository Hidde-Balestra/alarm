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
}
