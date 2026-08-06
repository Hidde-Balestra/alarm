import 'dart:convert';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/custom_sound.dart';
import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/timer_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists alarms, timers, settings and custom sounds as JSON in
/// [SharedPreferences].
class StorageService {
  static const _alarmsKey = 'alarms';
  static const _settingsKey = 'app_settings';
  static const _timersKey = 'timers';
  static const _customSoundsKey = 'custom_sounds';
  static const _historyKey = 'history';

  /// How many entries the history log keeps — old ones fall off the end.
  static const historyLimit = 50;

  Future<List<Alarm>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alarmsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Alarm.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_alarmsKey, raw);
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<TimerSession>> loadTimers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_timersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TimerSession.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveTimers(List<TimerSession> timers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(timers.map((t) => t.toJson()).toList());
    await prefs.setString(_timersKey, raw);
  }

  Future<List<CustomSound>> loadCustomSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customSoundsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CustomSound.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveCustomSounds(List<CustomSound> sounds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sounds.map((s) => s.toJson()).toList());
    await prefs.setString(_customSoundsKey, raw);
  }

  Future<List<HistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveHistory(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final bounded = entries.length > historyLimit
        ? entries.sublist(0, historyLimit)
        : entries;
    final raw = jsonEncode(bounded.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, raw);
  }
}
