import 'package:alarm_app/models/repeat_rule.dart';

/// A user-configured alarm. Time-of-day plus a [RepeatRule] describing when
/// it recurs; [RepeatRule.nextOccurrence] turns this into the concrete
/// [DateTime] that actually gets scheduled with the OS.
class Alarm {
  final String id;
  final int hour;
  final int minute;
  final String label;
  final bool enabled;
  final RepeatRule repeat;
  final bool vibrate;
  final int snoozeMinutes;

  /// Either a bundled [AppSound]'s name (e.g. `'classic'`) or a
  /// [CustomSound.id] — see `resolveSoundAssetPath`.
  final String soundId;

  /// How long the alarm takes to ramp from silent up to full volume, in
  /// seconds. `0` means it rings at full volume immediately.
  final int volumeRampSeconds;

  /// Whether dismissing (not snoozing) requires solving a generated math
  /// problem first — makes it harder to switch off while half-asleep.
  final bool requireMathToDismiss;

  /// Maximum number of times this alarm can be snoozed before the snooze
  /// button disappears. `0` means unlimited.
  final int maxSnoozes;

  /// How many times the alarm has been snoozed since it last rang from a
  /// fresh (non-snoozed) occurrence. Persisted so it survives the app being
  /// killed between snoozes; reset on dismiss or on a fresh occurrence.
  final int snoozeCount;

  /// The exact next occurrence (as computed by [RepeatRule.nextOccurrence])
  /// that the user asked to skip, if any. See [effectiveNextOccurrence].
  final DateTime? skippedOccurrence;

  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.enabled = true,
    this.repeat = const RepeatRule.none(),
    this.vibrate = true,
    this.snoozeMinutes = 9,
    this.soundId = 'classic',
    this.volumeRampSeconds = 0,
    this.requireMathToDismiss = false,
    this.maxSnoozes = 0,
    this.snoozeCount = 0,
    this.skippedOccurrence,
  });

  DateTime? nextOccurrence(DateTime from) =>
      repeat.nextOccurrence(from, hour: hour, minute: minute);

  /// Like [nextOccurrence], but skips over [skippedOccurrence] if that's
  /// what would otherwise be returned. Self-healing: a [skippedOccurrence]
  /// that's already in the past (e.g. the app wasn't reopened in time) is
  /// simply ignored rather than skipping the occurrence *after* it too.
  DateTime? effectiveNextOccurrence(DateTime from) {
    final next = nextOccurrence(from);
    final skipped = skippedOccurrence;
    if (next == null || skipped == null) return next;
    if (skipped.isBefore(from)) return next;
    if (next != skipped) return next;
    return repeat.nextOccurrence(next, hour: hour, minute: minute);
  }

  Alarm copyWith({
    String? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    RepeatRule? repeat,
    bool? vibrate,
    int? snoozeMinutes,
    String? soundId,
    int? volumeRampSeconds,
    bool? requireMathToDismiss,
    int? maxSnoozes,
    int? snoozeCount,
    DateTime? skippedOccurrence,
    bool clearSkippedOccurrence = false,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      repeat: repeat ?? this.repeat,
      vibrate: vibrate ?? this.vibrate,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      soundId: soundId ?? this.soundId,
      volumeRampSeconds: volumeRampSeconds ?? this.volumeRampSeconds,
      requireMathToDismiss: requireMathToDismiss ?? this.requireMathToDismiss,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      skippedOccurrence:
          clearSkippedOccurrence ? null : (skippedOccurrence ?? this.skippedOccurrence),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'enabled': enabled,
        'repeat': repeat.toJson(),
        'vibrate': vibrate,
        'snoozeMinutes': snoozeMinutes,
        'sound': soundId,
        'volumeRampSeconds': volumeRampSeconds,
        'requireMathToDismiss': requireMathToDismiss,
        'maxSnoozes': maxSnoozes,
        'snoozeCount': snoozeCount,
        'skippedOccurrence': skippedOccurrence?.toIso8601String(),
      };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        label: json['label'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        repeat: json['repeat'] != null
            ? RepeatRule.fromJson(json['repeat'] as Map<String, dynamic>)
            : const RepeatRule.none(),
        vibrate: json['vibrate'] as bool? ?? true,
        snoozeMinutes: json['snoozeMinutes'] as int? ?? 9,
        soundId: json['sound'] as String? ?? 'classic',
        volumeRampSeconds: json['volumeRampSeconds'] as int? ?? 0,
        requireMathToDismiss: json['requireMathToDismiss'] as bool? ?? false,
        maxSnoozes: json['maxSnoozes'] as int? ?? 0,
        snoozeCount: json['snoozeCount'] as int? ?? 0,
        skippedOccurrence: json['skippedOccurrence'] != null
            ? DateTime.parse(json['skippedOccurrence'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      other is Alarm &&
      other.id == id &&
      other.hour == hour &&
      other.minute == minute &&
      other.label == label &&
      other.enabled == enabled &&
      other.repeat == repeat &&
      other.vibrate == vibrate &&
      other.snoozeMinutes == snoozeMinutes &&
      other.soundId == soundId &&
      other.volumeRampSeconds == volumeRampSeconds &&
      other.requireMathToDismiss == requireMathToDismiss &&
      other.maxSnoozes == maxSnoozes &&
      other.snoozeCount == snoozeCount &&
      other.skippedOccurrence == skippedOccurrence;

  @override
  int get hashCode => Object.hash(
        id,
        hour,
        minute,
        label,
        enabled,
        repeat,
        vibrate,
        snoozeMinutes,
        soundId,
        volumeRampSeconds,
        requireMathToDismiss,
        maxSnoozes,
        snoozeCount,
        skippedOccurrence,
      );
}
