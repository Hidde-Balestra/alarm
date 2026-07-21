import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/settings/settings_screen.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_permission_service.dart';
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
}
