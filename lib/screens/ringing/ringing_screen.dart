import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/models/math_challenge.dart';
import 'package:alarm_app/models/timer_session.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Alarm? _findAlarm(List<Alarm> alarms, String id) {
  for (final a in alarms) {
    if (a.id == id) return a;
  }
  return null;
}

TimerSession? _findTimer(List<TimerSession> timers, String id) {
  for (final t in timers) {
    if (t.id == id) return t;
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
    final alarm = isAlarm
        ? _findAlarm(ref.watch(alarmsProvider).valueOrNull ?? const [], ringingRef.refId)
        : null;
    final label = isAlarm
        ? alarm?.label
        : _findTimer(ref.watch(timersProvider).valueOrNull ?? const [], ringingRef.refId)?.label;
    final canSnooze =
        isAlarm && (alarm == null || alarm.maxSnoozes == 0 || alarm.snoozeCount < alarm.maxSnoozes);

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
                if (canSnooze)
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
                    onPressed: () => _dismiss(context, ref, alarm),
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

  /// Shows the math dialog and waits for it to resolve: `true` once solved
  /// correctly, `false` if the user cancels. A wrong answer keeps the dialog
  /// open (see `_MathChallengeDialogState._submit`) rather than resolving.
  Future<bool> _confirmMathChallenge(BuildContext context) async {
    final solved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MathChallengeDialog(challenge: MathChallenge.generate()),
    );
    return solved ?? false;
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref, Alarm? alarm) async {
    if (alarm != null && alarm.requireMathToDismiss) {
      final solved = await _confirmMathChallenge(context);
      if (!solved) return;
    }
    if (!context.mounted) return;

    final scheduler = ref.read(schedulerServiceProvider);
    final l10n = AppLocalizations.of(context);
    final label = alarm?.label ??
        _findTimer(ref.read(timersProvider).valueOrNull ?? const [], ringingRef.refId)?.label ??
        '';

    if (ringingRef.kind == RingingKind.alarm) {
      await scheduler.cancelAlarm(ringingRef.refId);
      if (alarm != null) {
        await ref.read(alarmsProvider.notifier).resetSnoozeCount(alarm.id);
        if (alarm.repeat.repeats) {
          final customSounds = ref.read(customSoundsProvider).valueOrNull ?? const [];
          await scheduler.scheduleNext(
            alarm,
            from: DateTime.now(),
            soundAssetPath: resolveSoundAssetPath(alarm.soundId, customSounds),
            notificationTitle: l10n.alarmRingingTitle,
            notificationBody: alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label,
            stopButtonLabel: l10n.dismiss,
          );
        } else {
          await ref.read(alarmsProvider.notifier).disableAfterOneShot(alarm.id);
        }
      }
    } else {
      // Left in the list (paused, full duration) rather than deleted, so the
      // user can restart or manually remove it — see TimersNotifier.finish.
      await ref.read(timersProvider.notifier).finish(ringingRef.refId);
    }

    await ref.read(historyProvider.notifier).record(
          HistoryEntry(
            id: _uuid.v4(),
            kind: ringingRef.kind,
            refId: ringingRef.refId,
            label: label,
            action: HistoryAction.dismissed,
            timestamp: DateTime.now(),
          ),
        );

    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze(BuildContext context, WidgetRef ref) async {
    final alarm = _findAlarm(ref.read(alarmsProvider).valueOrNull ?? const [], ringingRef.refId);
    if (alarm == null) return;
    final l10n = AppLocalizations.of(context);
    final customSounds = ref.read(customSoundsProvider).valueOrNull ?? const [];
    await ref.read(schedulerServiceProvider).snooze(
          alarm,
          soundAssetPath: resolveSoundAssetPath(alarm.soundId, customSounds),
          notificationTitle: l10n.alarmRingingTitle,
          notificationBody: alarm.label.isEmpty ? l10n.alarmRingingTitle : alarm.label,
          stopButtonLabel: l10n.dismiss,
        );
    await ref.read(alarmsProvider.notifier).incrementSnoozeCount(alarm.id);
    await ref.read(historyProvider.notifier).record(
          HistoryEntry(
            id: _uuid.v4(),
            kind: RingingKind.alarm,
            refId: alarm.id,
            label: alarm.label,
            action: HistoryAction.snoozed,
            timestamp: DateTime.now(),
          ),
        );
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Blocks dismissal until [challenge] is answered correctly. Pops `true` on
/// a correct answer, `false` if the user cancels.
class _MathChallengeDialog extends StatefulWidget {
  final MathChallenge challenge;

  const _MathChallengeDialog({required this.challenge});

  @override
  State<_MathChallengeDialog> createState() => _MathChallengeDialogState();
}

class _MathChallengeDialogState extends State<_MathChallengeDialog> {
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.challenge.check(_controller.text)) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _wrong = true);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mathChallengeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.challenge.question} = ?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              errorText: _wrong ? l10n.mathChallengeWrongAnswer : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.dismiss)),
      ],
    );
  }
}
