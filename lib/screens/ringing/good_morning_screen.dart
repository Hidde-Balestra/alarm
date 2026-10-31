import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/alarm_stats.dart';
import 'package:alarm_app/models/upcoming_alarm.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/reminder_notification_service.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Streaks shorter than this aren't worth celebrating yet.
const _minStreakToShow = 2;

String greetingFor(AppLocalizations l10n, DateTime now) {
  if (now.hour < 12) return l10n.greetingMorning;
  if (now.hour < 18) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}

/// One thought per calendar day, the same all day long.
String quoteOfTheDay(AppLocalizations l10n, DateTime now) {
  final quotes = [
    l10n.morningQuote1,
    l10n.morningQuote2,
    l10n.morningQuote3,
    l10n.morningQuote4,
    l10n.morningQuote5,
    l10n.morningQuote6,
    l10n.morningQuote7,
    l10n.morningQuote8,
  ];
  final dayOfYear = DateTime(now.year, now.month, now.day)
      .difference(DateTime(now.year))
      .inDays;
  return quotes[dayOfYear % quotes.length];
}

/// Shown after dismissing an alarm with `Alarm.showGoodMorning` on: a calm
/// summary to start the day with instead of dropping straight back into the
/// app (or the lock screen).
class GoodMorningScreen extends ConsumerWidget {
  final String alarmId;

  const GoodMorningScreen({super.key, required this.alarmId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final alarms = ref.watch(alarmsProvider).valueOrNull ?? const <Alarm>[];
    final paused = ref.watch(settingsProvider).valueOrNull?.alarmsPaused ?? false;
    final history = ref.watch(historyProvider).valueOrNull ?? const [];

    Alarm? alarm;
    for (final a in alarms) {
      if (a.id == alarmId) alarm = a;
    }
    final streak = computeAlarmStats(history, now: now).currentNoSnoozeStreak;
    final upcoming = paused ? null : nextUpcomingAlarm(alarms, now);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.tertiaryContainer, theme.colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(Icons.wb_sunny_rounded, size: 72, color: theme.colorScheme.tertiary),
                const SizedBox(height: 16),
                Text(
                  greetingFor(l10n, now),
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  formatTimeOfDay(context, now.hour, now.minute),
                  style: theme.textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  DateFormat.yMMMMEEEEd(locale).format(now),
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      quoteOfTheDay(l10n, now),
                      style: theme.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (streak >= _minStreakToShow)
                  _InfoRow(
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.deepOrange,
                    text: l10n.goodMorningStreak(streak),
                  ),
                if (alarm != null && alarm.wakeUpCheck)
                  _InfoRow(
                    icon: Icons.notifications_active_outlined,
                    text: l10n.goodMorningWakeCheckNote(wakeCheckPromptDelay.inMinutes),
                  ),
                if (upcoming != null)
                  _InfoRow(
                    icon: Icons.alarm,
                    text: l10n.goodMorningNextAlarm(
                      DateFormat.MMMEd(locale).add_Hm().format(upcoming.at),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.goodMorningStartDay),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
