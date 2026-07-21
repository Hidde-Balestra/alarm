import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/screens/alarms/alarm_list_screen.dart';
import 'package:alarm_app/screens/settings/settings_screen.dart';
import 'package:alarm_app/screens/timers/timer_list_screen.dart';
import 'package:flutter/material.dart';

/// Bottom-navigation shell with the three main sections of the app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screens = const [
      AlarmListScreen(),
      TimerListScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.alarm), label: l10n.navAlarms),
          NavigationDestination(icon: const Icon(Icons.timer_outlined), label: l10n.navTimer),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: l10n.navSettings),
        ],
      ),
    );
  }
}
