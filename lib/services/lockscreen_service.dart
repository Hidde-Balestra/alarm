import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges the native calls that force the app's Activity to show over the
/// lock screen (and wake the display) while an alarm/timer is ringing, so
/// [RingingScreen] is guaranteed to be visible and usable even if the device
/// was fully locked/asleep when it started ringing.
///
/// Android-only: a no-op everywhere else. Reuses the same MethodChannel as
/// [PermissionService]'s full-screen-intent bridge, since both live in the
/// same native `MainActivity`.
class LockscreenService {
  static const _channel = MethodChannel('nl.hiddebalestra.alarm/full_screen_intent');

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> showOverLockscreen() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('showOverLockscreen');
    } on PlatformException {
      // Ignore: nothing more we can do if the OS refuses.
    } on MissingPluginException {
      // Ignore: e.g. running in a widget test without the native channel.
    }
  }

  Future<void> restoreLockscreen() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('restoreLockscreen');
    } on PlatformException {
      // Ignore: nothing more we can do if the OS refuses.
    } on MissingPluginException {
      // Ignore: e.g. running in a widget test without the native channel.
    }
  }
}
