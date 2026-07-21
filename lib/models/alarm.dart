import 'package:alarm_app/models/app_sound.dart';
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
  final AppSound sound;

  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.enabled = true,
    this.repeat = const RepeatRule.none(),
    this.vibrate = true,
    this.snoozeMinutes = 9,
    this.sound = AppSound.classic,
  });

  DateTime? nextOccurrence(DateTime from) =>
      repeat.nextOccurrence(from, hour: hour, minute: minute);

  Alarm copyWith({
    String? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    RepeatRule? repeat,
    bool? vibrate,
    int? snoozeMinutes,
    AppSound? sound,
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
      sound: sound ?? this.sound,
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
        'sound': sound.name,
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
        sound: AppSound.values.byName(json['sound'] as String? ?? 'classic'),
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
      other.sound == sound;

  @override
  int get hashCode =>
      Object.hash(id, hour, minute, label, enabled, repeat, vibrate, snoozeMinutes, sound);
}
