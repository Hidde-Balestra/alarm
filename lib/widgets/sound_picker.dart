import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:flutter/material.dart';

/// Compact dropdown for picking one of the bundled [AppSound]s.
class SoundPicker extends StatelessWidget {
  final AppSound value;
  final ValueChanged<AppSound> onChanged;

  const SoundPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButton<AppSound>(
      value: value,
      items: [
        for (final sound in AppSound.values)
          DropdownMenuItem(value: sound, child: Text(appSoundLabel(l10n, sound))),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}
