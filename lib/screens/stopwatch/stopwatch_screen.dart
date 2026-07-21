import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StopwatchScreen extends ConsumerWidget {
  const StopwatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(stopwatchProvider);
    final notifier = ref.read(stopwatchProvider.notifier);
    final elapsed = state.currentElapsed(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStopwatch)),
      body: Column(
        children: [
          const Spacer(),
          Center(
            child: Text(
              formatStopwatchClock(elapsed),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          if (!state.hasProgress) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.stopwatchEmptyTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: state.running
                      ? notifier.lap
                      : (state.hasProgress ? notifier.reset : null),
                  child: Text(state.running ? l10n.stopwatchLap : l10n.reset),
                ),
                FilledButton(
                  onPressed: state.running ? notifier.pause : notifier.start,
                  child: Text(
                    state.running
                        ? l10n.pause
                        : (state.elapsed > Duration.zero ? l10n.resume : l10n.start),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.laps.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.laps.length,
                    itemBuilder: (context, index) {
                      // Most recent lap first.
                      final lapIndex = state.laps.length - index;
                      final lapTime = state.laps[lapIndex - 1];
                      final previous = lapIndex >= 2 ? state.laps[lapIndex - 2] : Duration.zero;
                      return ListTile(
                        dense: true,
                        title: Text(l10n.stopwatchLapNumber(lapIndex)),
                        trailing: Text(formatStopwatchClock(lapTime - previous)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
