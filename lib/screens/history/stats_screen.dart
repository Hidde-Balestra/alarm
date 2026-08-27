import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm_stats.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A summary of recent alarm activity, computed from the history log. See
/// `AlarmStats` for why this is "recent", not a long-term trend.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsScreenTitle)),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (history) {
          final stats = computeAlarmStats(history);
          if (stats.rangCount == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_outlined,
                        size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(l10n.statsEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.statsSubtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _StatTile(
                icon: Icons.notifications_active_outlined,
                label: l10n.statsRangCount,
                value: '${stats.rangCount}',
              ),
              _StatTile(
                icon: Icons.check_circle_outline,
                label: l10n.statsDismissedWithoutSnooze,
                value: '${stats.dismissedWithoutSnoozeCount}',
              ),
              _StatTile(
                icon: Icons.snooze_outlined,
                label: l10n.statsTotalSnoozes,
                value: '${stats.totalSnoozeCount}',
              ),
              if (stats.averageTimeToDismiss != null)
                _StatTile(
                  icon: Icons.timer_outlined,
                  label: l10n.statsAverageTimeToDismiss,
                  value: formatCompactDuration(l10n, stats.averageTimeToDismiss!),
                ),
              _StatTile(
                icon: Icons.notifications_off_outlined,
                label: l10n.statsMissedCount,
                value: '${stats.missedCount}',
                highlighted: stats.missedCount > 0,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        highlighted ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
