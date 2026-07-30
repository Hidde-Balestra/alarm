import 'package:alarm_app/services/file_picker_service.dart';

/// Test double avoiding a real `file_picker` platform channel. Returns
/// [result] (defaulting to a canned picked file) every time, or null to
/// simulate the user cancelling the picker.
class FakeFilePickerService implements FilePickerService {
  final PickedAudioFile? result;

  const FakeFilePickerService({
    this.result = const PickedAudioFile(
      path: '/fake/source/my-sound.mp3',
      name: 'my-sound.mp3',
      extension: 'mp3',
    ),
  });

  @override
  Future<PickedAudioFile?> pickAudioFile() async => result;
}
