import 'package:alarm_app/models/custom_sound.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CustomSound JSON round-trip preserves all fields', () {
    const sound = CustomSound(id: 'abc', name: 'Rooster', relativePath: 'custom_sounds/abc.mp3');
    final restored = CustomSound.fromJson(sound.toJson());
    expect(restored, sound);
  });
}
