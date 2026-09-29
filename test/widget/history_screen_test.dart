import 'dart:convert';

import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/screens/history/history_screen.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  testWidgets('shows the empty state when there is no history', (tester) async {
    await pumpApp(tester, const HistoryScreen());

    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('a ring with no follow-up is shown as missed once the window has passed',
      (tester) async {
    final rangAt = DateTime.now().subtract(const Duration(hours: 1));
    final entry = HistoryEntry(
      id: '1',
      kind: RingingKind.alarm,
      refId: 'a1',
      label: 'Werk',
      action: HistoryAction.rang,
      timestamp: rangAt,
    );
    await pumpApp(
      tester,
      const HistoryScreen(),
      initialPrefs: {
        'history': jsonEncode([entry.toJson()]),
      },
    );

    expect(find.textContaining('Missed'), findsOneWidget);
    expect(find.textContaining('Rang'), findsNothing);
  });

  testWidgets('a dismissed ring is shown as Rang, not Missed', (tester) async {
    final rangAt = DateTime.now().subtract(const Duration(hours: 1));
    final entries = [
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
        timestamp: rangAt.add(const Duration(minutes: 2)),
      ),
    ];
    await pumpApp(
      tester,
      const HistoryScreen(),
      initialPrefs: {
        'history': jsonEncode(entries.map((e) => e.toJson()).toList()),
      },
    );

    expect(find.textContaining('Missed'), findsNothing);
  });
}
