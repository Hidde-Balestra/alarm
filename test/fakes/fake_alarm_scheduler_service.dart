import 'package:alarm/utils/alarm_set.dart';
import 'package:alarm_app/models/alarm.dart' as model;
import 'package:alarm_app/services/alarm_scheduler_service.dart';

/// Test double that never touches the real `alarm` plugin (which needs
/// platform channels unavailable in widget tests). Records calls so tests
/// can assert on scheduling behavior without a real OS alarm.
class FakeAlarmSchedulerService implements AlarmSchedulerService {
  final List<String> scheduledAlarmIds = [];
  final List<String> cancelledAlarmIds = [];
  final List<String> scheduledTimerIds = [];
  final List<String> cancelledTimerIds = [];

  @override
  Future<void> init() async {}

  @override
  Stream<AlarmSet> get ringing => const Stream.empty();

  @override
  Future<void> scheduleNext(
    model.Alarm alarm, {
    required DateTime from,
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    final next = alarm.enabled ? alarm.nextOccurrence(from) : null;
    if (next == null) {
      cancelledAlarmIds.add(alarm.id);
    } else {
      scheduledAlarmIds.add(alarm.id);
    }
  }

  @override
  Future<void> snooze(
    model.Alarm alarm, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    scheduledAlarmIds.add(alarm.id);
  }

  @override
  Future<void> cancelAlarm(String alarmId) async {
    cancelledAlarmIds.add(alarmId);
  }

  @override
  Future<void> scheduleTimer(
    String timerId,
    DateTime end, {
    required String notificationTitle,
    required String notificationBody,
    required String stopButtonLabel,
  }) async {
    scheduledTimerIds.add(timerId);
  }

  @override
  Future<void> cancelTimer(String timerId) async {
    cancelledTimerIds.add(timerId);
  }

  @override
  Future<void> stopRingingByPayload(String? payload) async {}
}
