import 'package:permission_handler/permission_handler.dart';

/// The permissions/settings this app relies on to make sure alarms actually
/// ring: notifications, exact alarm scheduling, Do Not Disturb access, and
/// battery-optimization exemption. All are Android-specific system toggles
/// that can't be granted silently — the user has to flip them in Settings.
enum ReliabilityPermission { notification, exactAlarm, doNotDisturb, batteryOptimization }

class PermissionService {
  Permission _permissionFor(ReliabilityPermission permission) => switch (permission) {
        ReliabilityPermission.notification => Permission.notification,
        ReliabilityPermission.exactAlarm => Permission.scheduleExactAlarm,
        ReliabilityPermission.doNotDisturb => Permission.accessNotificationPolicy,
        ReliabilityPermission.batteryOptimization => Permission.ignoreBatteryOptimizations,
      };

  Future<bool> isGranted(ReliabilityPermission permission) async {
    final status = await _permissionFor(permission).status;
    return status.isGranted;
  }

  /// Requests the permission through the normal OS dialog where supported.
  /// For permissions Android only grants via a settings screen (Do Not
  /// Disturb access, battery optimization), this opens that screen directly.
  Future<void> request(ReliabilityPermission permission) async {
    final target = _permissionFor(permission);
    if (permission == ReliabilityPermission.doNotDisturb ||
        permission == ReliabilityPermission.batteryOptimization) {
      await target.request();
      return;
    }
    await target.request();
  }

  Future<void> openSettings() => openAppSettings();

  /// Best-effort request for iOS Critical Alerts. Without Apple's entitlement
  /// this will not actually unlock ringing through the mute switch/DND, but
  /// requesting it is harmless and picks it up automatically if the
  /// entitlement is ever granted.
  Future<void> requestIosCriticalAlerts() async {
    await Permission.criticalAlerts.request();
  }

  Future<Map<ReliabilityPermission, bool>> statusSnapshot() async {
    final result = <ReliabilityPermission, bool>{};
    for (final permission in ReliabilityPermission.values) {
      result[permission] = await isGranted(permission);
    }
    return result;
  }
}
