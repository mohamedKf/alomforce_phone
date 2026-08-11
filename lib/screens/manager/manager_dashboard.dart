// manager_dashboard.dart — the manager's landing screen: business at a glance.
//
// Headline tiles from /dashboard/ (workers, stock, clients, catalog) plus the
// count of clock-fix requests waiting for approval. Tapping the approvals tile
// jumps to the Team tab.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

class ManagerDashboard extends StatefulWidget {
  /// Called when the manager taps a tile that lives on another tab.
  final void Function(int tab)? onGoTo;
  const ManagerDashboard({super.key, this.onGoTo});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  Map? _data;
  int _pending = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await api.get('/dashboard/');
      // Count of pending clock-fix requests (managers approve these).
      int pending = 0;
      try {
        final c = await api.get('/corrections/', query: {'status': 'pending'});
        final rows = c is Map ? (c['results'] ?? []) : c;
        pending = (rows as List).length;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _data = data as Map;
          _pending = pending;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: t('Retry'), onAction: _load);
    }
    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final workers = (_data!['workers'] ?? {}) as Map;
    final stock = (_data!['stock'] ?? {}) as Map;
    final clients = (_data!['clients'] ?? {}) as Map;
    final catalog = (_data!['catalog'] ?? {}) as Map;

    final tiles = <Widget>[
      _tile(
        icon: Icons.groups_outlined,
        color: kBlue,
        value: '${workers['online'] ?? 0}',
        sub: '/ ${workers['active'] ?? 0} ${t('active')}',
        label: t('Workers online'),
        onTap: () => widget.onGoTo?.call(1),
      ),
      _tile(
        icon: Icons.pending_actions_outlined,
        color: _pending > 0 ? kWarn : kSuccess,
        value: '$_pending',
        label: t('Pending approvals'),
        badge: _pending > 0,
        onTap: () => widget.onGoTo?.call(1),
      ),
      _tile(
        icon: Icons.inventory_2_outlined,
        color: (stock['alerts'] ?? 0) > 0 ? kDanger : kSuccess,
        value: '${stock['alerts'] ?? 0}',
        sub: '${stock['out'] ?? 0} ${t('out')} · ${stock['low'] ?? 0} ${t('low')}',
        label: t('Stock alerts'),
        onTap: () => widget.onGoTo?.call(3),
      ),
      _tile(
        icon: Icons.business_outlined,
        color: kNavy,
        value: '${clients['active'] ?? 0}',
        sub: '${clients['total'] ?? 0} ${t('total')}',
        label: t('Clients'),
      ),
      _tile(
        icon: Icons.view_in_ar_outlined,
        color: kNavy,
        value: '${catalog['profiles'] ?? 0}',
        sub: '${catalog['series'] ?? 0} ${t('series')}',
        label: t('Catalog profiles'),
      ),
      if ((workers['pending_password'] ?? 0) > 0)
        _tile(
          icon: Icons.key_outlined,
          color: kWarn,
          value: '${workers['pending_password']}',
          label: t('Need first password'),
        ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: Bounded(
        maxWidth: 900,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${t('Hello')}, ${api.fullName.split(' ').first} 👋',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 4),
            Text(t('Here is your business right now.'),
                style: const TextStyle(color: kMuted)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (ctx, cons) {
              final cols = cons.maxWidth >= 620 ? 3 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: tiles,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    String? sub,
    bool badge = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (badge)
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        const BoxDecoration(color: kWarn, shape: BoxShape.circle),
                  ),
              ],
            ),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800, color: color)),
            if (sub != null)
              Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: kInk, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
