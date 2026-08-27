import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/missed_alarms.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

String _actionLabel(AppLocalizations l10n, HistoryAction action) => switch (action) {
      HistoryAction.rang => l10n.historyActionRang,
      HistoryAction.snoozed => l10n.historyActionSnoozed,
      HistoryAction.dismissed => l10n.historyActionDismissed,
    };

IconData _actionIcon(HistoryAction action) => switch (action) {
      HistoryAction.rang => Icons.notifications_active_outlined,
      HistoryAction.snoozed => Icons.snooze_outlined,
      HistoryAction.dismissed => Icons.check_circle_outline,
    };

/// A read-only log of recent alarm/timer ring, snooze and dismiss events —
/// see `HistoryNotifier` for how entries get recorded.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(historyProvider);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyScreenTitle)),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(l10n.historyEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final defaultLabel =
                  entry.kind == RingingKind.alarm ? l10n.navAlarms : l10n.navTimer;
              final title = entry.label.isEmpty ? defaultLabel : entry.label;
              final timestamp = DateFormat.MMMEd(locale).add_Hms().format(entry.timestamp);
              final missed = isMissed(entry, entries);
              final errorColor = Theme.of(context).colorScheme.error;
              return ListTile(
                leading: Icon(
                  missed ? Icons.notifications_off_outlined : _actionIcon(entry.action),
                  color: missed ? errorColor : null,
                ),
                title: Text(title),
                subtitle: Text(
                  '${missed ? l10n.historyActionMissed : _actionLabel(l10n, entry.action)} • $timestamp',
                  style: missed ? TextStyle(color: errorColor) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
