import 'dart:async';
import 'dart:ui' as ui;

import 'package:alarm/utils/alarm_set.dart' as plugin;
import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/upcoming_alarm.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/home_shell.dart';
import 'package:alarm_app/screens/ringing/ringing_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/alarm_sync_coordinator.dart';
import 'package:alarm_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final navigatorKey = GlobalKey<NavigatorState>();

Locale resolveEffectiveLocale(AppSettings settings) {
  final requested = settings.locale;
  if (requested != null) return requested;
  final deviceLocale = ui.PlatformDispatcher.instance.locale;
  final supported = AppLocalizations.supportedLocales
      .map((l) => l.languageCode)
      .toSet();
  if (supported.contains(deviceLocale.languageCode)) {
    return Locale(deviceLocale.languageCode);
  }
  return const Locale('en');
}

/// Formats a time-of-day for the homescreen widget. Deliberately
/// context-free (unlike `formatTimeOfDay`, which needs `MaterialLocalizations`
/// via `BuildContext`): this runs from `syncNow`, called from a `ref.listen`
/// callback registered on `AlarmApp` itself — a context above `MaterialApp`
/// in the tree, where `Localizations.of` can't resolve anything.
String _formatWidgetTime(int hour, int minute, Locale locale) {
  final time = DateTime(2000, 1, 1, hour, minute);
  return DateFormat.jm(locale.toString()).format(time);
}

class AlarmApp extends ConsumerStatefulWidget {
  const AlarmApp({super.key});

  @override
  ConsumerState<AlarmApp> createState() => _AlarmAppState();
}

class _AlarmAppState extends ConsumerState<AlarmApp> {
  StreamSubscription<plugin.AlarmSet>? _ringingSub;
  bool _showingRingScreen = false;
  bool _initStarted = false;

  void _ensureInit() {
    if (_initStarted) return;
    _initStarted = true;
    unawaited(_init());
  }

  Future<void> _init() async {
    final scheduler = ref.read(schedulerServiceProvider);
    await scheduler.init();
    _ringingSub = scheduler.ringing.listen(_onRingingChanged);
  }

  void _onRingingChanged(plugin.AlarmSet alarmSet) {
    if (_showingRingScreen || alarmSet.alarms.isEmpty) return;
    final settings = alarmSet.alarms.first;
    final ringingRef = RingingRef.tryDecode(settings.payload);
    if (ringingRef == null) return;

    _showingRingScreen = true;
    unawaited(ref.read(historyProvider.notifier).record(
          HistoryEntry(
            id: _uuid.v4(),
            kind: ringingRef.kind,
            refId: ringingRef.refId,
            label: _labelFor(ringingRef),
            action: HistoryAction.rang,
            timestamp: DateTime.now(),
          ),
        ));
    // Guarantees the ringing screen is visible/usable even if the device was
    // fully locked and asleep when the alarm fired — see LockscreenService.
    unawaited(ref.read(lockscreenServiceProvider).showOverLockscreen());
    navigatorKey.currentState
        ?.push(
          MaterialPageRoute(
            builder: (_) => RingingScreen(ringingRef: ringingRef),
            fullscreenDialog: true,
          ),
        )
        .then((_) {
      _showingRingScreen = false;
      unawaited(ref.read(lockscreenServiceProvider).restoreLockscreen());
    });
  }

  String _labelFor(RingingRef ringingRef) {
    if (ringingRef.kind == RingingKind.alarm) {
      final alarms = ref.read(alarmsProvider).valueOrNull ?? const [];
      for (final a in alarms) {
        if (a.id == ringingRef.refId) return a.label;
      }
    } else {
      final timers = ref.read(timersProvider).valueOrNull ?? const [];
      for (final t in timers) {
        if (t.id == ringingRef.refId) return t.label;
      }
    }
    return '';
  }

  @override
  void dispose() {
    _ringingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureInit();

    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final locale = resolveEffectiveLocale(settings);

    void syncNow() {
      final alarms = ref.read(alarmsProvider).valueOrNull;
      final customSounds = ref.read(customSoundsProvider).valueOrNull;
      if (alarms == null || customSounds == null) return;
      final paused = ref.read(settingsProvider).valueOrNull?.alarmsPaused ?? false;
      unawaited(
        syncAlarmsWithScheduler(
          alarms: alarms,
          customSounds: customSounds,
          scheduler: ref.read(schedulerServiceProvider),
          l10n: lookupAppLocalizations(locale),
          paused: paused,
        ),
      );

      final upcoming = paused ? null : nextUpcomingAlarm(alarms, DateTime.now());
      unawaited(
        ref.read(homeWidgetServiceProvider).updateNextAlarm(
              timeText: upcoming != null
                  ? _formatWidgetTime(upcoming.alarm.hour, upcoming.alarm.minute, locale)
                  : null,
              labelText: upcoming?.alarm.label,
            ),
      );
    }

    // Re-sync whenever the alarm list changes, or when the custom sound
    // catalog or pause setting changes (e.g. a sound an alarm points to gets
    // deleted, or "pause all" gets toggled).
    ref.listen(alarmsProvider, (previous, next) => syncNow());
    ref.listen(customSoundsProvider, (previous, next) => syncNow());
    ref.listen(
      settingsProvider.select((s) => s.valueOrNull?.alarmsPaused),
      (previous, next) => syncNow(),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: settings.themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const HomeShell(),
    );
  }
}
