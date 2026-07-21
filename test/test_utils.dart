import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_alarm_scheduler_service.dart';
import 'fakes/fake_permission_service.dart';
import 'fakes/fake_update_service.dart';

/// Pumps [child] inside a [ProviderScope] + [MaterialApp] with localizations
/// wired up, using fakes for anything that would otherwise hit a real
/// platform channel. Also stubs `shared_preferences` with an empty in-memory
/// store unless [initialPrefs] is provided.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Map<String, Object> initialPrefs = const {},
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  PackageInfo.setMockInitialValues(
    appName: 'Alarm',
    packageName: 'nl.hiddebalestra.alarm',
    version: '0.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  // Tall surface so long scrollable screens (e.g. Settings) render every
  // item's Element instead of leaving off-screen ones un-mounted.
  await tester.binding.setSurfaceSize(const Size(420, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        schedulerServiceProvider.overrideWithValue(FakeAlarmSchedulerService()),
        permissionServiceProvider.overrideWithValue(FakePermissionService()),
        updateServiceProvider.overrideWithValue(FakeUpdateService()),
        // Avoids a real periodic Timer leaking past test teardown.
        clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
