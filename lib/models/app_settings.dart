import 'package:flutter/material.dart';

/// Supported app languages. `system` follows the device locale, falling back
/// to English if the device language isn't Dutch or English.
enum AppLanguage { system, dutch, english }

class AppSettings {
  final ThemeMode themeMode;
  final AppLanguage language;
  final int defaultSnoozeMinutes;
  final bool defaultVibrate;

  /// Either a bundled `AppSound`'s name or a `CustomSound.id`.
  final String defaultAlarmSoundId;
  final String defaultTimerSoundId;

  final int defaultVolumeRampSeconds;
  final bool defaultRequireMathToDismiss;
  final int defaultMaxSnoozes;

  /// When true, every alarm is cancelled at the OS level without touching
  /// individual `enabled` flags — a manual "pause everything" switch for
  /// e.g. a holiday, turned back off manually (see `AlarmSchedulerService`
  /// reliability notes for why this is manual-only, not date-based).
  final bool alarmsPaused;

  /// Desired hours of sleep, used to compute the bedtime-reminder card.
  final double desiredSleepHours;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.system,
    this.defaultSnoozeMinutes = 9,
    this.defaultVibrate = true,
    this.defaultAlarmSoundId = 'classic',
    this.defaultTimerSoundId = 'digital',
    this.defaultVolumeRampSeconds = 0,
    this.defaultRequireMathToDismiss = false,
    this.defaultMaxSnoozes = 0,
    this.alarmsPaused = false,
    this.desiredSleepHours = 8,
  });

  Locale? get locale => switch (language) {
        AppLanguage.system => null,
        AppLanguage.dutch => const Locale('nl'),
        AppLanguage.english => const Locale('en'),
      };

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    int? defaultSnoozeMinutes,
    bool? defaultVibrate,
    String? defaultAlarmSoundId,
    String? defaultTimerSoundId,
    int? defaultVolumeRampSeconds,
    bool? defaultRequireMathToDismiss,
    int? defaultMaxSnoozes,
    bool? alarmsPaused,
    double? desiredSleepHours,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      defaultVibrate: defaultVibrate ?? this.defaultVibrate,
      defaultAlarmSoundId: defaultAlarmSoundId ?? this.defaultAlarmSoundId,
      defaultTimerSoundId: defaultTimerSoundId ?? this.defaultTimerSoundId,
      defaultVolumeRampSeconds: defaultVolumeRampSeconds ?? this.defaultVolumeRampSeconds,
      defaultRequireMathToDismiss:
          defaultRequireMathToDismiss ?? this.defaultRequireMathToDismiss,
      defaultMaxSnoozes: defaultMaxSnoozes ?? this.defaultMaxSnoozes,
      alarmsPaused: alarmsPaused ?? this.alarmsPaused,
      desiredSleepHours: desiredSleepHours ?? this.desiredSleepHours,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'language': language.name,
        'defaultSnoozeMinutes': defaultSnoozeMinutes,
        'defaultVibrate': defaultVibrate,
        'defaultAlarmSound': defaultAlarmSoundId,
        'defaultTimerSound': defaultTimerSoundId,
        'defaultVolumeRampSeconds': defaultVolumeRampSeconds,
        'defaultRequireMathToDismiss': defaultRequireMathToDismiss,
        'defaultMaxSnoozes': defaultMaxSnoozes,
        'alarmsPaused': alarmsPaused,
        'desiredSleepHours': desiredSleepHours,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.byName(json['themeMode'] as String? ?? 'system'),
        language: AppLanguage.values.byName(json['language'] as String? ?? 'system'),
        defaultSnoozeMinutes: json['defaultSnoozeMinutes'] as int? ?? 9,
        defaultVibrate: json['defaultVibrate'] as bool? ?? true,
        defaultAlarmSoundId: json['defaultAlarmSound'] as String? ?? 'classic',
        defaultTimerSoundId: json['defaultTimerSound'] as String? ?? 'digital',
        defaultVolumeRampSeconds: json['defaultVolumeRampSeconds'] as int? ?? 0,
        defaultRequireMathToDismiss: json['defaultRequireMathToDismiss'] as bool? ?? false,
        defaultMaxSnoozes: json['defaultMaxSnoozes'] as int? ?? 0,
        alarmsPaused: json['alarmsPaused'] as bool? ?? false,
        desiredSleepHours: (json['desiredSleepHours'] as num?)?.toDouble() ?? 8,
      );
}
