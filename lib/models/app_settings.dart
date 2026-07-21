import 'package:flutter/material.dart';

/// Supported app languages. `system` follows the device locale, falling back
/// to English if the device language isn't Dutch or English.
enum AppLanguage { system, dutch, english }

class AppSettings {
  final ThemeMode themeMode;
  final AppLanguage language;
  final int defaultSnoozeMinutes;
  final bool defaultVibrate;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.system,
    this.defaultSnoozeMinutes = 9,
    this.defaultVibrate = true,
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
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      defaultVibrate: defaultVibrate ?? this.defaultVibrate,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'language': language.name,
        'defaultSnoozeMinutes': defaultSnoozeMinutes,
        'defaultVibrate': defaultVibrate,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.byName(json['themeMode'] as String? ?? 'system'),
        language: AppLanguage.values.byName(json['language'] as String? ?? 'system'),
        defaultSnoozeMinutes: json['defaultSnoozeMinutes'] as int? ?? 9,
        defaultVibrate: json['defaultVibrate'] as bool? ?? true,
      );
}
