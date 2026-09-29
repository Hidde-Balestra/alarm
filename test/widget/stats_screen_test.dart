import 'dart:convert';

import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/screens/history/stats_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

/// The stat tiles all use plain digits as their trailing value, so multiple
/// tiles can legitimately show the same number (e.g. two tiles both reading
/// "1") — find the value for one specific tile by its label instead of
/// asserting on the digit text directly.
String _statValueFor(WidgetTester tester, String label) {
  final tile = tester.widget<ListTile>(
    find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
  );
  return (tile.trailing as Text).data!;
}

void main() {
  testWidgets('shows the empty state when there is no alarm activity', (tester) async {
    await pumpApp(tester, const StatsScreen());

    expect(find.text('No alarm activity yet'), findsOneWidget);
  });

  testWidgets('shows computed stats once there is alarm history', (tester) async {
    final rangAt = DateTime(2026, 7, 21, 7, 0);
    final history = [
      HistoryEntry(
        id: '1',
        kind: RingingKind.alarm,
        refId: 'a1',
        action: HistoryAction.rang,
        timestamp: rangAt,
      ),
      HistoryEntry(
        id: '2',
        kind: RingingKind.alarm,
        refId: 'a1',
        action: HistoryAction.dismissed,
        timestamp: rangAt.add(const Duration(minutes: 5)),
      ),
    ];
    await pumpApp(
      tester,
      const StatsScreen(),
      initialPrefs: {'history': jsonEncode(history.map((e) => e.toJson()).toList())},
    );

    expect(find.text('No alarm activity yet'), findsNothing);
    expect(_statValueFor(tester, 'Times rung'), '1');
    expect(_statValueFor(tester, 'Dismissed without snoozing'), '1');
    expect(_statValueFor(tester, 'Total snoozes'), '0');
    expect(_statValueFor(tester, 'Average time to dismiss'), '5m');
  });
}
