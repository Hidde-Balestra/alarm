import 'dart:async';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/models/stopwatch_state.dart';
import 'package:alarm_app/models/timer_session.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:alarm_app/services/storage_service.dart';
import 'package:alarm_app/services/update_service.dart';
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

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Ticks once a second so widgets showing a live countdown can rebuild.
final clockProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

// --- Settings ---------------------------------------------------------------

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(storageServiceProvider).loadSettings();

  Future<void> _update(AppSettings Function(AppSettings) transform) async {
    // Waiting for `future` (rather than reading `state.valueOrNull`) avoids a
    // race where the initial `build()` load is still in flight: if it
    // resolves *after* we assign `state` below, it would silently overwrite
    // this update with the pre-change value loaded from storage.
    final current = await future;
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

  Future<void> setDefaultAlarmSound(AppSound sound) =>
      _update((s) => s.copyWith(defaultAlarmSound: sound));

  Future<void> setDefaultTimerSound(AppSound sound) =>
      _update((s) => s.copyWith(defaultTimerSound: sound));
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

  // Note: these all read via `await future` rather than `state.valueOrNull`
  // — see the comment on SettingsNotifier._update for why that matters.

  Future<void> upsert(Alarm alarm) async {
    final current = await future;
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
    final current = await future;
    final updated = current.where((a) => a.id != id).toList();
    await _persist(updated);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final current = await future;
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

  // Note: these all read via `await future` rather than `state.valueOrNull`
  // — see the comment on SettingsNotifier._update for why that matters.

  Future<void> add(TimerSession timer) async {
    final current = await future;
    final updated = <TimerSession>[...current, timer];
    await _persist(updated);
  }

  Future<void> updateTimer(TimerSession timer) async {
    final current = await future;
    final updated = [
      for (final t in current)
        if (t.id == timer.id) timer else t,
    ];
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    await ref.read(schedulerServiceProvider).cancelTimer(id);
    final current = await future;
    final updated = current.where((t) => t.id != id).toList();
    await _persist(updated);
  }

  Future<TimerSession> _require(String id) async {
    final current = await future;
    return current.firstWhere((t) => t.id == id);
  }

  Future<void> start({
    required String id,
    required Duration duration,
    required String label,
    required AppSound sound,
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final timer = TimerSession.start(id: id, duration: duration, label: label, sound: sound);
    await add(timer);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          timer.endAt!,
          sound: sound,
          notificationTitle: notificationTitle,
          notificationBody: notificationBody,
          stopButtonLabel: stopButtonLabel,
        );
  }

  Future<void> pause(String id) async {
    final current = await _require(id);
    final paused = current.pause(DateTime.now());
    await updateTimer(paused);
    await ref.read(schedulerServiceProvider).cancelTimer(id);
  }

  Future<void> resume(
    String id, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final current = await _require(id);
    final resumed = current.resume();
    await updateTimer(resumed);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          resumed.endAt!,
          sound: resumed.sound,
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
    final current = await _require(id);
    final resetTimer = current.reset();
    await updateTimer(resetTimer);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          resetTimer.endAt!,
          sound: resetTimer.sound,
          notificationTitle: notificationTitle,
          notificationBody: notificationBody,
          stopButtonLabel: stopButtonLabel,
        );
  }
}

final timersProvider = AsyncNotifierProvider<TimersNotifier, List<TimerSession>>(
  TimersNotifier.new,
);

// --- Stopwatch ----------------------------------------------------------------

class StopwatchNotifier extends Notifier<StopwatchState> {
  Timer? _ticker;

  @override
  StopwatchState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const StopwatchState();
  }

  void _tick() {
    // No field actually changes; copyWith still allocates a new instance,
    // which is what makes Riverpod notify listeners for the live display.
    state = state.copyWith();
  }

  void start() {
    if (state.running) return;
    state = state.copyWith(running: true, startedAt: DateTime.now());
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void pause() {
    if (!state.running) return;
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
      running: false,
      elapsed: state.currentElapsed(DateTime.now()),
      clearStartedAt: true,
    );
  }

  void lap() {
    if (!state.running) return;
    state = state.copyWith(laps: [...state.laps, state.currentElapsed(DateTime.now())]);
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    state = const StopwatchState();
  }
}

final stopwatchProvider = NotifierProvider<StopwatchNotifier, StopwatchState>(
  StopwatchNotifier.new,
);
