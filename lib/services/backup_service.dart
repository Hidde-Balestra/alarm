import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Thin wrapper around `file_picker`'s save/open dialogs for alarm
/// export/import, so it can be faked in widget tests instead of hitting a
/// real platform channel — same pattern as `FilePickerService`.
class BackupService {
  /// Opens a save dialog and writes [jsonContent] to the chosen location.
  /// Returns whether a file was actually saved (false if the user cancelled).
  Future<bool> exportToFile(String jsonContent) async {
    final fileName =
        'alarm_backup_${DateTime.now().toIso8601String().split('T').first}.json';
    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(jsonContent)),
    );
    return path != null;
  }

  /// Opens a file picker and returns the picked file's text content, or
  /// null if the user cancelled.
  Future<String?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final files = result?.files ?? const [];
    if (files.isEmpty) return null;
    final file = files.first;
    if (file.bytes != null) return utf8.decode(file.bytes!);
    if (file.path != null) return File(file.path!).readAsString();
    return null;
  }
}
