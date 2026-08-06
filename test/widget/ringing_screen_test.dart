import 'dart:convert';

import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/ringing/ringing_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

final _questionPattern = RegExp(r'^(-?\d+) ([+\-×]) (\d+) = \?$');

/// Reads the generated math question off screen and computes its answer,
/// since `MathChallenge.generate()` isn't seeded from the widget under test.
int _solveDisplayedChallenge(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final match = _questionPattern.firstMatch(widget.data ?? '');
    if (match == null) continue;
    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(3)!);
    return switch (match.group(2)!) {
      '+' => a + b,
      '-' => a - b,
      '×' => a * b,
      _ => throw StateError('unknown operator'),
    };
  }
  throw StateError('math challenge question not found on screen');
}

void main() {
  const ringingRef = RingingRef(RingingKind.alarm, 'a1');

  testWidgets('requireMathToDismiss blocks dismiss until the correct answer is entered',
      (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0, requireMathToDismiss: true);
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const RingingScreen(ringingRef: ringingRef);
        },
      ),
      initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
    );

    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();

    expect(find.text('Solve to dismiss'), findsOneWidget);

    final answer = _solveDisplayedChallenge(tester);
    await tester.enterText(find.byType(TextField), '$answer');
    await tester.tap(find.text('Dismiss').last);
    await tester.pumpAndSettle();

    expect(find.text('Solve to dismiss'), findsNothing);
    final history = container.read(historyProvider).valueOrNull ?? [];
    expect(history.any((e) => e.action.name == 'dismissed'), isTrue);
  });

  testWidgets('a wrong answer keeps the challenge open instead of dismissing', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0, requireMathToDismiss: true);
    await pumpApp(
      tester,
      const RingingScreen(ringingRef: ringingRef),
      initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
    );

    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();

    final correct = _solveDisplayedChallenge(tester);
    await tester.enterText(find.byType(TextField), '${correct + 1000}');
    await tester.tap(find.text('Dismiss').last);
    await tester.pumpAndSettle();

    expect(find.text('Solve to dismiss'), findsOneWidget);
    expect(find.byType(RingingScreen), findsOneWidget);
  });

  testWidgets('snooze button is hidden once maxSnoozes is reached', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0, maxSnoozes: 1, snoozeCount: 1);
    await pumpApp(
      tester,
      const RingingScreen(ringingRef: ringingRef),
      initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
    );

    expect(find.text('Snooze'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('snoozing increments the alarm\'s snooze count', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 0);
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const RingingScreen(ringingRef: ringingRef);
        },
      ),
      initialPrefs: {'alarms': jsonEncode([alarm.toJson()])},
    );

    await tester.tap(find.text('Snooze'));
    await tester.pumpAndSettle();

    final alarms = container.read(alarmsProvider).valueOrNull ?? [];
    expect(alarms.single.snoozeCount, 1);
  });
}
