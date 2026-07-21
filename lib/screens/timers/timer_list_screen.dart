import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/timer_session.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimerListScreen extends ConsumerWidget {
  const TimerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timersAsync = ref.watch(timersProvider);
    // Drives periodic rebuilds so the countdown text stays live.
    ref.watch(clockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTimer)),
      body: timersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('$error')),
        data: (timers) {
          if (timers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(l10n.timerEmptyTitle, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: timers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _TimerCard(timer: timers[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'timerListFab',
        onPressed: () => _showAddTimerDialog(context, ref),
        tooltip: l10n.addTimer,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddTimerDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final labelController = TextEditingController();
    int hours = 0;
    int minutes = 5;
    int seconds = 0;

    final duration = await showDialog<Duration>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addTimer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NumberSpinner(
                    label: l10n.hoursShort,
                    value: hours,
                    max: 23,
                    onChanged: (v) => setState(() => hours = v),
                  ),
                  _NumberSpinner(
                    label: l10n.minutesUnitShort,
                    value: minutes,
                    max: 59,
                    onChanged: (v) => setState(() => minutes = v),
                  ),
                  _NumberSpinner(
                    label: l10n.secondsShort,
                    value: seconds,
                    max: 59,
                    onChanged: (v) => setState(() => seconds = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: labelController,
                decoration: InputDecoration(labelText: l10n.timerLabelHint),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: (hours == 0 && minutes == 0 && seconds == 0)
                  ? null
                  : () => Navigator.of(context).pop(
                        Duration(hours: hours, minutes: minutes, seconds: seconds),
                      ),
              child: Text(l10n.start),
            ),
          ],
        ),
      ),
    );

    if (duration == null || !context.mounted) return;
    final notifier = ref.read(timersProvider.notifier);
    await notifier.start(
      id: notifier.newTimerId(),
      duration: duration,
      label: labelController.text.trim(),
      notificationTitle: l10n.timerFinishedTitle,
      notificationBody: labelController.text.trim().isEmpty
          ? l10n.timerFinishedTitle
          : labelController.text.trim(),
      stopButtonLabel: l10n.dismiss,
    );
  }
}

class _NumberSpinner extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberSpinner({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: () => onChanged(value >= max ? 0 : value + 1),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => onChanged(value <= 0 ? max : value - 1),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TimerCard extends ConsumerWidget {
  final TimerSession timer;

  const _TimerCard({required this.timer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final remaining = timer.remaining(now);
    final progress = timer.totalDuration.inMilliseconds == 0
        ? 0.0
        : 1 - (remaining.inMilliseconds / timer.totalDuration.inMilliseconds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timer.label.isNotEmpty)
              Text(timer.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(formatTimerClock(remaining), style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress.clamp(0, 1)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.reset,
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => ref.read(timersProvider.notifier).reset(
                        timer.id,
                        notificationTitle: l10n.timerFinishedTitle,
                        notificationBody:
                            timer.label.isEmpty ? l10n.timerFinishedTitle : timer.label,
                        stopButtonLabel: l10n.dismiss,
                      ),
                ),
                IconButton(
                  tooltip: timer.paused ? l10n.resume : l10n.pause,
                  icon: Icon(timer.paused ? Icons.play_arrow : Icons.pause),
                  onPressed: () {
                    final notifier = ref.read(timersProvider.notifier);
                    if (timer.paused) {
                      notifier.resume(
                        timer.id,
                        notificationTitle: l10n.timerFinishedTitle,
                        notificationBody:
                            timer.label.isEmpty ? l10n.timerFinishedTitle : timer.label,
                        stopButtonLabel: l10n.dismiss,
                      );
                    } else {
                      notifier.pause(timer.id);
                    }
                  },
                ),
                IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(timersProvider.notifier).remove(timer.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
