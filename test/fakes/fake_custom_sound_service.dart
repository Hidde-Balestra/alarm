import 'package:alarm_app/services/custom_sound_service.dart';

/// Test double avoiding real file I/O / `path_provider` platform channels.
class FakeCustomSoundService implements CustomSoundService {
  int _counter = 0;
  final List<String> deletedPaths = [];

  @override
  Future<String> importFile(String sourcePath, String extension) async {
    _counter++;
    final suffix = extension.isEmpty ? '' : '.$extension';
    return 'custom_sounds/fake-$_counter$suffix';
  }

  @override
  Future<void> deleteFile(String relativePath) async {
    deletedPaths.add(relativePath);
  }

  @override
  Future<String> absolutePath(String relativePath) async => '/fake/docs/$relativePath';
}
