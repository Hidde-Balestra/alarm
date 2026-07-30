import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/models/custom_sound.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('resolveSoundLabel', () {
    test('resolves a bundled id to its localized name', () {
      expect(resolveSoundLabel(l10n, 'digital', const []), 'Digital');
    });

    test('resolves a custom id to its stored display name', () {
      const custom = CustomSound(id: 'abc', name: 'Rooster', relativePath: 'custom_sounds/abc.mp3');
      expect(resolveSoundLabel(l10n, 'abc', [custom]), 'Rooster');
    });

    test('falls back to the classic label when the id is unknown', () {
      expect(resolveSoundLabel(l10n, 'deleted-sound', const []), 'Classic');
    });
  });

  group('resolveSoundAssetPath', () {
    test('resolves a bundled id to its asset path', () {
      expect(resolveSoundAssetPath('siren', const []), 'assets/sounds/siren.wav');
    });

    test('resolves a custom id to its stored relative path', () {
      const custom = CustomSound(id: 'abc', name: 'My sound', relativePath: 'custom_sounds/abc.mp3');
      expect(resolveSoundAssetPath('abc', [custom]), 'custom_sounds/abc.mp3');
    });

    test('falls back to classic when the id matches neither bundled nor custom', () {
      expect(resolveSoundAssetPath('deleted-sound', const []), AppSound.classic.assetPath);
    });
  });

  group('bundledSoundById', () {
    test('finds a bundled sound by its enum name', () {
      expect(bundledSoundById('gentle'), AppSound.gentle);
    });

    test('returns null for a non-bundled id', () {
      expect(bundledSoundById('some-custom-uuid'), isNull);
    });
  });
}
