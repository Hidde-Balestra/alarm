import 'dart:convert';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/alarms/alarm_edit_screen.dart';
import 'package:alarm_app/screens/alarms/alarm_list_screen.dart';
import 'package:alarm_app/screens/ringing/good_morning_screen.dart';
import 'package:alarm_app/screens/ringing/ringing_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_alarm_scheduler_service.dart';
import '../fakes/fake_reminder_notification_service.dart';
import '../test_utils.dart';

/// Pushes a [RingingScreen] from a host page and records what it pops
/// with, so tests can check whether the good-morning screen would follow.
class _RingingHost extends StatefulWidget {
  final RingingRef ringingRef;
  final void Function(ProviderContainer) onContainer;

  const _RingingHost({required this.ringingRef, required this.onContainer});

  @override
  State<_RingingHost> createState() => _RingingHostState();
}

class _RingingHostState extends State<_RingingHost> {
  Object? result = 'not popped';

  @override
  Widget build(BuildContext context) {
    widget.onContainer(ProviderScope.containerOf(context));
    return Scaffold(
      body: Column(
        children: [
          Text('result: $result'),
          TextButton(
            onPressed: () async {
              final popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => RingingScreen(ringingRef: widget.ringingRef)),
              );
              setState(() => result = popped);
            },
            child: const Text('ring'),
          ),
        ],
      ),
    );
  }
}

Future<ProviderContainer> _pumpRinging(
  WidgetTester tester,
  Alarm alarm, {
  RingingRef? ringingRef,
}) async {
  late ProviderContainer container;
  await pumpApp(
    tester,
    _RingingHost(
      ringingRef: ringingRef ?? RingingRef(RingingKind.alarm, alarm.id),
      onContainer: (c) => container = c,
    ),
    initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
  );
  await tester.tap(find.text('ring'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('dismissing pops true when the good-morning screen is on', (tester) async {
    await _pumpRinging(tester, const Alarm(id: 'a1', hour: 7, minute: 0));

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('result: true'), findsOneWidget);
  });

  testWidgets('dismissing pops false when the good-morning screen is off', (tester) async {
    await _pumpRinging(tester, const Alarm(id: 'a1', hour: 7, minute: 0, showGoodMorning: false));

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('result: false'), findsOneWidget);
  });

  testWidgets('dismissing with the wake-up check on arms the follow-up ring and prompt',
      (tester) async {
    final container =
        await _pumpRinging(tester, const Alarm(id: 'a1', hour: 7, minute: 0, wakeUpCheck: true));

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    final scheduler = container.read(schedulerServiceProvider) as FakeAlarmSchedulerService;
    final reminders =
        container.read(reminderNotificationServiceProvider) as FakeReminderNotificationService;
    expect(scheduler.scheduledWakeCheckIds, ['a1']);
    expect(reminders.scheduledWakeCheckPrompts, {'a1'});
    expect(container.read(pendingWakeCheckProvider)?.alarmId, 'a1');
  });

  testWidgets('the wake-check ring has no snooze and confirming cancels the follow-up',
      (tester) async {
    final container = await _pumpRinging(
      tester,
      const Alarm(id: 'a1', hour: 7, minute: 0, wakeUpCheck: true),
      ringingRef: const RingingRef(RingingKind.alarm, 'a1', stage: RingingStage.wakeCheck),
    );

    expect(find.text('Still asleep?'), findsOneWidget);
    expect(find.text('Snooze'), findsNothing);

    await tester.tap(find.text("I'm awake"));
    await tester.pumpAndSettle();

    final scheduler = container.read(schedulerServiceProvider) as FakeAlarmSchedulerService;
    expect(scheduler.cancelledWakeCheckIds, contains('a1'));
    expect(scheduler.scheduledWakeCheckIds, isEmpty);
    // Confirming isn't a new wake-up: no history entry, no good morning.
    expect(await container.read(historyProvider.future), isEmpty);
    expect(find.text('result: false'), findsOneWidget);
  });

  testWidgets('a nap alarm is deleted once dismissed', (tester) async {
    final container =
        await _pumpRinging(tester, const Alarm(id: 'n1', hour: 14, minute: 30, isNap: true));

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(container.read(alarmsProvider).valueOrNull, isEmpty);
    expect(find.text('result: false'), findsOneWidget);
  });

  testWidgets('the nap button adds a nap alarm and offers undo', (tester) async {
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const AlarmListScreen();
        },
      ),
    );

    await tester.tap(find.byTooltip('Nap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 min'));
    await tester.pumpAndSettle();

    final alarms = container.read(alarmsProvider).valueOrNull ?? [];
    expect(alarms, hasLength(1));
    expect(alarms.single.isNap, isTrue);
    expect(alarms.single.label, 'Nap');
    expect(find.textContaining('Nap: alarm at'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(alarmsProvider).valueOrNull, isEmpty);
  });

  testWidgets('the alarm list shows which holiday is being skipped', (tester) async {
    // Every weekday so the next occurrence is never more than a few days
    // out; only checked for presence of *some* holiday hint when it is one.
    const alarm = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      repeat: RepeatRule.daily(),
      skipHolidays: true,
    );
    await pumpApp(
      tester,
      const AlarmListScreen(),
      initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
    );

    final holiday = alarm.upcomingSkippedHoliday(DateTime.now());
    expect(
      find.textContaining('skipped (public holiday)'),
      holiday == null ? findsNothing : findsOneWidget,
    );
  });

  testWidgets('the holiday option only shows for repeating alarms', (tester) async {
    await pumpApp(tester, const AlarmEditScreen());

    expect(find.text('Skip public holidays'), findsNothing);
    expect(find.text('Sunrise light'), findsOneWidget);

    await tester.tap(find.text('Every day'));
    await tester.pumpAndSettle();

    expect(find.text('Skip public holidays'), findsOneWidget);
  });

  testWidgets('new alarms take the wake-up defaults from Settings', (tester) async {
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          // In the app, settings are long loaded by the time the editor
          // opens; it reads them once, in initState.
          if (!ref.watch(settingsProvider).hasValue) return const SizedBox();
          return const AlarmEditScreen();
        },
      ),
      initialPrefs: {
        'app_settings': jsonEncode({
          'defaultSunriseMinutes': 15,
          'defaultWakeUpCheck': true,
          'defaultShowGoodMorning': false,
        }),
      },
    );

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final saved = container.read(alarmsProvider).valueOrNull?.single;
    expect(saved?.sunriseMinutes, 15);
    expect(saved?.wakeUpCheck, isTrue);
    expect(saved?.showGoodMorning, isFalse);
  });

  testWidgets('the good-morning screen greets, shows a thought and closes', (tester) async {
    await pumpApp(tester, const GoodMorningScreen(alarmId: 'a1'));

    expect(
      find.textContaining(RegExp(r'^Good (morning|afternoon|evening)$')),
      findsOneWidget,
    );
    expect(find.text('Start your day'), findsOneWidget);
  });
}
