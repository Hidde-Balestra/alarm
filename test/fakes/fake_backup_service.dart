import 'package:alarm_app/services/backup_service.dart';

/// Test double that never touches the real `file_picker` platform channel.
class FakeBackupService implements BackupService {
  /// Preset content `importFromFile` returns; null simulates the user
  /// cancelling the picker.
  String? importContent;

  /// Whether `exportToFile` should behave as if the user cancelled the
  /// save dialog.
  bool exportCancelled = false;

  String? lastExportedJson;
  int exportCallCount = 0;
  int importCallCount = 0;

  @override
  Future<bool> exportToFile(String jsonContent) async {
    exportCallCount++;
    lastExportedJson = jsonContent;
    return !exportCancelled;
  }

  @override
  Future<String?> importFromFile() async {
    importCallCount++;
    return importContent;
  }
}
