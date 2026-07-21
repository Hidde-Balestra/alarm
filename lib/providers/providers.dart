import 'dart:async';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/timer_session.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:alarm_app/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// --- Services -------------------------------------------------------------
// Plain Providers so tests can override them with fakes/mocks.

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final schedulerServiceProvider =
    Provider<AlarmSchedulerService>((ref) => AlarmSchedulerService());

final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());

/// Ticks once a second so widgets showing a live countdown can rebuild.
final clockProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

// --- Settings ---------------------------------------------------------------

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(storageServiceProvider).loadSettings();

  Future<void> _update(AppSettings Function(AppSettings) transform) async {
    final current = state.valueOrNull ?? const AppSettings();
    final updated = transform(current);
    state = AsyncData(updated);
    await ref.read(storageServiceProvider).saveSettings(updated);
  }

  Future<void> setThemeMode(ThemeMode mode) => _update((s) => s.copyWith(themeMode: mode));

  Future<void> setLanguage(AppLanguage language) =>
      _update((s) => s.copyWith(language: language));

  Future<void> setDefaultSnoozeMinutes(int minutes) =>
      _update((s) => s.copyWith(defaultSnoozeMinutes: minutes));

  Future<void> setDefaultVibrate(bool vibrate) =>
      _update((s) => s.copyWith(defaultVibrate: vibrate));
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// --- Alarms -----------------------------------------------------------------

class AlarmsNotifier extends AsyncNotifier<List<Alarm>> {
  @override
  Future<List<Alarm>> build() => ref.watch(storageServiceProvider).loadAlarms();

  List<Alarm> _sorted(List<Alarm> alarms) => [...alarms]
    ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

  Future<void> _persist(List<Alarm> alarms) async {
    state = AsyncData(alarms);
    await ref.read(storageServiceProvider).saveAlarms(alarms);
  }

  String newAlarmId() => _uuid.v4();

  Future<void> upsert(Alarm alarm) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((a) => a.id == alarm.id);
    final updated = [...current];
    if (idx >= 0) {
      updated[idx] = alarm;
    } else {
      updated.add(alarm);
    }
    await _persist(_sorted(updated));
  }

  Future<void> remove(String id) async {
    await ref.read(schedulerServiceProvider).cancelAlarm(id);
    final updated = (state.valueOrNull ?? []).where((a) => a.id != id).toList();
    await _persist(updated);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final current = state.valueOrNull ?? [];
    final updated = [
      for (final a in current)
        if (a.id == id) a.copyWith(enabled: enabled) else a,
    ];
    await _persist(updated);
  }

  /// Called when an alarm without repeat has finished ringing: it doesn't
  /// recur, so it goes back to disabled rather than staying "on" forever.
  Future<void> disableAfterOneShot(String id) => setEnabled(id, false);
}

final alarmsProvider = AsyncNotifierProvider<AlarmsNotifier, List<Alarm>>(AlarmsNotifier.new);

// --- Timers -------------------------------------------------------------------

class TimersNotifier extends AsyncNotifier<List<TimerSession>> {
  @override
  Future<List<TimerSession>> build() => ref.watch(storageServiceProvider).loadTimers();

  Future<void> _persist(List<TimerSession> timers) async {
    state = AsyncData(timers);
    await ref.read(storageServiceProvider).saveTimers(timers);
  }

  String newTimerId() => _uuid.v4();

  Future<void> add(TimerSession timer) async {
    final updated = <TimerSession>[...(state.valueOrNull ?? const <TimerSession>[]), timer];
    await _persist(updated);
  }

  Future<void> updateTimer(TimerSession timer) async {
    final current = state.valueOrNull ?? const <TimerSession>[];
    final updated = [
      for (final t in current)
        if (t.id == timer.id) timer else t,
    ];
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    await ref.read(schedulerServiceProvider).cancelTimer(id);
    final current = state.valueOrNull ?? const <TimerSession>[];
    final updated = current.where((t) => t.id != id).toList();
    await _persist(updated);
  }

  TimerSession _require(String id) {
    final current = state.valueOrNull ?? const <TimerSession>[];
    return current.firstWhere((t) => t.id == id);
  }

  Future<void> start({
    required String id,
    required Duration duration,
    required String label,
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final timer = TimerSession.start(id: id, duration: duration, label: label);
    await add(timer);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          timer.endAt!,
          notificationTitle: notificationTitle,
          notificationBody: notificationBody,
          stopButtonLabel: stopButtonLabel,
        );
  }

  Future<void> pause(String id) async {
    final paused = _require(id).pause(DateTime.now());
    await updateTimer(paused);
    await ref.read(schedulerServiceProvider).cancelTimer(id);
  }

  Future<void> resume(
    String id, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final resumed = _require(id).resume();
    await updateTimer(resumed);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          resumed.endAt!,
          notificationTitle: notificationTitle,
          notificationBody: notificationBody,
          stopButtonLabel: stopButtonLabel,
        );
  }

  Future<void> reset(
    String id, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final resetTimer = _require(id).reset();
    await updateTimer(resetTimer);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          resetTimer.endAt!,
          notificationTitle: notificationTitle,
          notificationBody: notificationBody,
          stopButtonLabel: stopButtonLabel,
        );
  }
}

final timersProvider = AsyncNotifierProvider<TimersNotifier, List<TimerSession>>(
  TimersNotifier.new,
);
