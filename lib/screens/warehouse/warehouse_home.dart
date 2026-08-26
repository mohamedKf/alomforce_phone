// warehouse_home.dart — the stock worker's app: orders to prepare, stock, me.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../widgets.dart';
import '../../state.dart';
import '../../theme.dart';
import '../driver/driver_home.dart';
import '../settings_screen.dart';
import 'clock_screen.dart';
import 'payslips_screen.dart';
import 'orders_to_prepare.dart';
import 'scan_screen.dart';
import 'stock_screen.dart';

class WarehouseHome extends StatefulWidget {
  const WarehouseHome({super.key});

  @override
  State<WarehouseHome> createState() => _WarehouseHomeState();
}

class _WarehouseHomeState extends State<WarehouseHome> {
  // Landing tab is Clock (0); a dev --dart-define=TAB=n can start elsewhere.
  int _tab = const int.fromEnvironment('TAB', defaultValue: 0);

  @override
  Widget build(BuildContext context) {
    // A driver is a stock worker who also delivers, so they get every worker
    // tab plus a Deliveries tab. Clock is the home tab either way.
    final isDriver = api.role == 'driver';
    final pages = <Widget>[
      const ClockScreen(),
      const OrdersToPrepare(),
      const StockScreen(),
      if (isDriver) const DeliveriesTab(),
      const _MeTab(),
    ];
    final titles = [
      t('Time clock'), t('Orders to prepare'), t('Stock'),
      if (isDriver) t('Deliveries'), t('Me'),
    ];
    final destinations = [
      NavigationDestination(
          icon: const Icon(Icons.schedule_outlined),
          selectedIcon: const Icon(Icons.schedule),
          label: t('Clock')),
      NavigationDestination(
          icon: const Icon(Icons.assignment_outlined),
          selectedIcon: const Icon(Icons.assignment),
          label: t('Orders')),
      NavigationDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: t('Stock')),
      if (isDriver)
        NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: t('Deliveries')),
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
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: pages[_tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }
}

class _MeTab extends StatelessWidget {
  const _MeTab();

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
            child: Text(
              _initials(api.fullName),
              style: const TextStyle(fontSize: 30, color: kNavy, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(api.fullName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kInk)),
        ),
        const SizedBox(height: 4),
        Center(
            child: Text(
                t(api.role == 'driver' ? 'Delivery driver' : 'Warehouse worker'),
                style: const TextStyle(color: kMuted))),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                _row(Icons.badge_outlined, t('ID number'),
                    (api.user['id_number'] ?? '').toString()),
                const Divider(height: 1),
                _row(Icons.phone_outlined, t('Phone'),
                    (api.user['phone'] ?? '—').toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: kNavy),
                title: Text(t('My payslips')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PayslipsScreen())),
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

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: kMuted, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: kMuted)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}
