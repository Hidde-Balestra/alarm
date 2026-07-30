import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Copies picked audio files into the app's documents directory and cleans
/// them up again on delete. Kept separate from [CustomSoundsNotifier] so the
/// notifier itself stays free of real file I/O and is easy to fake in tests.
class CustomSoundService {
  static const _subdirectory = 'custom_sounds';

  /// Copies the file at [sourcePath] into `<app docs>/custom_sounds/` and
  /// returns the new file's path *relative* to the app documents directory
  /// (what the `alarm` plugin expects, since the absolute path can change
  /// across app updates).
  Future<String> importFile(String sourcePath, String extension) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${docsDir.path}/$_subdirectory');
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }
    final suffix = extension.isEmpty ? '' : '.$extension';
    final relativePath = '$_subdirectory/${_uuid.v4()}$suffix';
    await File(sourcePath).copy('${docsDir.path}/$relativePath');
    return relativePath;
  }

  Future<void> deleteFile(String relativePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/$relativePath');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Resolves a stored relative path back to an absolute one, for preview
  /// playback (`DeviceFileSource` needs an absolute path).
  Future<String> absolutePath(String relativePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    return '${docsDir.path}/$relativePath';
  }
}
