import 'package:alarm_app/services/sound_preview_service.dart';

/// Test double avoiding a real `audioplayers` platform channel.
class FakeSoundPreviewService implements SoundPreviewService {
  final List<String> playedAssets = [];
  final List<String> playedFiles = [];
  int stopCallCount = 0;

  @override
  Future<void> playAsset(String assetPath) async {
    playedAssets.add(assetPath);
  }

  @override
  Future<void> playFile(String absolutePath) async {
    playedFiles.add(absolutePath);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  void dispose() {}
}
