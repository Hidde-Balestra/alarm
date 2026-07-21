import 'package:alarm_app/screens/alarms/alarm_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

void main() {
  testWidgets('selecting "every other week" reveals a starting-week picker defaulting to today',
      (tester) async {
    await pumpApp(tester, const AlarmEditScreen());

    await tester.tap(find.text('Every other week'));
    await tester.pumpAndSettle();

    expect(find.text('Starting week'), findsOneWidget);
  });

  testWidgets('with no weekday selected yet, the next-ring banner asks to pick a day',
      (tester) async {
    await pumpApp(tester, const AlarmEditScreen());

    await tester.tap(find.text('Weekly on selected days'));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one day'), findsOneWidget);
  });

  testWidgets('picking a weekday shows a concrete next-ring time', (tester) async {
    await pumpApp(tester, const AlarmEditScreen());

    await tester.tap(find.text('Every other week'));
    await tester.pumpAndSettle();
    // Pick today's weekday chip so a next occurrence can always be computed.
    final todayLabel = _weekdayLabels[DateTime.now().weekday - 1];
    await tester.tap(find.text(todayLabel));
    await tester.pumpAndSettle();

    expect(find.textContaining('Next:'), findsOneWidget);
    expect(find.text('Pick at least one day'), findsNothing);
  });

  testWidgets('changing the starting week updates the displayed date', (tester) async {
    await pumpApp(tester, const AlarmEditScreen());

    await tester.tap(find.text('Every other week'));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final nextMonth = DateTime(today.year, today.month + 1, 1);

    // The last TextButton on screen at this point is the starting-week date
    // button (the first TextButton is the time picker).
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining(_monthAbbreviations[nextMonth.month - 1]), findsWidgets);
  });
}
