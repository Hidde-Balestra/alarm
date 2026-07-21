/// A running or paused countdown timer.
class TimerSession {
  final String id;
  final String label;
  final Duration totalDuration;

  /// Absolute end time while running. Null while paused.
  final DateTime? endAt;

  /// Time left, captured at the moment the timer was paused.
  final Duration remainingWhenPaused;
  final bool paused;

  const TimerSession({
    required this.id,
    required this.totalDuration,
    this.label = '',
    this.endAt,
    this.remainingWhenPaused = Duration.zero,
    this.paused = false,
  });

  factory TimerSession.start({
    required String id,
    required Duration duration,
    String label = '',
  }) {
    return TimerSession(
      id: id,
      label: label,
      totalDuration: duration,
      endAt: DateTime.now().add(duration),
    );
  }

  Duration remaining(DateTime now) {
    if (paused) return remainingWhenPaused;
    final end = endAt;
    if (end == null) return totalDuration;
    final diff = end.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool isFinished(DateTime now) => remaining(now) == Duration.zero;

  TimerSession pause(DateTime now) => TimerSession(
        id: id,
        label: label,
        totalDuration: totalDuration,
        paused: true,
        remainingWhenPaused: remaining(now),
      );

  TimerSession resume() => TimerSession(
        id: id,
        label: label,
        totalDuration: totalDuration,
        paused: false,
        endAt: DateTime.now().add(remainingWhenPaused),
      );

  TimerSession reset() => TimerSession(
        id: id,
        label: label,
        totalDuration: totalDuration,
        endAt: DateTime.now().add(totalDuration),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'totalDurationMs': totalDuration.inMilliseconds,
        'endAt': endAt?.toIso8601String(),
        'remainingWhenPausedMs': remainingWhenPaused.inMilliseconds,
        'paused': paused,
      };

  factory TimerSession.fromJson(Map<String, dynamic> json) => TimerSession(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        totalDuration: Duration(milliseconds: json['totalDurationMs'] as int),
        endAt: json['endAt'] != null ? DateTime.parse(json['endAt'] as String) : null,
        remainingWhenPaused:
            Duration(milliseconds: json['remainingWhenPausedMs'] as int? ?? 0),
        paused: json['paused'] as bool? ?? false,
      );
}
