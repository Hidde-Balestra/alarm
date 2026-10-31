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

  /// How many of the most recent alarm rings in a row were dismissed
  /// without snoozing. A snooze or a missed ring ends the streak; a ring
  /// that's still in progress is left out rather than counted either way.
  final int currentNoSnoozeStreak;

  /// The longest such run anywhere in the (recent) history.
  final int bestNoSnoozeStreak;

  const AlarmStats({
    required this.rangCount,
    required this.dismissedWithoutSnoozeCount,
    required this.totalSnoozeCount,
    required this.missedCount,
    required this.averageTimeToDismiss,
    this.currentNoSnoozeStreak = 0,
    this.bestNoSnoozeStreak = 0,
  });
}

/// How one "rang" entry got resolved.
enum _Outcome { cleanDismiss, snoozedThenDismissed, missed, pending }

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
  ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  var dismissedWithoutSnooze = 0;
  var totalSnoozes = 0;
  final dismissDurations = <Duration>[];
  final outcomes = <_Outcome>[];
  // A snoozed alarm logs a fresh "rang" when it goes off again; that ring
  // continues the same wake-up rather than starting a clean new one.
  final snoozedUnresolved = <String>{};

  for (final rang in rangEntries) {
    final laterEvents = [
      for (final e in history)
        if (e.kind == rang.kind && e.refId == rang.refId && e.timestamp.isAfter(rang.timestamp))
          e,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var snoozeCount = 0;
    DateTime? dismissedAt;
    var supersededByNextRing = false;
    for (final event in laterEvents) {
      if (event.action == HistoryAction.rang) {
        supersededByNextRing = true;
        break;
      }
      if (event.action == HistoryAction.snoozed) snoozeCount++;
      if (event.action == HistoryAction.dismissed) {
        dismissedAt = event.timestamp;
        break;
      }
    }

    totalSnoozes += snoozeCount;
    final continuesSnooze = snoozedUnresolved.remove(rang.refId);
    if (dismissedAt != null) {
      if (snoozeCount == 0) dismissedWithoutSnooze++;
      dismissDurations.add(dismissedAt.difference(rang.timestamp));
      outcomes.add(snoozeCount == 0 && !continuesSnooze
          ? _Outcome.cleanDismiss
          : _Outcome.snoozedThenDismissed);
    } else if (snoozeCount > 0) {
      snoozedUnresolved.add(rang.refId);
      outcomes.add(_Outcome.snoozedThenDismissed);
    } else {
      // [isMissed] alone sees a later ring's dismiss as resolving this one
      // too; for the streak, being overtaken by the next ring unanswered
      // means this one was missed.
      final missed = supersededByNextRing || isMissed(rang, history, n);
      outcomes.add(missed ? _Outcome.missed : _Outcome.pending);
    }
  }

  Duration? averageDismiss;
  if (dismissDurations.isNotEmpty) {
    final totalMs = dismissDurations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    averageDismiss = Duration(milliseconds: totalMs ~/ dismissDurations.length);
  }

  var run = 0;
  var best = 0;
  for (final outcome in outcomes) {
    if (outcome == _Outcome.pending) continue;
    run = outcome == _Outcome.cleanDismiss ? run + 1 : 0;
    if (run > best) best = run;
  }

  return AlarmStats(
    rangCount: rangEntries.length,
    dismissedWithoutSnoozeCount: dismissedWithoutSnooze,
    totalSnoozeCount: totalSnoozes,
    missedCount: missedEntries(history, now: n).where((e) => e.kind == RingingKind.alarm).length,
    averageTimeToDismiss: averageDismiss,
    currentNoSnoozeStreak: run,
    bestNoSnoozeStreak: best,
  );
}
