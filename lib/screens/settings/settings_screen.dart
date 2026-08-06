import 'dart:async';

import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/screens/history/history_screen.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:alarm_app/services/update_service.dart';
import 'package:alarm_app/widgets/sound_selector_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _volumeRampOptions = [0, 10, 30, 60];
const _maxSnoozeOptions = [0, 1, 2, 3, 5];
const _sleepHoursOptions = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  Map<ReliabilityPermission, bool> _permissionStatus = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final status = await ref.read(permissionServiceProvider).statusSnapshot();
    if (mounted) setState(() => _permissionStatus = status);
  }

  Future<void> _ringTestAlarm(BuildContext context, AppLocalizations l10n) async {
    await ref.read(schedulerServiceProvider).scheduleTestAlarm(
          delay: const Duration(seconds: 5),
          notificationTitle: l10n.testAlarmTitle,
          notificationBody: l10n.testAlarmTitle,
          stopButtonLabel: l10n.dismiss,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.testAlarmScheduledMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsThemeSection),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) => notifier.setThemeMode(value ?? settings.themeMode),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(l10n.themeSystem),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.themeLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(l10n.themeDark),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsLanguageSection),
          RadioGroup<AppLanguage>(
            groupValue: settings.language,
            onChanged: (value) => notifier.setLanguage(value ?? settings.language),
            child: Column(
              children: [
                RadioListTile<AppLanguage>(
                  title: Text(l10n.languageSystem),
                  value: AppLanguage.system,
                ),
                RadioListTile<AppLanguage>(
                  title: Text(l10n.languageDutch),
                  value: AppLanguage.dutch,
                ),
                RadioListTile<AppLanguage>(
                  title: Text(l10n.languageEnglish),
                  value: AppLanguage.english,
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsDefaultsSection),
          ListTile(
            title: Text(l10n.settingsDefaultSnooze),
            trailing: DropdownButton<int>(
              value: settings.defaultSnoozeMinutes,
              items: [
                for (final minutes in const [3, 5, 9, 10, 15, 20])
                  DropdownMenuItem(value: minutes, child: Text(l10n.minutesShort(minutes))),
              ],
              onChanged: (value) {
                if (value != null) notifier.setDefaultSnoozeMinutes(value);
              },
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsDefaultVibration),
            value: settings.defaultVibrate,
            onChanged: notifier.setDefaultVibrate,
          ),
          SoundSelectorTile(
            title: l10n.settingsDefaultAlarmSound,
            selectedId: settings.defaultAlarmSoundId,
            onChanged: notifier.setDefaultAlarmSoundId,
          ),
          SoundSelectorTile(
            title: l10n.settingsDefaultTimerSound,
            selectedId: settings.defaultTimerSoundId,
            onChanged: notifier.setDefaultTimerSoundId,
          ),
          ListTile(
            title: Text(l10n.maxSnoozesLabel),
            trailing: DropdownButton<int>(
              value: settings.defaultMaxSnoozes,
              items: [
                for (final count in _maxSnoozeOptions)
                  DropdownMenuItem(
                    value: count,
                    child: Text(count == 0 ? l10n.maxSnoozesUnlimited : '$count'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) notifier.setDefaultMaxSnoozes(value);
              },
            ),
          ),
          ListTile(
            title: Text(l10n.volumeRampLabel),
            trailing: DropdownButton<int>(
              value: settings.defaultVolumeRampSeconds,
              items: [
                for (final seconds in _volumeRampOptions)
                  DropdownMenuItem(
                    value: seconds,
                    child: Text(seconds == 0 ? l10n.volumeRampOff : '$seconds${l10n.secondsShort}'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) notifier.setDefaultVolumeRampSeconds(value);
              },
            ),
          ),
          SwitchListTile(
            title: Text(l10n.requireMathToDismissLabel),
            subtitle: Text(l10n.requireMathToDismissHint),
            value: settings.defaultRequireMathToDismiss,
            onChanged: notifier.setDefaultRequireMathToDismiss,
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsBedtimeSection, subtitle: l10n.settingsBedtimeSubtitle),
          ListTile(
            title: Text(l10n.desiredSleepHoursLabel),
            trailing: DropdownButton<double>(
              value: settings.desiredSleepHours,
              items: [
                for (final hours in _sleepHoursOptions)
                  DropdownMenuItem(
                    value: hours,
                    child: Text(
                      '${hours == hours.roundToDouble() ? hours.toInt() : hours}${l10n.hoursShort}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) notifier.setDesiredSleepHours(value);
              },
            ),
          ),
          const Divider(),
          _SectionHeader(
              title: l10n.settingsPauseSection, subtitle: l10n.settingsPauseSubtitle),
          SwitchListTile(
            title: Text(l10n.alarmsPausedToggleLabel),
            value: settings.alarmsPaused,
            onChanged: notifier.setAlarmsPaused,
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsHistorySection),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.viewHistoryAction),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsPermissionsSection, subtitle: l10n.settingsPermissionsSubtitle),
          _PermissionTile(
            title: l10n.permissionNotificationTitle,
            description: l10n.permissionNotificationDescription,
            permission: ReliabilityPermission.notification,
            granted: _permissionStatus[ReliabilityPermission.notification] ?? false,
            onRefresh: _refreshPermissions,
          ),
          _PermissionTile(
            title: l10n.permissionExactAlarmTitle,
            description: l10n.permissionExactAlarmDescription,
            permission: ReliabilityPermission.exactAlarm,
            granted: _permissionStatus[ReliabilityPermission.exactAlarm] ?? false,
            onRefresh: _refreshPermissions,
          ),
          _PermissionTile(
            title: l10n.permissionDndTitle,
            description: l10n.permissionDndDescription,
            permission: ReliabilityPermission.doNotDisturb,
            granted: _permissionStatus[ReliabilityPermission.doNotDisturb] ?? false,
            onRefresh: _refreshPermissions,
          ),
          _PermissionTile(
            title: l10n.permissionBatteryTitle,
            description: l10n.permissionBatteryDescription,
            permission: ReliabilityPermission.batteryOptimization,
            granted: _permissionStatus[ReliabilityPermission.batteryOptimization] ?? false,
            onRefresh: _refreshPermissions,
          ),
          _PermissionTile(
            title: l10n.permissionFullScreenTitle,
            description: l10n.permissionFullScreenDescription,
            permission: ReliabilityPermission.fullScreenAlarm,
            granted: _permissionStatus[ReliabilityPermission.fullScreenAlarm] ?? false,
            onRefresh: _refreshPermissions,
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsTestSection),
          ListTile(
            title: Text(l10n.testAlarmTitle),
            subtitle: Text(l10n.testAlarmDescription),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: () => _ringTestAlarm(context, l10n),
              child: Text(l10n.testAlarmButton),
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsAboutSection),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.settingsIosCriticalAlertsNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsUpdatesSection),
          const _UpdatesSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _UpdatesSection extends ConsumerStatefulWidget {
  const _UpdatesSection();

  @override
  ConsumerState<_UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends ConsumerState<_UpdatesSection> {
  String? _currentVersion;
  UpdateCheckResult? _result;
  // Starts true as the initial field value (not via setState) since
  // calling setState synchronously from initState is not allowed — it
  // still runs during the build phase.
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    if (!_checking) setState(() => _checking = true);
    final info = await PackageInfo.fromPlatform();
    final result = await ref.read(updateServiceProvider).checkForUpdate(info.version);
    if (!mounted) return;
    setState(() {
      _currentVersion = info.version;
      _result = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUpdate = _result?.status == UpdateStatus.updateAvailable;

    return ListTile(
      leading: const Icon(Icons.new_releases_outlined),
      title: Text(l10n.githubReleasesTitle),
      subtitle: hasUpdate
          ? Text(
              l10n.updateAvailableLabel(_result!.latestVersion ?? ''),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            )
          : _currentVersion != null
              ? Text(l10n.currentVersionLabel(_currentVersion!))
              : null,
      trailing: _checking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : hasUpdate
              ? Icon(Icons.circle, color: Theme.of(context).colorScheme.primary, size: 10)
              : const Icon(Icons.open_in_new, size: 16),
      onTap: () => ref
          .read(updateServiceProvider)
          .openReleasePage(_result?.releaseUrl ?? UpdateService.releasesUrl),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PermissionTile extends ConsumerWidget {
  final String title;
  final String description;
  final ReliabilityPermission permission;
  final bool granted;
  final VoidCallback onRefresh;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.permission,
    required this.granted,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      isThreeLine: true,
      trailing: granted
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : TextButton(
              onPressed: () async {
                await ref.read(permissionServiceProvider).request(permission);
                onRefresh();
              },
              child: Text(l10n.openSettings),
            ),
    );
  }
}
