import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navAlarms)),
      body: alarmsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (alarms) {
          if (alarms.isEmpty) {
            return _EmptyState(l10n: l10n);
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: alarms.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _AlarmTile(alarm: alarms[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
    final subtitleParts = [
      repeatSummary(l10n, alarm.repeat),
      if (alarm.label.isNotEmpty) alarm.label,
    ];

    return ListTile(
      onTap: () => AlarmListScreen._openEditor(context, ref, alarm),
      title: Text(
        time,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: alarm.enabled
                  ? null
                  : Theme.of(context).colorScheme.outline,
            ),
      ),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: Switch(
        value: alarm.enabled,
        onChanged: (value) =>
            ref.read(alarmsProvider.notifier).setEnabled(alarm.id, value),
      ),
    );
  }
}
