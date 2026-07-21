import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/app_settings.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          const SizedBox(height: 24),
        ],
      ),
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
