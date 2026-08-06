import 'package:alarm_app/services/home_widget_service.dart';

/// Test double that never touches the real `home_widget` plugin (which needs
/// a platform channel unavailable in widget tests).
class FakeHomeWidgetService implements HomeWidgetService {
  String? lastTimeText;
  String? lastLabelText;
  int updateCount = 0;

  @override
  Future<void> updateNextAlarm({String? timeText, String? labelText}) async {
    lastTimeText = timeText;
    lastLabelText = labelText;
    updateCount++;
  }
}
