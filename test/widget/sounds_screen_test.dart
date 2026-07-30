import 'dart:convert';

import 'package:alarm_app/models/custom_sound.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/sounds/sounds_screen.dart';
import 'package:alarm_app/services/file_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_file_picker_service.dart';
import '../fakes/fake_sound_preview_service.dart';
import '../test_utils.dart';

/// Pushes [SoundsScreen] on top of a placeholder screen (matching how it's
/// really used, as a pushed route that pops with the chosen sound's id) and
/// taps through to it.
Future<void> _pushSoundsScreen(
  WidgetTester tester, {
  required String selectedId,
  List<Override> overrides = const [],
  Map<String, Object> initialPrefs = const {},
  ValueChanged<String?>? onPopped,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            final result = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => SoundsScreen(selectedId: selectedId)),
            );
            onPopped?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
    overrides: overrides,
    initialPrefs: initialPrefs,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists all bundled sounds and marks the selected one', (tester) async {
    await _pushSoundsScreen(tester, selectedId: 'gentle');

    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Digital'), findsOneWidget);
    expect(find.text('Gentle'), findsOneWidget);
    expect(find.text('Siren'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping a bundled sound pops the screen with its id', (tester) async {
    String? result;
    await _pushSoundsScreen(tester, selectedId: 'classic', onPopped: (v) => result = v);

    await tester.tap(find.text('Siren'));
    await tester.pumpAndSettle();

    expect(result, 'siren');
  });

  testWidgets('tapping preview plays the sound and toggles to a stop icon', (tester) async {
    final fakePreview = FakeSoundPreviewService();
    await _pushSoundsScreen(
      tester,
      selectedId: 'classic',
      overrides: [soundPreviewServiceProvider.overrideWithValue(fakePreview)],
    );

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(fakePreview.playedAssets, ['assets/sounds/classic.wav']);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    expect(fakePreview.stopCallCount, 1);
    expect(find.byIcon(Icons.stop), findsNothing);
  });

  testWidgets('shows a hint when there are no uploaded sounds yet', (tester) async {
    await _pushSoundsScreen(tester, selectedId: 'classic');

    expect(find.text('No uploaded sounds yet.'), findsOneWidget);
  });

  testWidgets('uploading a sound adds it to the list and pops with its id', (tester) async {
    String? result;
    const picked = PickedAudioFile(path: '/src/rooster.mp3', name: 'Rooster.mp3', extension: 'mp3');
    await _pushSoundsScreen(
      tester,
      selectedId: 'classic',
      overrides: [
        filePickerServiceProvider.overrideWithValue(const FakeFilePickerService(result: picked)),
      ],
      onPopped: (v) => result = v,
    );

    await tester.tap(find.text('Upload a sound'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
  });

  testWidgets('cancelling the file picker does not add a sound or pop', (tester) async {
    String? result;
    await _pushSoundsScreen(
      tester,
      selectedId: 'classic',
      overrides: [
        filePickerServiceProvider.overrideWithValue(const FakeFilePickerService(result: null)),
      ],
      onPopped: (v) => result = v,
    );

    await tester.tap(find.text('Upload a sound'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(SoundsScreen), findsOneWidget);
  });

  testWidgets('deleting a custom sound removes it after confirmation', (tester) async {
    const custom = CustomSound(id: 'c1', name: 'Rooster', relativePath: 'custom_sounds/c1.mp3');
    await _pushSoundsScreen(
      tester,
      selectedId: 'classic',
      initialPrefs: {'custom_sounds': jsonEncode([custom.toJson()])},
    );

    expect(find.text('Rooster'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Rooster'), findsNothing);
    expect(find.text('No uploaded sounds yet.'), findsOneWidget);
  });

  testWidgets('a custom sound matching selectedId shows the check mark', (tester) async {
    const custom = CustomSound(id: 'c1', name: 'Rooster', relativePath: 'custom_sounds/c1.mp3');
    await _pushSoundsScreen(
      tester,
      selectedId: 'c1',
      initialPrefs: {'custom_sounds': jsonEncode([custom.toJson()])},
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
