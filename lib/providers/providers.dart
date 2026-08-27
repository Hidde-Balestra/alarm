import 'dart:async';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/models/custom_sound.dart';
import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/stopwatch_state.dart';
import 'package:alarm_app/models/timer_session.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/backup_service.dart';
import 'package:alarm_app/services/custom_sound_service.dart';
import 'package:alarm_app/services/file_picker_service.dart';
import 'package:alarm_app/services/home_widget_service.dart';
import 'package:alarm_app/services/lockscreen_service.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:alarm_app/services/sound_preview_service.dart';
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

final lockscreenServiceProvider =
    Provider<LockscreenService>((ref) => LockscreenService());

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final customSoundServiceProvider =
    Provider<CustomSoundService>((ref) => CustomSoundService());

final filePickerServiceProvider = Provider<FilePickerService>((ref) => FilePickerService());

final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) => HomeWidgetService());

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

final soundPreviewServiceProvider =
    Provider<SoundPreviewService>((ref) => SoundPreviewService());

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

  Future<void> setDefaultAlarmSoundId(String soundId) =>
      _update((s) => s.copyWith(defaultAlarmSoundId: soundId));

  Future<void> setDefaultTimerSoundId(String soundId) =>
      _update((s) => s.copyWith(defaultTimerSoundId: soundId));

  Future<void> setDefaultVolumeRampSeconds(int seconds) =>
      _update((s) => s.copyWith(defaultVolumeRampSeconds: seconds));

  Future<void> setDefaultRequireMathToDismiss(bool value) =>
      _update((s) => s.copyWith(defaultRequireMathToDismiss: value));

  Future<void> setDefaultMaxSnoozes(int count) =>
      _update((s) => s.copyWith(defaultMaxSnoozes: count));

  Future<void> setAlarmsPaused(bool paused) =>
      _update((s) => s.copyWith(alarmsPaused: paused));

  Future<void> setDesiredSleepHours(double hours) =>
      _update((s) => s.copyWith(desiredSleepHours: hours));
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// --- Custom sounds ------------------------------------------------------------

class CustomSoundsNotifier extends AsyncNotifier<List<CustomSound>> {
  @override
  Future<List<CustomSound>> build() => ref.watch(storageServiceProvider).loadCustomSounds();

  Future<void> _persist(List<CustomSound> sounds) async {
    state = AsyncData(sounds);
    await ref.read(storageServiceProvider).saveCustomSounds(sounds);
  }

  /// Copies [file] into app storage and adds it to the list.
  Future<CustomSound> addFromFile(PickedAudioFile file) async {
    final relativePath =
        await ref.read(customSoundServiceProvider).importFile(file.path, file.extension);
    final sound = CustomSound(id: _uuid.v4(), name: file.name, relativePath: relativePath);
    final current = await future;
    await _persist([...current, sound]);
    return sound;
  }

  Future<void> remove(String id) async {
    final current = await future;
    CustomSound? target;
    for (final sound in current) {
      if (sound.id == id) target = sound;
    }
    await _persist(current.where((s) => s.id != id).toList());
    if (target != null) {
      await ref.read(customSoundServiceProvider).deleteFile(target.relativePath);
    }
  }
}

final customSoundsProvider = AsyncNotifierProvider<CustomSoundsNotifier, List<CustomSound>>(
  CustomSoundsNotifier.new,
);

// --- Alarms -----------------------------------------------------------------

class AlarmsNotifier extends AsyncNotifier<List<Alarm>> {
  @override
  Future<List<Alarm>> build() async {
    final alarms = await ref.watch(storageServiceProvider).loadAlarms();
    // Clear any skippedOccurrence that's already in the past — see
    // Alarm.effectiveNextOccurrence for why this self-heals instead of
    // silently skipping the occurrence after the one the user meant.
    final now = DateTime.now();
    final sanitized = [
      for (final a in alarms)
        if (a.skippedOccurrence != null && a.skippedOccurrence!.isBefore(now))
          a.copyWith(clearSkippedOccurrence: true)
        else
          a,
    ];
    return sanitized;
  }

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

  Future<void> _updateOne(String id, Alarm Function(Alarm) transform) async {
    final current = await future;
    final updated = [
      for (final a in current)
        if (a.id == id) transform(a) else a,
    ];
    await _persist(updated);
  }

  Future<void> incrementSnoozeCount(String id) =>
      _updateOne(id, (a) => a.copyWith(snoozeCount: a.snoozeCount + 1));

  Future<void> resetSnoozeCount(String id) =>
      _updateOne(id, (a) => a.copyWith(snoozeCount: 0));

  /// Marks the alarm's next occurrence (as of now) to be skipped, e.g. the
  /// "skip tomorrow" action on a repeating alarm.
  Future<void> skipNext(String id) => _updateOne(id, (a) {
        final next = a.nextOccurrence(DateTime.now());
        if (next == null) return a;
        return a.copyWith(skippedOccurrence: next);
      });

  /// Undoes [skipNext].
  Future<void> unskipNext(String id) =>
      _updateOne(id, (a) => a.copyWith(clearSkippedOccurrence: true));

  /// Adds [imported] alongside the current alarms rather than replacing
  /// them, each with a freshly generated id (and reset snooze/skip state)
  /// so a backup restore can never collide with — or silently overwrite —
  /// alarms already on this device. Returns how many were added.
  Future<int> importAlarms(List<Alarm> imported) async {
    final current = await future;
    final withFreshIds = [
      for (final a in imported)
        a.copyWith(
          id: newAlarmId(),
          snoozeCount: 0,
          clearSkippedOccurrence: true,
        ),
    ];
    await _persist(_sorted([...current, ...withFreshIds]));
    return withFreshIds.length;
  }
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

  Future<String> _resolveSoundPath(String soundId) async {
    final customSounds = await ref.read(customSoundsProvider.notifier).future;
    return resolveSoundAssetPath(soundId, customSounds);
  }

  Future<void> start({
    required String id,
    required Duration duration,
    required String label,
    required String soundId,
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final timer = TimerSession.start(id: id, duration: duration, label: label, soundId: soundId);
    await add(timer);
    await ref.read(schedulerServiceProvider).scheduleTimer(
          id,
          timer.endAt!,
          soundAssetPath: await _resolveSoundPath(soundId),
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
          soundAssetPath: await _resolveSoundPath(resumed.soundId),
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
          soundAssetPath: await _resolveSoundPath(resetTimer.soundId),
          notificationTitle: notificationTitle,
          notificationBody: notificationBody,
          stopButtonLabel: stopButtonLabel,
        );
  }

  /// Called once a timer has rung and the user dismissed it: rather than
  /// disappearing, it goes back to a paused, full-duration state so it stays
  /// in the list ready to restart (or be deleted manually).
  Future<void> finish(String id) async {
    await ref.read(schedulerServiceProvider).cancelTimer(id);
    final current = await _require(id);
    await updateTimer(current.readyToRestart());
  }
}

final timersProvider = AsyncNotifierProvider<TimersNotifier, List<TimerSession>>(
  TimersNotifier.new,
);

// --- History --------------------------------------------------------------

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() => ref.watch(storageServiceProvider).loadHistory();

  /// Adds [entry] to the front of the log, trimmed to
  /// [StorageService.historyLimit] most-recent entries.
  Future<void> record(HistoryEntry entry) async {
    final current = await future;
    final updated = [entry, ...current];
    final bounded = updated.length > StorageService.historyLimit
        ? updated.sublist(0, StorageService.historyLimit)
        : updated;
    state = AsyncData(bounded);
    await ref.read(storageServiceProvider).saveHistory(bounded);
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
  HistoryNotifier.new,
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
