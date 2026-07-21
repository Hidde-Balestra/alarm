import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatTimeOfDay(BuildContext context, int hour, int minute) {
  final time = TimeOfDay(hour: hour, minute: minute);
  return time.format(context);
}

String formatDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(date);
}

/// Human-readable "Next: Mon, Aug 3, 07:00" (or the "pick a day" hint when
/// [next] is null because no weekday is selected yet).
String formatNextOccurrence(BuildContext context, AppLocalizations l10n, DateTime? next) {
  if (next == null) return l10n.nextOccurrenceUnknown;
  final locale = Localizations.localeOf(context).toString();
  final formatted = DateFormat.MMMEd(locale).add_Hm().format(next);
  return l10n.nextOccurrenceLabel(formatted);
}

String repeatSummary(AppLocalizations l10n, RepeatRule repeat) {
  switch (repeat.type) {
    case RepeatType.none:
      return l10n.repeatNever;
    case RepeatType.daily:
      return l10n.repeatDaily;
    case RepeatType.weekly:
    case RepeatType.biweekly:
      final names = <int, String>{
        DateTime.monday: l10n.weekdayMonShort,
        DateTime.tuesday: l10n.weekdayTueShort,
        DateTime.wednesday: l10n.weekdayWedShort,
        DateTime.thursday: l10n.weekdayThuShort,
        DateTime.friday: l10n.weekdayFriShort,
        DateTime.saturday: l10n.weekdaySatShort,
        DateTime.sunday: l10n.weekdaySunShort,
      };
      final sortedDays = repeat.weekdays.toList()..sort();
      final days = sortedDays.map((d) => names[d]).join(', ');
      final prefix = repeat.type == RepeatType.biweekly ? l10n.repeatBiweekly : '';
      if (days.isEmpty) return prefix.isEmpty ? l10n.repeatWeekly : prefix;
      return prefix.isEmpty ? days : '$prefix: $days';
  }
}

/// Compact "1u 30m" / "45m" style duration, reusing the timer unit strings.
String formatCompactDuration(AppLocalizations l10n, Duration duration) {
  final totalMinutes = (duration.inSeconds / 60).ceil();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '$hours${l10n.hoursShort} $minutes${l10n.minutesUnitShort}';
  }
  return '$minutes${l10n.minutesUnitShort}';
}

String formatTimerClock(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final buffer = StringBuffer();
  if (hours > 0) {
    buffer.write('${hours.toString().padLeft(2, '0')}:');
  }
  buffer
    ..write(minutes.toString().padLeft(2, '0'))
    ..write(':')
    ..write(seconds.toString().padLeft(2, '0'));
  return buffer.toString();
}

/// "12:03.4" (mm:ss.d) style, or "1:12:03.4" (h:mm:ss.d) past an hour —
/// stopwatches conventionally show tenths of a second.
String formatStopwatchClock(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final tenths = (d.inMilliseconds.remainder(1000) / 100).floor();
  final buffer = StringBuffer();
  if (hours > 0) {
    buffer.write('$hours:${minutes.toString().padLeft(2, '0')}:');
  } else {
    buffer.write('${minutes.toString().padLeft(2, '0')}:');
  }
  buffer
    ..write(seconds.toString().padLeft(2, '0'))
    ..write('.')
    ..write(tenths);
  return buffer.toString();
}
