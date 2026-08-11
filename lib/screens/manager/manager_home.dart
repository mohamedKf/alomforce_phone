// manager_home.dart — the manager's app: a business dashboard, team approvals,
// orders oversight, stock, and a personal tab. Built for phone and tablet.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../state.dart';
import '../../theme.dart';
import '../settings_screen.dart';
import '../warehouse/clock_screen.dart';
import '../warehouse/orders_to_prepare.dart';
import '../warehouse/scan_screen.dart';
import '../warehouse/stock_screen.dart';
import 'manager_dashboard.dart';
import 'manager_team.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int _tab = 0;

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ManagerDashboard(onGoTo: _goTo),
      const ManagerTeam(),
      const OrdersToPrepare(),
      const StockScreen(),
      const _ManagerMe(),
    ];
    final titles = [
      t('Dashboard'), t('Team'), t('Orders'), t('Stock'), t('Me'),
    ];
    final destinations = [
      NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: t('Dashboard')),
      NavigationDestination(
          icon: const Icon(Icons.groups_outlined),
          selectedIcon: const Icon(Icons.groups),
          label: t('Team')),
      NavigationDestination(
          icon: const Icon(Icons.assignment_outlined),
          selectedIcon: const Icon(Icons.assignment),
          label: t('Orders')),
      NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: t('Stock')),
      NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: t('Me')),
    ];
    if (_tab >= pages.length) _tab = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: t('Find a profile'),
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }
}

class _ManagerMe extends StatelessWidget {
  const _ManagerMe();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: kBlueLight,
            child: Text(_initials(api.fullName),
                style: const TextStyle(
                    fontSize: 30, color: kNavy, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(api.fullName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: kInk)),
        ),
        const SizedBox(height: 4),
        Center(child: Text(t('Manager'), style: const TextStyle(color: kMuted))),
        const SizedBox(height: 28),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.schedule_outlined, color: kNavy),
                title: Text(t('Time clock')),
                subtitle: Text(t('Clock in and out')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClockScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: kNavy),
                title: Text(t('Settings')),
                subtitle: Text(t('Server and language')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => appState.signOut(),
          icon: const Icon(Icons.logout, color: kDanger),
          label: Text(t('Sign out'), style: const TextStyle(color: kDanger)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
