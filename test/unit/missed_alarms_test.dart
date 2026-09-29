import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/missed_alarms.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry({
  required String id,
  required HistoryAction action,
  required DateTime timestamp,
  String refId = 'a1',
  RingingKind kind = RingingKind.alarm,
}) =>
    HistoryEntry(id: id, kind: kind, refId: refId, action: action, timestamp: timestamp);

void main() {
  final rangAt = DateTime(2026, 7, 21, 7, 0);

  group('isMissed', () {
    test('a non-rang entry is never missed', () {
      final entry = _entry(id: '1', action: HistoryAction.dismissed, timestamp: rangAt);
      expect(isMissed(entry, [entry], rangAt.add(const Duration(hours: 1))), isFalse);
    });

    test('a fresh ring within the window is not yet missed', () {
      final rang = _entry(id: '1', action: HistoryAction.rang, timestamp: rangAt);
      expect(isMissed(rang, [rang], rangAt.add(const Duration(minutes: 5))), isFalse);
    });

    test('a ring with no follow-up past the window is missed', () {
      final rang = _entry(id: '1', action: HistoryAction.rang, timestamp: rangAt);
      expect(isMissed(rang, [rang], rangAt.add(missedAlarmWindow * 2)), isTrue);
    });

    test('a ring dismissed within the window is not missed', () {
      final rang = _entry(id: '1', action: HistoryAction.rang, timestamp: rangAt);
      final dismissed = _entry(
        id: '2',
        action: HistoryAction.dismissed,
        timestamp: rangAt.add(const Duration(minutes: 2)),
      );
      expect(isMissed(rang, [rang, dismissed], rangAt.add(missedAlarmWindow * 2)), isFalse);
    });

    test('a ring dismissed late (after the window) still counts as handled', () {
      final rang = _entry(id: '1', action: HistoryAction.rang, timestamp: rangAt);
      final dismissed = _entry(
        id: '2',
        action: HistoryAction.dismissed,
        timestamp: rangAt.add(const Duration(hours: 1)),
      );
      expect(isMissed(rang, [rang, dismissed], rangAt.add(const Duration(hours: 2))), isFalse);
    });

    test('a follow-up for a different alarm does not count', () {
      final rang = _entry(id: '1', action: HistoryAction.rang, timestamp: rangAt, refId: 'a1');
      final otherDismissed = _entry(
        id: '2',
        action: HistoryAction.dismissed,
        timestamp: rangAt.add(const Duration(minutes: 1)),
        refId: 'a2',
      );
      expect(
        isMissed(rang, [rang, otherDismissed], rangAt.add(missedAlarmWindow * 2)),
        isTrue,
      );
    });
  });

  group('missedEntries', () {
    test('returns only the missed rang entries', () {
      final missedRing = _entry(id: '1', action: HistoryAction.rang, timestamp: rangAt);
      final handledRing = _entry(
        id: '2',
        action: HistoryAction.rang,
        timestamp: rangAt,
        refId: 'a2',
      );
      final handledDismiss = _entry(
        id: '3',
        action: HistoryAction.dismissed,
        timestamp: rangAt.add(const Duration(minutes: 1)),
        refId: 'a2',
      );
      final now = rangAt.add(missedAlarmWindow * 2);

      final result = missedEntries([missedRing, handledRing, handledDismiss], now: now);

      expect(result, [missedRing]);
    });
  });
}
