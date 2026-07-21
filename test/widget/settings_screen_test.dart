import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/models/app_sound.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/settings/settings_screen.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:alarm_app/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_alarm_scheduler_service.dart';
import '../fakes/fake_permission_service.dart';
import '../fakes/fake_update_service.dart';
import '../test_utils.dart';

void main() {
  testWidgets('selecting Dark updates the settings provider', (tester) async {
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const SettingsScreen();
        },
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).valueOrNull?.themeMode, ThemeMode.dark);
  });

  testWidgets('selecting Nederlands updates the language setting', (tester) async {
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const SettingsScreen();
        },
      ),
    );

    await tester.tap(find.text('Nederlands'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).valueOrNull?.language, AppLanguage.dutch);
  });

  testWidgets('shows granted permissions as satisfied and hides the action button', (tester) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [
        permissionServiceProvider.overrideWithValue(
          FakePermissionService(
            granted: {
              for (final p in ReliabilityPermission.values) p: true,
            },
          ),
        ),
      ],
    );

    expect(find.text('Open settings'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(ReliabilityPermission.values.length));
  });

  testWidgets('requesting an ungranted permission calls the permission service', (tester) async {
    final fakePermissions = FakePermissionService();
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [
        permissionServiceProvider.overrideWithValue(fakePermissions),
      ],
    );

    expect(find.text('Open settings'), findsWidgets);

    await tester.tap(find.text('Open settings').first);
    await tester.pumpAndSettle();

    expect(fakePermissions.requestCallCount, 1);
  });

  testWidgets('tapping "Ring now" schedules a real test alarm and confirms it', (tester) async {
    final fakeScheduler = FakeAlarmSchedulerService();
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [
        schedulerServiceProvider.overrideWithValue(fakeScheduler),
      ],
    );

    await tester.tap(find.text('Ring now'));
    await tester.pumpAndSettle();

    expect(fakeScheduler.testAlarmScheduledCount, 1);
    expect(find.text('Test alarm will ring in 5 seconds'), findsOneWidget);
  });

  testWidgets('shows a reliability tile for the full-screen alarm permission', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    expect(find.text('Full-screen alarm'), findsOneWidget);
  });

  testWidgets('changing the default alarm sound updates settings', (tester) async {
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const SettingsScreen();
        },
      ),
    );

    // Default alarm sound is Classic, default timer sound is Digital —
    // tapping "Classic" unambiguously opens the alarm-sound dropdown.
    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siren').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).valueOrNull?.defaultAlarmSound, AppSound.siren);
  });

  testWidgets('changing the default timer sound updates settings', (tester) async {
    late ProviderContainer container;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const SettingsScreen();
        },
      ),
    );

    await tester.tap(find.text('Digital'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gentle').last);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).valueOrNull?.defaultTimerSound, AppSound.gentle);
  });

  testWidgets('shows the current version and up-to-date status', (tester) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [
        updateServiceProvider.overrideWithValue(
          FakeUpdateService(result: const UpdateCheckResult(status: UpdateStatus.upToDate)),
        ),
      ],
    );

    expect(find.text('Current version: 0.0.0'), findsOneWidget);
    expect(find.text("You're on the latest version"), findsOneWidget);
    expect(find.text('View release'), findsNothing);
  });

  testWidgets('shows an update-available card with a working release link', (tester) async {
    final fakeUpdates = FakeUpdateService(
      result: const UpdateCheckResult(
        status: UpdateStatus.updateAvailable,
        latestVersion: '9.9.9',
        releaseUrl: 'https://github.com/Hidde-Balestra/alarm/releases/tag/v9.9.9',
      ),
    );
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [updateServiceProvider.overrideWithValue(fakeUpdates)],
    );

    expect(find.text('Update available: 9.9.9'), findsOneWidget);

    await tester.tap(find.text('View release'));
    await tester.pumpAndSettle();

    expect(fakeUpdates.openReleasePageCallCount, 1);
    expect(fakeUpdates.lastOpenedUrl, 'https://github.com/Hidde-Balestra/alarm/releases/tag/v9.9.9');
  });

  testWidgets('a failed check shows an error state with a retry button', (tester) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: [
        updateServiceProvider.overrideWithValue(
          FakeUpdateService(result: const UpdateCheckResult(status: UpdateStatus.checkFailed)),
        ),
      ],
    );

    expect(find.text("Couldn't check for updates"), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
  });
}
