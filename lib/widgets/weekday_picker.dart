import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// Row of 7 toggleable day chips. Uses ISO weekday numbers (1 = Monday .. 7 = Sunday).
class WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const WeekdayPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = <int, String>{
      DateTime.monday: l10n.weekdayMonShort,
      DateTime.tuesday: l10n.weekdayTueShort,
      DateTime.wednesday: l10n.weekdayWedShort,
      DateTime.thursday: l10n.weekdayThuShort,
      DateTime.friday: l10n.weekdayFriShort,
      DateTime.saturday: l10n.weekdaySatShort,
      DateTime.sunday: l10n.weekdaySunShort,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in labels.keys)
          FilterChip(
            label: Text(labels[day]!),
            selected: selected.contains(day),
            onSelected: (isSelected) {
              final updated = {...selected};
              if (isSelected) {
                updated.add(day);
              } else {
                updated.remove(day);
              }
              onChanged(updated);
            },
          ),
      ],
    );
  }
}
