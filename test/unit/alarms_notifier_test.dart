import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_alarm_scheduler_service.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        schedulerServiceProvider.overrideWithValue(FakeAlarmSchedulerService()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('incrementSnoozeCount and resetSnoozeCount update the stored alarm', () async {
    final notifier = container.read(alarmsProvider.notifier);
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0);
    await notifier.upsert(alarm);

    await notifier.incrementSnoozeCount('a1');
    await notifier.incrementSnoozeCount('a1');

    var alarms = container.read(alarmsProvider).valueOrNull ?? [];
    expect(alarms.single.snoozeCount, 2);

    await notifier.resetSnoozeCount('a1');

    alarms = container.read(alarmsProvider).valueOrNull ?? [];
    expect(alarms.single.snoozeCount, 0);
  });

  test('skipNext marks the current next occurrence, unskipNext clears it', () async {
    final notifier = container.read(alarmsProvider.notifier);
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0, repeat: RepeatRule.daily());
    await notifier.upsert(alarm);

    await notifier.skipNext('a1');

    var alarms = container.read(alarmsProvider).valueOrNull ?? [];
    final expectedSkip = alarm.nextOccurrence(DateTime.now());
    expect(alarms.single.skippedOccurrence, expectedSkip);
    expect(alarms.single.effectiveNextOccurrence(DateTime.now()), isNot(expectedSkip));

    await notifier.unskipNext('a1');

    alarms = container.read(alarmsProvider).valueOrNull ?? [];
    expect(alarms.single.skippedOccurrence, isNull);
  });

  test('build() sanitizes a skippedOccurrence that is already in the past', () async {
    final pastSkip = DateTime.now().subtract(const Duration(days: 1));
    final alarm = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      repeat: const RepeatRule.daily(),
      skippedOccurrence: pastSkip,
    );
    await container.read(storageServiceProvider).saveAlarms([alarm]);
    container.invalidate(alarmsProvider);

    // Re-reading forces build() to run its sanitization pass.
    final alarms = await container.read(alarmsProvider.notifier).future;

    expect(alarms.single.skippedOccurrence, isNull);
  });
}
