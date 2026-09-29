import 'dart:convert';

import 'package:alarm_app/models/alarm.dart';

/// A portable snapshot of just the alarms (not settings, timers, custom
/// sounds, or history — those are either device-local, ephemeral, or would
/// silently change the app's configuration on import in a surprising way).
/// If an alarm points at a custom sound the importing device doesn't have,
/// `resolveSoundAssetPath` already falls back to the classic sound, so
/// nothing breaks — the alarm just needs its sound reassigned by hand.
class BackupData {
  static const _formatVersion = 1;

  final List<Alarm> alarms;

  const BackupData({required this.alarms});

  String toJsonString() => const JsonEncoder.withIndent('  ').convert({
        'formatVersion': _formatVersion,
        'alarms': alarms.map((a) => a.toJson()).toList(),
      });

  factory BackupData.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final list = json['alarms'] as List<dynamic>? ?? const [];
    return BackupData(
      alarms: list.map((e) => Alarm.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
