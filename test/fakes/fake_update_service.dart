import 'package:alarm_app/services/update_service.dart';

/// Test double avoiding real network calls / url_launcher platform channels.
class FakeUpdateService implements UpdateService {
  final UpdateCheckResult result;
  int openReleasePageCallCount = 0;
  String? lastOpenedUrl;

  FakeUpdateService({
    this.result = const UpdateCheckResult(status: UpdateStatus.upToDate),
  });

  @override
  Future<UpdateCheckResult> checkForUpdate(String currentVersion) async => result;

  @override
  Future<void> openReleasePage(String url) async {
    openReleasePageCallCount++;
    lastOpenedUrl = url;
  }
}
