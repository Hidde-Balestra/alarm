import 'package:alarm_app/models/holidays.dart';
import 'package:alarm_app/models/repeat_rule.dart';

/// Sunrise lead-time choices (in minutes) offered in the editor and
/// Settings; `0` means off. See [Alarm.sunriseMinutes].
const sunriseMinuteOptions = [0, 10, 15, 20, 30];

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

  /// How many minutes before ringing the screen starts a slow, silent
  /// "sunrise" — brightening from dark to warm light. `0` means off.
  final int sunriseMinutes;

  /// Whether dismissing arms a follow-up "are you awake?" check: unless the
  /// user confirms within a few minutes, the alarm rings again.
  final bool wakeUpCheck;

  /// Whether a good-morning screen is shown after dismissing.
  final bool showGoodMorning;

  /// Whether a repeating alarm stays silent on Dutch public holidays — see
  /// [dutchHolidayOn]. Ignored for one-shot alarms, which are always for a
  /// specific day the user picked deliberately.
  final bool skipHolidays;

  /// A quick nap alarm from the "nap" button: deleted (not just disabled)
  /// once it's dismissed, so naps don't pile up in the list.
  final bool isNap;

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
    this.sunriseMinutes = 0,
    this.wakeUpCheck = false,
    this.showGoodMorning = true,
    this.skipHolidays = false,
    this.isNap = false,
  });

  DateTime? nextOccurrence(DateTime from) =>
      repeat.nextOccurrence(from, hour: hour, minute: minute);

  bool _isSkippedHoliday(DateTime occurrence) =>
      skipHolidays && repeat.repeats && dutchHolidayOn(occurrence) != null;

  /// Walks forward from [nextOccurrence] past holidays (if [skipHolidays])
  /// and, when [honorSkip], past [skippedOccurrence]. Bounded so a
  /// pathological rule can't loop forever; a real one needs at most a few
  /// steps (e.g. Christmas Day + Boxing Day back to back).
  DateTime? _nextRinging(DateTime from, {required bool honorSkip}) {
    final skipped = skippedOccurrence;
    var next = nextOccurrence(from);
    for (var i = 0; next != null && i < 64; i++) {
      final manuallySkipped = honorSkip && skipped != null && next == skipped;
      if (!manuallySkipped && !_isSkippedHoliday(next)) return next;
      next = repeat.nextOccurrence(next, hour: hour, minute: minute);
    }
    return null;
  }

  /// When this alarm will actually ring next: like [nextOccurrence], but
  /// skipping over [skippedOccurrence] and (if [skipHolidays]) holidays.
  /// Self-healing: a [skippedOccurrence] that's already in the past (e.g.
  /// the app wasn't reopened in time) is simply ignored rather than
  /// skipping the occurrence *after* it too.
  DateTime? effectiveNextOccurrence(DateTime from) {
    final skipped = skippedOccurrence;
    final honorSkip = skipped != null && !skipped.isBefore(from);
    return _nextRinging(from, honorSkip: honorSkip);
  }

  /// The occurrence a "skip next" action should target: the next one that
  /// would actually ring, ignoring any existing manual skip — a holiday the
  /// alarm already stays silent on isn't worth "skipping".
  DateTime? nextOccurrenceSkippingHolidays(DateTime from) =>
      _nextRinging(from, honorSkip: false);

  /// The holiday the very next occurrence falls on, if [skipHolidays] makes
  /// the alarm stay silent then — for a "skipped: King's Day" hint.
  DutchHoliday? upcomingSkippedHoliday(DateTime from) {
    final next = nextOccurrence(from);
    if (next == null || !_isSkippedHoliday(next)) return null;
    return dutchHolidayOn(next);
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
    int? sunriseMinutes,
    bool? wakeUpCheck,
    bool? showGoodMorning,
    bool? skipHolidays,
    bool? isNap,
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
      sunriseMinutes: sunriseMinutes ?? this.sunriseMinutes,
      wakeUpCheck: wakeUpCheck ?? this.wakeUpCheck,
      showGoodMorning: showGoodMorning ?? this.showGoodMorning,
      skipHolidays: skipHolidays ?? this.skipHolidays,
      isNap: isNap ?? this.isNap,
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
        'sunriseMinutes': sunriseMinutes,
        'wakeUpCheck': wakeUpCheck,
        'showGoodMorning': showGoodMorning,
        'skipHolidays': skipHolidays,
        'isNap': isNap,
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
        sunriseMinutes: json['sunriseMinutes'] as int? ?? 0,
        wakeUpCheck: json['wakeUpCheck'] as bool? ?? false,
        showGoodMorning: json['showGoodMorning'] as bool? ?? true,
        skipHolidays: json['skipHolidays'] as bool? ?? false,
        isNap: json['isNap'] as bool? ?? false,
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
      other.skippedOccurrence == skippedOccurrence &&
      other.sunriseMinutes == sunriseMinutes &&
      other.wakeUpCheck == wakeUpCheck &&
      other.showGoodMorning == showGoodMorning &&
      other.skipHolidays == skipHolidays &&
      other.isNap == isNap;

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
        sunriseMinutes,
        wakeUpCheck,
        showGoodMorning,
        skipHolidays,
        isNap,
      );
}
