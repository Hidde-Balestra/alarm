import 'package:alarm_app/screens/stopwatch/stopwatch_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  testWidgets('shows the empty hint and a Start button before anything has run', (tester) async {
    await pumpApp(tester, const StopwatchScreen());

    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('starting shows Pause and Lap, hides the empty hint', (tester) async {
    await pumpApp(tester, const StopwatchScreen());

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();

    expect(find.text('Ready when you are'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Pause'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Lap'), findsOneWidget);
  });

  testWidgets('pausing switches back to Resume and enables Reset', (tester) async {
    await pumpApp(tester, const StopwatchScreen());

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    final resetButton =
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Reset'));
    expect(resetButton.onPressed, isNotNull);
  });

  testWidgets('recording a lap while running adds it to the list', (tester) async {
    await pumpApp(tester, const StopwatchScreen());

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Lap'));
    await tester.pump();

    expect(find.text('Lap 1'), findsOneWidget);
  });

  testWidgets('reset clears laps and returns to the empty state', (tester) async {
    await pumpApp(tester, const StopwatchScreen());

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Lap'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await tester.pump();

    expect(find.text('Lap 1'), findsNothing);
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });
}
