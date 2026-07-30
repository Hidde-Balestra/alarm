import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/sounds/sounds_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Row showing the currently chosen sound's name; tapping it opens the full
/// [SoundsScreen] picker (bundled + uploaded sounds, with preview).
class SoundSelectorTile extends ConsumerWidget {
  final String selectedId;
  final ValueChanged<String> onChanged;
  final EdgeInsetsGeometry contentPadding;
  final String? title;

  const SoundSelectorTile({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.contentPadding = EdgeInsets.zero,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final customSounds = ref.watch(customSoundsProvider).valueOrNull ?? const [];
    final label = resolveSoundLabel(l10n, selectedId, customSounds);

    return ListTile(
      contentPadding: contentPadding,
      title: Text(title ?? l10n.soundSectionTitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final picked = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => SoundsScreen(selectedId: selectedId)),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
