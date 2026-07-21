import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Alarm? _findAlarm(List<Alarm> alarms, String id) {
  for (final a in alarms) {
    if (a.id == id) return a;
  }
  return null;
}

/// Full-screen view shown when an alarm or timer fires. Deliberately blocks
/// the back gesture/button — dismissing must be a conscious action.
class RingingScreen extends ConsumerWidget {
  final RingingRef ringingRef;

  const RingingScreen({super.key, required this.ringingRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isAlarm = ringingRef.kind == RingingKind.alarm;
    final label = switch (ringingRef.kind) {
      RingingKind.alarm =>
        _findAlarm(ref.watch(alarmsProvider).valueOrNull ?? const [], ringingRef.refId)?.label,
      RingingKind.timer => null,
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAlarm ? Icons.alarm_rounded : Icons.timer_rounded,
                  size: 96,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 24),
                Text(
                  isAlarm ? l10n.alarmRingingTitle : l10n.timerFinishedTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                if (label != null && label.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(),
                if (isAlarm)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _snooze(context, ref),
                      child: Text(l10n.snooze),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _dismiss(context, ref),
                    child: Text(l10n.dismiss),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final scheduler = ref.read(schedulerServiceProvider);
    final l10n = AppLocalizations.of(context);

    if (ringingRef.kind == RingingKind.alarm) {
      await scheduler.cancelAlarm(ringingRef.refId);
      final alarm = _findAlarm(ref.read(alarmsProvider).valueOrNull ?? const [], ringingRef.refId);
      if (alarm != null) {
        if (alarm.repeat.repeats) {
          await scheduler.scheduleNext(
            alarm,
            from: DateTime.now(),
            notificationTitle: l10n.alarmRingingTitle,
            notificationBody: alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label,
            stopButtonLabel: l10n.dismiss,
          );
        } else {
          await ref.read(alarmsProvider.notifier).disableAfterOneShot(alarm.id);
        }
      }
    } else {
      await scheduler.cancelTimer(ringingRef.refId);
      await ref.read(timersProvider.notifier).remove(ringingRef.refId);
    }

    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze(BuildContext context, WidgetRef ref) async {
    final alarm = _findAlarm(ref.read(alarmsProvider).valueOrNull ?? const [], ringingRef.refId);
    if (alarm == null) return;
    final l10n = AppLocalizations.of(context);
    await ref.read(schedulerServiceProvider).snooze(
          alarm,
          notificationTitle: l10n.alarmRingingTitle,
          notificationBody: alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label,
          stopButtonLabel: l10n.dismiss,
        );
    if (context.mounted) Navigator.of(context).pop();
  }
}
