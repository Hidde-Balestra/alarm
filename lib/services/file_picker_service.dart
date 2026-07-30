import 'package:file_picker/file_picker.dart';

class PickedAudioFile {
  final String path;
  final String name;
  final String extension;

  const PickedAudioFile({required this.path, required this.name, required this.extension});
}

/// Thin wrapper around `file_picker` so the Sounds screen's "upload" flow
/// can be faked in widget tests instead of hitting a real platform channel.
class FilePickerService {
  Future<PickedAudioFile?> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final files = result?.files ?? const [];
    final file = files.isEmpty ? null : files.first;
    if (file == null || file.path == null) return null;
    return PickedAudioFile(
      path: file.path!,
      name: file.name,
      extension: file.extension ?? '',
    );
  }
}
