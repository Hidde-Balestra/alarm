import 'dart:convert';

import 'package:alarm_app/app.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_alarm_scheduler_service.dart';
import '../fakes/fake_custom_sound_service.dart';
import '../fakes/fake_file_picker_service.dart';
import '../fakes/fake_home_widget_service.dart';
import '../fakes/fake_permission_service.dart';
import '../fakes/fake_sound_preview_service.dart';
import '../fakes/fake_update_service.dart';

/// Pumps the real [AlarmApp] at the root of the widget tree — deliberately
/// *not* nested inside another MaterialApp/Localizations ancestor, unlike
/// `test_utils.dart`'s `pumpApp` (which wraps its child in one). AlarmApp
/// builds its own MaterialApp, so its own `build(context)` runs with a
/// context that sits *above* that MaterialApp. Pumping it inside another
/// MaterialApp would accidentally supply a working Localizations ancestor
/// and hide exactly this kind of bug — see the regression this file guards
/// against: `syncNow` once called `formatTimeOfDay(context, ...)`, which
/// crashed with a null-check on `MaterialLocalizations.of` for precisely
/// this reason, on every sync (startup, snooze, dismiss).
Future<FakeHomeWidgetService> pumpAlarmApp(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  PackageInfo.setMockInitialValues(
    appName: 'Alarm',
    packageName: 'nl.hiddebalestra.alarm',
    version: '0.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  final fakeHomeWidget = FakeHomeWidgetService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        schedulerServiceProvider.overrideWithValue(FakeAlarmSchedulerService()),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
        updateServiceProvider.overrideWithValue(FakeUpdateService()),
        soundPreviewServiceProvider.overrideWithValue(FakeSoundPreviewService()),
        customSoundServiceProvider.overrideWithValue(FakeCustomSoundService()),
        filePickerServiceProvider.overrideWithValue(const FakeFilePickerService()),
        homeWidgetServiceProvider.overrideWithValue(fakeHomeWidget),
        clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ...overrides,
      ],
      child: const AlarmApp(),
    ),
  );
  await tester.pumpAndSettle();
  return fakeHomeWidget;
}

void main() {
  testWidgets('starting the app with an enabled alarm does not throw', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 30, repeat: RepeatRule.daily());
    await pumpAlarmApp(tester, initialPrefs: {'alarms': jsonEncode([alarm.toJson()])});

    expect(tester.takeException(), isNull);
  });

  testWidgets('pushes the next alarm\'s time and label to the homescreen widget', (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 30, label: 'Werk', repeat: RepeatRule.daily());
    final fakeHomeWidget =
        await pumpAlarmApp(tester, initialPrefs: {'alarms': jsonEncode([alarm.toJson()])});

    expect(tester.takeException(), isNull);
    expect(fakeHomeWidget.lastTimeText, isNotNull);
    expect(fakeHomeWidget.lastLabelText, 'Werk');
  });

  testWidgets('clears the homescreen widget when there are no alarms', (tester) async {
    final fakeHomeWidget = await pumpAlarmApp(tester);

    expect(tester.takeException(), isNull);
    expect(fakeHomeWidget.lastTimeText, anyOf(isNull, isEmpty));
  });

  testWidgets('pausing all alarms clears the homescreen widget even with an alarm enabled',
      (tester) async {
    const alarm = Alarm(id: 'a1', hour: 7, minute: 30, repeat: RepeatRule.daily());
    final fakeHomeWidget = await pumpAlarmApp(
      tester,
      initialPrefs: {
        'alarms': jsonEncode([alarm.toJson()]),
        'app_settings': jsonEncode(const AppSettings(alarmsPaused: true).toJson()),
      },
    );

    expect(tester.takeException(), isNull);
    expect(fakeHomeWidget.lastTimeText, anyOf(isNull, isEmpty));
  });
}
