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

  test('finish() keeps the timer in the list instead of deleting it', () async {
    final notifier = container.read(timersProvider.notifier);
    await notifier.start(
      id: 'timer-1',
      duration: const Duration(minutes: 5),
      label: 'Pasta',
      soundId: 'digital',
      notificationTitle: 'Timer finished',
      notificationBody: 'Pasta',
      stopButtonLabel: 'Dismiss',
    );

    await notifier.finish('timer-1');

    final timers = container.read(timersProvider).valueOrNull ?? [];
    expect(timers, hasLength(1));

    final timer = timers.single;
    expect(timer.id, 'timer-1');
    expect(timer.paused, isTrue);
    expect(timer.remainingWhenPaused, const Duration(minutes: 5));
    expect(timer.remaining(DateTime.now()), const Duration(minutes: 5));
  });

  test('finish() cancels the underlying OS-level alarm', () async {
    final scheduler =
        container.read(schedulerServiceProvider) as FakeAlarmSchedulerService;
    final notifier = container.read(timersProvider.notifier);
    await notifier.start(
      id: 'timer-1',
      duration: const Duration(minutes: 5),
      label: '',
      soundId: 'digital',
      notificationTitle: 'Timer finished',
      notificationBody: 'Timer finished',
      stopButtonLabel: 'Dismiss',
    );

    await notifier.finish('timer-1');

    expect(scheduler.cancelledTimerIds, contains('timer-1'));
  });
}
