import 'package:alarm_app/services/reminder_notification_service.dart';

/// Test double that never touches the real `flutter_local_notifications`
/// plugin (which needs platform channels unavailable in widget tests).
/// Records calls so tests can assert on scheduling behavior.
class FakeReminderNotificationService implements ReminderNotificationService {
  final Set<String> scheduledAlarmIds = {};
  final Set<String> cancelledAlarmIds = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleReminder({
    required String alarmId,
    required DateTime occurrence,
    required String title,
    required String body,
    required String skipActionLabel,
  }) async {
    scheduledAlarmIds.add(alarmId);
    cancelledAlarmIds.remove(alarmId);
  }

  @override
  Future<void> cancelReminder(String alarmId) async {
    cancelledAlarmIds.add(alarmId);
    scheduledAlarmIds.remove(alarmId);
  }
}
