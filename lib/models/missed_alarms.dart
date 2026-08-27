import 'package:alarm_app/models/history_entry.dart';

/// How long to wait after a "rang" entry before treating it as missed, so an
/// alarm that's still actively ringing/snoozing isn't flagged prematurely.
const missedAlarmWindow = Duration(minutes: 15);

/// Whether [rangEntry] (must be a [HistoryAction.rang] entry) was never
/// followed by a snooze or dismiss for the same alarm/timer — e.g. the phone
/// died, or Do Not Disturb swallowed it. [allEntries] should be the full
/// history list (any order); [now] defaults to the current time.
bool isMissed(HistoryEntry rangEntry, List<HistoryEntry> allEntries, [DateTime? now]) {
  if (rangEntry.action != HistoryAction.rang) return false;
  final n = now ?? DateTime.now();
  if (n.isBefore(rangEntry.timestamp.add(missedAlarmWindow))) return false;
  return !allEntries.any((e) =>
      e.kind == rangEntry.kind &&
      e.refId == rangEntry.refId &&
      e.action != HistoryAction.rang &&
      e.timestamp.isAfter(rangEntry.timestamp));
}

/// All entries in [history] that count as missed — see [isMissed].
List<HistoryEntry> missedEntries(List<HistoryEntry> history, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return [
    for (final entry in history)
      if (isMissed(entry, history, n)) entry,
  ];
}
