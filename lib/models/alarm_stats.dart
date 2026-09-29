import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/missed_alarms.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';

/// A summary of alarm-ringing activity computed purely from the (capped,
/// most-recent) history log — see `StorageService.historyLimit`. This is
/// "recent activity", not a long-term trend, since the log itself doesn't
/// keep more than that.
class AlarmStats {
  final int rangCount;
  final int dismissedWithoutSnoozeCount;
  final int totalSnoozeCount;
  final int missedCount;
  final Duration? averageTimeToDismiss;

  const AlarmStats({
    required this.rangCount,
    required this.dismissedWithoutSnoozeCount,
    required this.totalSnoozeCount,
    required this.missedCount,
    required this.averageTimeToDismiss,
  });
}

/// Walks each alarm "rang" entry forward through the (unsorted) [history]
/// to find how it was resolved: snoozed N times then dismissed, dismissed
/// straight away, or never resolved (missed). A later "rang" entry for the
/// same alarm marks the end of that cycle, in case a dismiss/snooze event
/// went missing from the log for some reason.
AlarmStats computeAlarmStats(List<HistoryEntry> history, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final rangEntries = [
    for (final e in history)
      if (e.kind == RingingKind.alarm && e.action == HistoryAction.rang) e,
  ];

  var dismissedWithoutSnooze = 0;
  var totalSnoozes = 0;
  final dismissDurations = <Duration>[];

  for (final rang in rangEntries) {
    final laterEvents = [
      for (final e in history)
        if (e.kind == rang.kind && e.refId == rang.refId && e.timestamp.isAfter(rang.timestamp))
          e,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var snoozeCount = 0;
    DateTime? dismissedAt;
    for (final event in laterEvents) {
      if (event.action == HistoryAction.rang) break;
      if (event.action == HistoryAction.snoozed) snoozeCount++;
      if (event.action == HistoryAction.dismissed) {
        dismissedAt = event.timestamp;
        break;
      }
    }

    totalSnoozes += snoozeCount;
    if (dismissedAt != null) {
      if (snoozeCount == 0) dismissedWithoutSnooze++;
      dismissDurations.add(dismissedAt.difference(rang.timestamp));
    }
  }

  Duration? averageDismiss;
  if (dismissDurations.isNotEmpty) {
    final totalMs = dismissDurations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    averageDismiss = Duration(milliseconds: totalMs ~/ dismissDurations.length);
  }

  return AlarmStats(
    rangCount: rangEntries.length,
    dismissedWithoutSnoozeCount: dismissedWithoutSnooze,
    totalSnoozeCount: totalSnoozes,
    missedCount: missedEntries(history, now: n).where((e) => e.kind == RingingKind.alarm).length,
    averageTimeToDismiss: averageDismiss,
  );
}
