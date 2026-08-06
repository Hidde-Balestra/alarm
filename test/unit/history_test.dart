import 'package:alarm_app/models/history_entry.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/alarm_scheduler_service.dart';
import 'package:alarm_app/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_alarm_scheduler_service.dart';

void main() {
  test('HistoryEntry JSON round-trip preserves all fields', () {
    final entry = HistoryEntry(
      id: 'h1',
      kind: RingingKind.timer,
      refId: 't1',
      label: 'Pasta',
      action: HistoryAction.snoozed,
      timestamp: DateTime(2026, 7, 21, 7, 5),
    );

    final json = entry.toJson();
    final restored = HistoryEntry.fromJson(json);

    expect(restored.id, entry.id);
    expect(restored.kind, entry.kind);
    expect(restored.refId, entry.refId);
    expect(restored.label, entry.label);
    expect(restored.action, entry.action);
    expect(restored.timestamp, entry.timestamp);
  });

  group('HistoryNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(
        overrides: [
          schedulerServiceProvider.overrideWithValue(FakeAlarmSchedulerService()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('record() adds new entries to the front', () async {
      final notifier = container.read(historyProvider.notifier);
      final first = HistoryEntry(
        id: '1',
        kind: RingingKind.alarm,
        refId: 'a1',
        action: HistoryAction.rang,
        timestamp: DateTime(2026, 7, 21, 7, 0),
      );
      final second = HistoryEntry(
        id: '2',
        kind: RingingKind.alarm,
        refId: 'a1',
        action: HistoryAction.dismissed,
        timestamp: DateTime(2026, 7, 21, 7, 1),
      );

      await notifier.record(first);
      await notifier.record(second);

      final entries = container.read(historyProvider).valueOrNull ?? [];
      expect(entries.map((e) => e.id), ['2', '1']);
    });

    test('record() trims the log to StorageService.historyLimit entries', () async {
      final notifier = container.read(historyProvider.notifier);

      for (var i = 0; i < StorageService.historyLimit + 5; i++) {
        await notifier.record(
          HistoryEntry(
            id: '$i',
            kind: RingingKind.alarm,
            refId: 'a1',
            action: HistoryAction.rang,
            timestamp: DateTime(2026, 7, 21).add(Duration(minutes: i)),
          ),
        );
      }

      final entries = container.read(historyProvider).valueOrNull ?? [];
      expect(entries.length, StorageService.historyLimit);
      // Most-recently recorded (highest i) stays at the front.
      expect(entries.first.id, '${StorageService.historyLimit + 4}');
    });
  });
}
