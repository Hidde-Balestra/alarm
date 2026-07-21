import 'dart:convert';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/screens/alarms/alarm_edit_screen.dart';
import 'package:alarm_app/screens/alarms/alarm_list_screen.dart';
import 'package:flutter/material.dart';
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
}
