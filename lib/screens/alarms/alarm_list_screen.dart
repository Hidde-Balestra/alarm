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
      appBar: AppBar(title: Text(l10n.navAlarms)),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (alarms) {
          if (alarms.isEmpty) {
            return _EmptyState(l10n: l10n);
          }
          final upcoming =
              settings.alarmsPaused ? null : nextUpcomingAlarm(alarms, DateTime.now());
          final bedtime = computeBedtime(upcoming, settings.desiredSleepHours);
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
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
