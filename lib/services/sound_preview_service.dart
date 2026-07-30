import 'package:audioplayers/audioplayers.dart';

/// Plays short previews of bundled/custom sounds on the Sounds screen. Not
/// used for actual alarm/timer ringing — that's the `alarm` plugin's job.
class SoundPreviewService {
  final AudioPlayer _player = AudioPlayer();

  /// [assetPath] as declared in pubspec (e.g. `assets/sounds/classic.wav`).
  Future<void> playAsset(String assetPath) async {
    final withoutPrefix =
        assetPath.startsWith('assets/') ? assetPath.substring('assets/'.length) : assetPath;
    await _player.play(AssetSource(withoutPrefix));
  }

  /// [absolutePath] on the device's filesystem (custom/uploaded sounds).
  Future<void> playFile(String absolutePath) async {
    await _player.play(DeviceFileSource(absolutePath));
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();
}
