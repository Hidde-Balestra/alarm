import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/bedtime.dart';
import 'package:alarm_app/models/upcoming_alarm.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/alarms/alarm_edit_screen.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlarmListScreen extends ConsumerWidget {
  const AlarmListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alarmsAsync = ref.watch(alarmsProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navAlarms),
        actions: [
          IconButton(
            icon: const Icon(Icons.hotel_outlined),
            tooltip: l10n.napAction,
            onPressed: () => _startNap(context, ref),
          ),
        ],
      ),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (alarms) {
          if (alarms.isEmpty) {
            return Column(
              children: [
                const _WakeCheckBanner(),
                Expanded(child: _EmptyState(l10n: l10n)),
              ],
            );
          }
          final upcoming =
              settings.alarmsPaused ? null : nextUpcomingAlarm(alarms, DateTime.now());
          final bedtime = computeBedtime(upcoming, settings.desiredSleepHours);
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const _WakeCheckBanner(),
              if (settings.alarmsPaused) const _PausedBanner(),
              if (bedtime != null) _BedtimeCard(bedtime: bedtime, upcoming: upcoming!),
              for (final alarm in alarms) _AlarmTile(alarm: alarm),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'alarmListFab',
        onPressed: () => _openEditor(context, ref, null),
        tooltip: l10n.addAlarm,
        child: const Icon(Icons.add),
      ),
    );
  }

  static void _openEditor(BuildContext context, WidgetRef ref, Alarm? alarm) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: alarm)),
    );
  }

  /// Asks how long to nap, then adds a one-shot nap alarm (see
  /// `Alarm.isNap`) using the default sound/vibration/snooze settings.
  static Future<void> _startNap(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.napSheetTitle, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final option in napMinuteOptions)
              ListTile(
                leading: const Icon(Icons.hotel_outlined),
                title: Text(l10n.minutesShort(option)),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (minutes == null || !context.mounted) return;

    final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
    final notifier = ref.read(alarmsProvider.notifier);
    final nap = buildNapAlarm(
      id: notifier.newAlarmId(),
      now: DateTime.now(),
      minutes: minutes,
      label: l10n.napLabel,
      settings: settings,
    );
    await notifier.upsert(nap);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.napSetMessage(formatTimeOfDay(context, nap.hour, nap.minute))),
        action: SnackBarAction(label: l10n.undo, onPressed: () => notifier.remove(nap.id)),
      ),
    );
  }
}

/// Nap lengths offered by the nap button, in minutes.
const napMinuteOptions = [10, 20, 30, 45, 60, 90];

/// A one-shot alarm [minutes] from [now] (rounded up to the next whole
/// minute, since alarms only store hour and minute).
Alarm buildNapAlarm({
  required String id,
  required DateTime now,
  required int minutes,
  required String label,
  required AppSettings settings,
}) {
  var at = now.add(Duration(minutes: minutes));
  if (at.second > 0 || at.millisecond > 0 || at.microsecond > 0) {
    at = DateTime(at.year, at.month, at.day, at.hour, at.minute + 1);
  }
  return Alarm(
    id: id,
    hour: at.hour,
    minute: at.minute,
    label: label,
    vibrate: settings.defaultVibrate,
    snoozeMinutes: settings.defaultSnoozeMinutes,
    soundId: settings.defaultAlarmSoundId,
    volumeRampSeconds: settings.defaultVolumeRampSeconds,
    showGoodMorning: false,
    isNap: true,
  );
}

/// Shown while an "are you awake?" check is waiting for an answer.
class _WakeCheckBanner extends ConsumerWidget {
  const _WakeCheckBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWakeCheckProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    if (pending == null || !now.isBefore(pending.ringsAt)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.notifications_active_outlined, color: scheme.onTertiaryContainer),
        title: Text(
          l10n.wakeCheckBanner(
            formatTimeOfDay(context, pending.ringsAt.hour, pending.ringsAt.minute),
          ),
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        trailing: FilledButton(
          onPressed: () => confirmAwake(ref, pending.alarmId),
          child: Text(l10n.wakeCheckAwakeAction),
        ),
      ),
    );
  }
}

class _PausedBanner extends ConsumerWidget {
  const _PausedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: InkWell(
        onTap: () => ref.read(settingsProvider.notifier).setAlarmsPaused(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.pause_circle_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.alarmsPausedBanner,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _BedtimeCard extends StatelessWidget {
  final DateTime bedtime;
  final UpcomingAlarm upcoming;

  const _BedtimeCard({required this.bedtime, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bedtimeText = formatTimeOfDay(context, bedtime.hour, bedtime.minute);
    final alarmText = formatTimeOfDay(context, upcoming.alarm.hour, upcoming.alarm.minute);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ListTile(
        leading: const Icon(Icons.bedtime_outlined),
        title: Text(l10n.bedtimeCardTitle(bedtimeText)),
        subtitle: Text(l10n.bedtimeCardSubtitle(alarmText)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_off, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(l10n.alarmsEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.alarmsEmptySubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmTile extends ConsumerWidget {
  final Alarm alarm;

  const _AlarmTile({required this.alarm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final time = formatTimeOfDay(context, alarm.hour, alarm.minute);
    final now = DateTime.now();
    final isSkipped =
        alarm.skippedOccurrence != null && alarm.skippedOccurrence!.isAfter(now);
    final subtitleParts = [
      repeatSummary(l10n, alarm.repeat),
      if (alarm.label.isNotEmpty) alarm.label,
    ];
    final next = alarm.enabled ? alarm.effectiveNextOccurrence(now) : null;
    final skippedHoliday = alarm.enabled ? alarm.upcomingSkippedHoliday(now) : null;

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: alarm)),
      ),
      title: Text(
        time,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: alarm.enabled
                  ? null
                  : Theme.of(context).colorScheme.outline,
            ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subtitleParts.join(' • ')),
          if (next != null)
            Text(
              formatNextOccurrence(context, l10n, next),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          if (skippedHoliday != null)
            Text(
              l10n.holidaySkippedLabel(dutchHolidayLabel(l10n, skippedHoliday)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
            ),
          if (isSkipped)
            Text(
              l10n.nextOccurrenceSkippedLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alarm.enabled && alarm.repeat.repeats)
            IconButton(
              icon: Icon(isSkipped ? Icons.event_busy : Icons.event_busy_outlined),
              color: isSkipped ? Theme.of(context).colorScheme.error : null,
              tooltip: isSkipped ? l10n.unskipNextAction : l10n.skipNextAction,
              onPressed: () {
                final notifier = ref.read(alarmsProvider.notifier);
                if (isSkipped) {
                  notifier.unskipNext(alarm.id);
                } else {
                  notifier.skipNext(alarm.id);
                }
              },
            ),
          Switch(
            value: alarm.enabled,
            onChanged: (value) =>
                ref.read(alarmsProvider.notifier).setEnabled(alarm.id, value),
          ),
        ],
      ),
    );
  }
}
