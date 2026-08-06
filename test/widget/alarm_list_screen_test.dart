import 'dart:convert';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/alarms/alarm_edit_screen.dart';
import 'package:alarm_app/screens/alarms/alarm_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  testWidgets('shows the empty state when there are no alarms', (tester) async {
    await pumpApp(tester, const AlarmListScreen());

    expect(find.text('No alarms yet'), findsOneWidget);
  });

  testWidgets('shows a tile for each stored alarm', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 30, label: 'Werk');
    await pumpApp(
      tester,
      const AlarmListScreen(),
      initialPrefs: {
        'alarms': jsonEncode([alarm.toJson()]),
      },
    );

    expect(find.text('7:30 AM'), findsOneWidget);
    expect(find.textContaining('Werk'), findsOneWidget);
    expect(find.text('No alarms yet'), findsNothing);
  });

  testWidgets('disabled alarms show an off switch', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 6, minute: 0, enabled: false);
    await pumpApp(
      tester,
      const AlarmListScreen(),
      initialPrefs: {
        'alarms': jsonEncode([alarm.toJson()]),
      },
    );

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
  });

  testWidgets('tapping the add button opens the new alarm editor', (tester) async {
    await pumpApp(tester, const AlarmListScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlarmEditScreen), findsOneWidget);
    expect(find.text('New alarm'), findsOneWidget);
  });

  testWidgets('a paused settings state shows a banner that resumes on tap', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 30);
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const AlarmListScreen();
        },
      ),
      initialPrefs: {
        'alarms': jsonEncode([alarm.toJson()]),
        'app_settings': jsonEncode(const AppSettings(alarmsPaused: true).toJson()),
      },
    );

    expect(find.text('Alarms are paused — tap to resume'), findsOneWidget);

    await tester.tap(find.text('Alarms are paused — tap to resume'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).valueOrNull?.alarmsPaused, isFalse);
    expect(find.text('Alarms are paused — tap to resume'), findsNothing);
  });

  testWidgets('a repeating enabled alarm can have its next occurrence skipped', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 30, repeat: RepeatRule.daily());
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const AlarmListScreen();
        },
      ),
      initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
    );

    await tester.tap(find.byTooltip('Skip next occurrence'));
    await tester.pumpAndSettle();

    final alarms = container.read(alarmsProvider).valueOrNull ?? [];
    expect(alarms.single.skippedOccurrence, isNotNull);
    expect(find.text('Next occurrence skipped'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel skip'));
    await tester.pumpAndSettle();

    final unskipped = container.read(alarmsProvider).valueOrNull ?? [];
    expect(unskipped.single.skippedOccurrence, isNull);
  });

  testWidgets('a bedtime card is shown for the soonest upcoming alarm', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 6, minute: 30, repeat: RepeatRule.daily());
    await pumpApp(
      tester,
      const AlarmListScreen(),
      initialPrefs: {
        'alarms': jsonEncode([alarm.toJson()]),
        'app_settings': jsonEncode(const AppSettings(desiredSleepHours: 8).toJson()),
      },
    );

    expect(find.textContaining('Go to sleep by'), findsOneWidget);
  });
}
