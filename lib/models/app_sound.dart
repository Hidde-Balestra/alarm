import 'package:alarm_app/l10n/gen/app_localizations.dart';

/// The bundled alarm/timer ringtones a user can pick between.
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
