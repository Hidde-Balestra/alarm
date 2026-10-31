import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/services/reminder_notification_service.dart';
import 'package:alarm_app/widgets/format_helpers.dart';
import 'package:flutter/material.dart';

/// The "waking up" options — sunrise light, "are you awake?" check,
/// good-morning screen and holiday skipping — shared by the alarm editor
/// (per alarm) and Settings (defaults for new alarms).
class WakeUpOptions extends StatelessWidget {
  final int sunriseMinutes;
  final ValueChanged<int> onSunriseMinutesChanged;
  final bool wakeUpCheck;
  final ValueChanged<bool> onWakeUpCheckChanged;
  final bool showGoodMorning;
  final ValueChanged<bool> onShowGoodMorningChanged;
  final bool skipHolidays;
  final ValueChanged<bool> onSkipHolidaysChanged;

  /// Hides the holiday toggle, e.g. for a one-shot alarm it doesn't apply to.
  final bool showHolidayOption;

  final EdgeInsetsGeometry? contentPadding;

  const WakeUpOptions({
    super.key,
    required this.sunriseMinutes,
    required this.onSunriseMinutesChanged,
    required this.wakeUpCheck,
    required this.onWakeUpCheckChanged,
    required this.showGoodMorning,
    required this.onShowGoodMorningChanged,
    required this.skipHolidays,
    required this.onSkipHolidaysChanged,
    this.showHolidayOption = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A value saved from a since-removed option still needs a menu entry.
    final sunriseOptions = {...sunriseMinuteOptions, sunriseMinutes}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: contentPadding,
          title: Text(l10n.sunriseLabel),
          subtitle: Text(l10n.sunriseHint),
          trailing: DropdownButton<int>(
            value: sunriseMinutes,
            items: [
              for (final minutes in sunriseOptions)
                DropdownMenuItem(value: minutes, child: Text(sunriseOptionLabel(l10n, minutes))),
            ],
            onChanged: (value) {
              if (value != null) onSunriseMinutesChanged(value);
            },
          ),
        ),
        SwitchListTile(
          contentPadding: contentPadding,
          title: Text(l10n.wakeUpCheckLabel),
          subtitle: Text(l10n.wakeUpCheckHint(wakeCheckRingDelay.inMinutes)),
          isThreeLine: true,
          value: wakeUpCheck,
          onChanged: onWakeUpCheckChanged,
        ),
        SwitchListTile(
          contentPadding: contentPadding,
          title: Text(l10n.goodMorningLabel),
          subtitle: Text(l10n.goodMorningHint),
          value: showGoodMorning,
          onChanged: onShowGoodMorningChanged,
        ),
        if (showHolidayOption)
          SwitchListTile(
            contentPadding: contentPadding,
            title: Text(l10n.skipHolidaysLabel),
            subtitle: Text(l10n.skipHolidaysHint),
            value: skipHolidays,
            onChanged: onSkipHolidaysChanged,
          ),
      ],
    );
  }
}
