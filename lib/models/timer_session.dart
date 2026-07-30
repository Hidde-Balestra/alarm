/// A running or paused countdown timer.
class TimerSession {
  final String id;
  final String label;
  final Duration totalDuration;

  /// Either a bundled `AppSound`'s name (e.g. `'digital'`) or a
  /// `CustomSound.id` — see `resolveSoundAssetPath`.
  final String soundId;

  /// Absolute end time while running. Null while paused.
  final DateTime? endAt;

  /// Time left, captured at the moment the timer was paused.
  final Duration remainingWhenPaused;
  final bool paused;

  const TimerSession({
    required this.id,
    required this.totalDuration,
    this.label = '',
    this.soundId = 'digital',
    this.endAt,
    this.remainingWhenPaused = Duration.zero,
    this.paused = false,
  });

  factory TimerSession.start({
    required String id,
    required Duration duration,
    String label = '',
    String soundId = 'digital',
  }) {
    return TimerSession(
      id: id,
      label: label,
      totalDuration: duration,
      soundId: soundId,
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
        soundId: soundId,
        paused: true,
        remainingWhenPaused: remaining(now),
      );

  TimerSession resume() => TimerSession(
        id: id,
        label: label,
        totalDuration: totalDuration,
        soundId: soundId,
        paused: false,
        endAt: DateTime.now().add(remainingWhenPaused),
      );

  TimerSession reset() => TimerSession(
        id: id,
        label: label,
        totalDuration: totalDuration,
        soundId: soundId,
        endAt: DateTime.now().add(totalDuration),
      );

  /// State to fall back to once the timer has rung and been dismissed:
  /// paused at its full original duration, ready for the user to either
  /// restart it (play button) or delete it (trash button) — rather than
  /// disappearing from the list on its own.
  TimerSession readyToRestart() => TimerSession(
        id: id,
        label: label,
        totalDuration: totalDuration,
        soundId: soundId,
        paused: true,
        remainingWhenPaused: totalDuration,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'totalDurationMs': totalDuration.inMilliseconds,
        'sound': soundId,
        'endAt': endAt?.toIso8601String(),
        'remainingWhenPausedMs': remainingWhenPaused.inMilliseconds,
        'paused': paused,
      };

  factory TimerSession.fromJson(Map<String, dynamic> json) => TimerSession(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        totalDuration: Duration(milliseconds: json['totalDurationMs'] as int),
        soundId: json['sound'] as String? ?? 'digital',
        endAt: json['endAt'] != null ? DateTime.parse(json['endAt'] as String) : null,
        remainingWhenPaused:
            Duration(milliseconds: json['remainingWhenPausedMs'] as int? ?? 0),
        paused: json['paused'] as bool? ?? false,
      );
}
