import 'dart:async';
import 'dart:ui' as ui;

import 'package:alarm/utils/alarm_set.dart' as plugin;
import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/home_shell.dart';
import 'package:alarm_app/screens/ringing/ringing_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/alarm_sync_coordinator.dart';
import 'package:alarm_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    navigatorKey.currentState
        ?.push(
          MaterialPageRoute(
            builder: (_) => RingingScreen(ringingRef: ringingRef),
            fullscreenDialog: true,
          ),
        )
        .then((_) => _showingRingScreen = false);
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

    ref.listen(alarmsProvider, (previous, next) {
      final alarms = next.valueOrNull;
      if (alarms == null) return;
      unawaited(
        syncAlarmsWithScheduler(
          alarms: alarms,
          scheduler: ref.read(schedulerServiceProvider),
          l10n: lookupAppLocalizations(locale),
        ),
      );
    });

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
