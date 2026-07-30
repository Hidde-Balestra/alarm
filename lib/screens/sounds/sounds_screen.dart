import 'dart:async';

import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/models/custom_sound.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/sound_preview_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen sound picker: lists the bundled sounds plus any
/// user-uploaded ones, with tap-to-preview and the ability to upload more.
/// Tapping a row pops the screen with that sound's id selected.
class SoundsScreen extends ConsumerStatefulWidget {
  final String selectedId;

  const SoundsScreen({super.key, required this.selectedId});

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  String? _playingId;
  bool _uploading = false;

  // Captured in initState rather than read via `ref` inside dispose(),
  // since Riverpod's `ref` can no longer be used once a widget is disposed.
  late final SoundPreviewService _preview;

  @override
  void initState() {
    super.initState();
    _preview = ref.read(soundPreviewServiceProvider);
  }

  @override
  void dispose() {
    unawaited(_preview.stop());
    super.dispose();
  }

  Future<void> _togglePreviewBundled(AppSound sound) async {
    final preview = _preview;
    if (_playingId == sound.name) {
      await preview.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = sound.name);
    await preview.playAsset(sound.assetPath);
  }

  Future<void> _togglePreviewCustom(CustomSound sound) async {
    final preview = _preview;
    if (_playingId == sound.id) {
      await preview.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = sound.id);
    final absolutePath =
        await ref.read(customSoundServiceProvider).absolutePath(sound.relativePath);
    await preview.playFile(absolutePath);
  }

  Future<void> _upload() async {
    final picked = await ref.read(filePickerServiceProvider).pickAudioFile();
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final sound = await ref.read(customSoundsProvider.notifier).addFromFile(picked);
      if (mounted) Navigator.of(context).pop(sound.id);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteCustom(CustomSound sound) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteSoundConfirm(sound.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(customSoundsProvider.notifier).remove(sound.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customSoundsAsync = ref.watch(customSoundsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.soundsScreenTitle)),
      body: ListView(
        children: [
          for (final sound in AppSound.values)
            ListTile(
              leading: IconButton(
                icon: Icon(_playingId == sound.name ? Icons.stop : Icons.play_arrow),
                onPressed: () => _togglePreviewBundled(sound),
              ),
              title: Text(appSoundLabel(l10n, sound)),
              trailing: widget.selectedId == sound.name
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(sound.name),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.customSoundsSectionTitle,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          customSoundsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$error'),
            ),
            data: (customSounds) {
              if (customSounds.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    l10n.customSoundsEmptyHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final sound in customSounds)
                    ListTile(
                      leading: IconButton(
                        icon: Icon(_playingId == sound.id ? Icons.stop : Icons.play_arrow),
                        onPressed: () => _togglePreviewCustom(sound),
                      ),
                      title: Text(sound.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.selectedId == sound.id)
                            Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.delete,
                            onPressed: () => _deleteCustom(sound),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pop(sound.id),
                    ),
                ],
              );
            },
          ),
          ListTile(
            leading: _uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            title: Text(l10n.uploadSoundButton),
            onTap: _uploading ? null : _upload,
          ),
        ],
      ),
    );
  }
}
