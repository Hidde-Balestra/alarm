/// How an alarm repeats.
enum RepeatType { none, daily, weekly, biweekly }

/// Describes when an alarm repeats, including a "every other week" mode.
///
/// [weekdays] uses ISO weekday numbers (1 = Monday .. 7 = Sunday) and applies
/// to [RepeatType.weekly] and [RepeatType.biweekly].
///
/// [anchorDate] is required for [RepeatType.biweekly]: it marks the Monday of
/// an "on" week. A candidate date only counts if the Monday of its week is an
/// even number of weeks away from the Monday of [anchorDate] — that's what
/// makes alternating weeks "on"/"off" instead of firing every week.
class RepeatRule {
  final RepeatType type;
  final Set<int> weekdays;
  final DateTime? anchorDate;

  const RepeatRule._({
    required this.type,
    this.weekdays = const {},
    this.anchorDate,
  });

  const RepeatRule.none() : this._(type: RepeatType.none);

  const RepeatRule.daily() : this._(type: RepeatType.daily);

  const RepeatRule.weekly(Set<int> weekdays)
      : this._(type: RepeatType.weekly, weekdays: weekdays);

  RepeatRule.biweekly(Set<int> weekdays, DateTime anchorDate)
      : this._(
          type: RepeatType.biweekly,
          weekdays: weekdays,
          anchorDate: mondayOf(anchorDate),
        );

  bool get repeats => type != RepeatType.none;

  static DateTime mondayOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  bool _isOnWeek(DateTime candidate) {
    final anchor = anchorDate;
    if (anchor == null) return true;
    final diffDays = mondayOf(candidate).difference(mondayOf(anchor)).inDays;
    return diffDays % 14 == 0;
  }

  /// Returns the next [DateTime] strictly after [from] at which this alarm
  /// should ring, given the alarm's time-of-day ([hour]:[minute]).
  ///
  /// Returns null only when the rule can never fire (e.g. weekly/biweekly
  /// with no weekdays selected).
  DateTime? nextOccurrence(DateTime from, {required int hour, required int minute}) {
    switch (type) {
      case RepeatType.none:
      case RepeatType.daily:
        var candidate = DateTime(from.year, from.month, from.day, hour, minute);
        if (!candidate.isAfter(from)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;

      case RepeatType.weekly:
      case RepeatType.biweekly:
        if (weekdays.isEmpty) return null;
        final startDay = DateTime(from.year, from.month, from.day);
        // 14 days covers a full two-week biweekly cycle, guaranteeing a hit
        // if any weekday is selected.
        for (var i = 0; i <= 14; i++) {
          final day = startDay.add(Duration(days: i));
          final candidate = DateTime(day.year, day.month, day.day, hour, minute);
          if (!candidate.isAfter(from)) continue;
          if (!weekdays.contains(candidate.weekday)) continue;
          if (type == RepeatType.biweekly && !_isOnWeek(candidate)) continue;
          return candidate;
        }
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'weekdays': weekdays.toList(),
        'anchorDate': anchorDate?.toIso8601String(),
      };

  factory RepeatRule.fromJson(Map<String, dynamic> json) {
    final type = RepeatType.values.byName(json['type'] as String);
    final weekdays = (json['weekdays'] as List<dynamic>? ?? const [])
        .map((e) => e as int)
        .toSet();
    final anchorDateStr = json['anchorDate'] as String?;
    return RepeatRule._(
      type: type,
      weekdays: weekdays,
      anchorDate: anchorDateStr != null ? DateTime.parse(anchorDateStr) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.type == type &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays) &&
      other.anchorDate == anchorDate;

  @override
  int get hashCode => Object.hash(type, Object.hashAllUnordered(weekdays), anchorDate);
}
