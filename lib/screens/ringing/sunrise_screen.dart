import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sky colors from night to full daylight, evenly spaced over the sunrise.
const _skyStops = [
  Color(0xFF000000),
  Color(0xFF1A0B2E),
  Color(0xFF7A2418),
  Color(0xFFFF8C42),
  Color(0xFFFFF1C9),
];

/// The color at [t] (0..1) along [_skyStops].
Color sunriseColorAt(double t) {
  final clamped = t.clamp(0.0, 1.0);
  final scaled = clamped * (_skyStops.length - 1);
  final index = scaled.floor().clamp(0, _skyStops.length - 2);
  return Color.lerp(_skyStops[index], _skyStops[index + 1], scaled - index)!;
}

/// How far along the sunrise is at [now]: 0 at [startsAt], 1 at [ringsAt].
double sunriseProgress(DateTime startsAt, DateTime ringsAt, DateTime now) {
  final total = ringsAt.difference(startsAt).inMilliseconds;
  if (total <= 0) return 1;
  return (now.difference(startsAt).inMilliseconds / total).clamp(0.0, 1.0);
}

/// A silent "wake-up light": the screen slowly brightens from black through
/// deep red and orange to warm white over `Alarm.sunriseMinutes`, so the
/// alarm itself ideally finds someone already half awake. The real alarm
/// rings on its own schedule regardless; when it does, the app replaces
/// this screen with the ringing one.
class SunriseScreen extends ConsumerWidget {
  final String alarmId;
  final DateTime startsAt;
  final DateTime ringsAt;

  const SunriseScreen({
    super.key,
    required this.alarmId,
    required this.startsAt,
    required this.ringsAt,
  });

  Alarm? _alarm(WidgetRef ref) {
    for (final a in ref.read(alarmsProvider).valueOrNull ?? const <Alarm>[]) {
      if (a.id == alarmId) return a;
    }
    return null;
  }

  /// Woke up before the alarm: make sure it doesn't ring anyway.
  Future<void> _alreadyAwake(BuildContext context, WidgetRef ref) async {
    final alarm = _alarm(ref);
    final notifier = ref.read(alarmsProvider.notifier);
    if (alarm != null) {
      if (alarm.repeat.repeats) {
        await notifier.skipNext(alarm.id);
      } else if (alarm.isNap) {
        await notifier.remove(alarm.id);
      } else {
        await notifier.disableAfterOneShot(alarm.id);
      }
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final progress = sunriseProgress(startsAt, ringsAt, now);
    // The "sun" near the bottom runs a little ahead of the sky around it.
    final sky = sunriseColorAt(progress);
    final sun = sunriseColorAt(progress + 0.25);
    final foreground = progress < 0.6 ? Colors.white70 : const Color(0xFF4E2A12);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 1.2),
            radius: 1.4,
            colors: [sun, sky],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  formatTimeOfDay(context, now.hour, now.minute),
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.sunriseAlarmAt(formatTimeOfDay(context, ringsAt.hour, ringsAt.minute)),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: foreground),
                ),
                const Spacer(flex: 2),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: foreground),
                  onPressed: () => _alreadyAwake(context, ref),
                  child: Text(l10n.sunriseAlreadyAwake),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: foreground),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.sunriseClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
