/// State for the single stopwatch (unlike alarms/timers, there's only ever
/// one). Kept in memory only — a stopwatch is meant to be watched live, not
/// something that should keep ringing after the app is killed.
class StopwatchState {
  final bool running;

  /// Elapsed time accumulated before the current run (frozen while paused).
  final Duration elapsed;

  /// Wall-clock time the stopwatch was last (re)started. Null while paused.
  final DateTime? startedAt;
  final List<Duration> laps;

  const StopwatchState({
    this.running = false,
    this.elapsed = Duration.zero,
    this.startedAt,
    this.laps = const [],
  });

  Duration currentElapsed(DateTime now) {
    final started = startedAt;
    if (!running || started == null) return elapsed;
    return elapsed + now.difference(started);
  }

  bool get hasProgress => running || elapsed > Duration.zero || laps.isNotEmpty;

  StopwatchState copyWith({
    bool? running,
    Duration? elapsed,
    DateTime? startedAt,
    bool clearStartedAt = false,
    List<Duration>? laps,
  }) {
    return StopwatchState(
      running: running ?? this.running,
      elapsed: elapsed ?? this.elapsed,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      laps: laps ?? this.laps,
    );
  }
}
