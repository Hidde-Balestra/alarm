import 'package:alarm_app/models/timer_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('readyToRestart resets to paused at the full original duration', () {
    final started = TimerSession.start(
      id: 't1',
      duration: const Duration(minutes: 5),
      label: 'Pasta',
      soundId: 'siren',
    );
    // Simulate time passing before it rang.
    final almostDone = started.pause(started.endAt!.subtract(const Duration(seconds: 1)));

    final finished = almostDone.readyToRestart();

    expect(finished.paused, isTrue);
    expect(finished.remainingWhenPaused, const Duration(minutes: 5));
    expect(finished.remaining(DateTime.now()), const Duration(minutes: 5));
    // Label and sound choice survive the reset.
    expect(finished.label, 'Pasta');
    expect(finished.soundId, 'siren');
  });

  test('JSON round-trip preserves all fields', () {
    final timer = TimerSession(
      id: 't1',
      totalDuration: const Duration(minutes: 3),
      label: 'Eggs',
      soundId: 'gentle',
      remainingWhenPaused: const Duration(minutes: 1),
      paused: true,
    );
    final restored = TimerSession.fromJson(timer.toJson());

    expect(restored.id, timer.id);
    expect(restored.totalDuration, timer.totalDuration);
    expect(restored.label, timer.label);
    expect(restored.soundId, timer.soundId);
    expect(restored.remainingWhenPaused, timer.remainingWhenPaused);
    expect(restored.paused, timer.paused);
  });
}
