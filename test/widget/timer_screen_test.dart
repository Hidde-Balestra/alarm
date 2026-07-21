import 'package:alarm_app/screens/timers/timer_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

Finder _clockText() => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^(\d{2}:)?\d{2}:\d{2}$').hasMatch(widget.data!),
    );

void main() {
  testWidgets('shows the empty state when there are no timers', (tester) async {
    await pumpApp(tester, const TimerListScreen());

    expect(find.text('No timers running'), findsOneWidget);
  });

  testWidgets('starting a timer from the dialog shows a running card', (tester) async {
    await pumpApp(tester, const TimerListScreen());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add timer'), findsOneWidget);

    // Dialog defaults to 5 minutes; just confirm it.
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('No timers running'), findsNothing);
    expect(_clockText(), findsOneWidget);
  });

  testWidgets('pause button switches to a resume icon', (tester) async {
    await pumpApp(tester, const TimerListScreen());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('delete button removes the timer', (tester) async {
    await pumpApp(tester, const TimerListScreen());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('No timers running'), findsOneWidget);
  });
}
