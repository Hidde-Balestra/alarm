import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/custom_sound.dart';

/// The bundled alarm/timer ringtones every install ships with. Alarms,
/// timers and settings store a plain `String soundId` instead of this enum
/// directly, since a chosen sound may also be a user-uploaded [CustomSound]
/// — see [resolveSoundAssetPath] and [resolveSoundLabel].
enum AppSound { classic, digital, gentle, siren }

extension AppSoundAsset on AppSound {
  String get assetPath => 'assets/sounds/$name.wav';
}

String appSoundLabel(AppLocalizations l10n, AppSound sound) => switch (sound) {
      AppSound.classic => l10n.soundClassic,
      AppSound.digital => l10n.soundDigital,
      AppSound.gentle => l10n.soundGentle,
      AppSound.siren => l10n.soundSiren,
    };

AppSound? bundledSoundById(String id) {
  for (final sound in AppSound.values) {
    if (sound.name == id) return sound;
  }
  return null;
}

CustomSound? _customSoundById(String id, List<CustomSound> customSounds) {
  for (final sound in customSounds) {
    if (sound.id == id) return sound;
  }
  return null;
}

/// Resolves a stored `soundId` to the path the `alarm` plugin should play:
/// a bundled asset path, or a custom sound's app-documents-relative path.
/// Falls back to the classic bundled sound if [soundId] refers to a custom
/// sound that's since been deleted.
String resolveSoundAssetPath(String soundId, List<CustomSound> customSounds) {
  final bundled = bundledSoundById(soundId);
  if (bundled != null) return bundled.assetPath;
  final custom = _customSoundById(soundId, customSounds);
  return custom?.relativePath ?? AppSound.classic.assetPath;
}

/// Resolves a stored `soundId` to a human-readable name for display.
String resolveSoundLabel(
  AppLocalizations l10n,
  String soundId,
  List<CustomSound> customSounds,
) {
  final bundled = bundledSoundById(soundId);
  if (bundled != null) return appSoundLabel(l10n, bundled);
  final custom = _customSoundById(soundId, customSounds);
  return custom?.name ?? appSoundLabel(l10n, AppSound.classic);
}
