// manager_team.dart — the manager's people view: approve clock-fix requests and
// see who is online right now.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

class ManagerTeam extends StatefulWidget {
  const ManagerTeam({super.key});

  @override
  State<ManagerTeam> createState() => _ManagerTeamState();
}

class _ManagerTeamState extends State<ManagerTeam> {
  List<dynamic>? _pending;
  List<dynamic>? _online;
  Map? _drivers; // {out_for_delivery, ready, drivers: [...]}
  Object? _error;
  final _busy = <int>{}; // correction ids currently being acted on

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final drivers = await api.get('/dashboard/drivers/');
      final c = await api.get('/corrections/', query: {'status': 'pending'});
      final pRows = c is Map ? (c['results'] ?? []) : c;
      final o = await api.get('/dashboard/online/');
      if (mounted) {
        setState(() {
          _drivers = drivers as Map;
          _pending = pRows as List;
          _online = o as List;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Map req, bool approve) async {
    final id = req['id'] as int;
    setState(() => _busy.add(id));
    try {
      await api.post('/corrections/$id/${approve ? 'approve' : 'reject'}/', {});
      if (mounted) {
        showOk(context,
            approve ? t('Request approved.') : t('Request rejected.'));
        setState(() => _pending!.removeWhere((r) => r['id'] == id));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: t('Retry'), onAction: _load);
    }
    if (_pending == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: Bounded(
        maxWidth: 900,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader(t('Active drivers'), Icons.local_shipping_outlined),
            const SizedBox(height: 8),
            _driversBoard(),
            const SizedBox(height: 24),
            _sectionHeader(
                t('Pending approvals'), Icons.pending_actions_outlined),
            const SizedBox(height: 8),
            if (_pending!.isEmpty)
              _emptyNote(t('No requests waiting.'))
            else
              ..._pending!.map((r) => _approvalCard(r as Map)),
            const SizedBox(height: 24),
            _sectionHeader(t('Online now'), Icons.circle, dotColor: kSuccess),
            const SizedBox(height: 8),
            if ((_online ?? []).isEmpty)
              _emptyNote(t('Nobody is online.'))
            else
              ...(_online!).map((u) => _onlineTile(u as Map)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Color? dotColor}) => Row(
        children: [
          Icon(icon, size: dotColor != null ? 12 : 20, color: dotColor ?? kNavy),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
        ],
      );

  Widget _emptyNote(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, style: const TextStyle(color: kMuted)),
      );

  Widget _driversBoard() {
    final d = _drivers;
    if (d == null) return const SizedBox.shrink();
    final drivers = (d['drivers'] ?? []) as List;
    final out = (d['out_for_delivery'] ?? 0) as int;
    final ready = (d['ready'] ?? 0) as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Business-wide truck counts (the run is shared, not per driver).
        Row(
          children: [
            _truckChip(Icons.local_shipping, '$out', t('out for delivery'),
                out > 0 ? kBlue : kMuted),
            const SizedBox(width: 10),
            _truckChip(Icons.inventory_2_outlined, '$ready', t('ready to load'),
                ready > 0 ? kWarn : kMuted),
          ],
        ),
        const SizedBox(height: 12),
        if (drivers.isEmpty)
          _emptyNote(t('No drivers.'))
        else
          ...drivers.map((x) => _driverTile(x as Map)),
      ],
    );
  }

  Widget _truckChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverTile(Map u) {
    final clockedIn = u['clocked_in'] == true;
    final online = u['online'] == true;
    final delivered = (u['delivered_today'] ?? 0) as int;
    final statusColor = clockedIn ? kSuccess : (online ? kBlue : kMuted);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: kBlueLight,
              child: Text(_initials(u['full_name']?.toString() ?? '?'),
                  style:
                      const TextStyle(color: kNavy, fontWeight: FontWeight.w700)),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kCard, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(u['full_name']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
        subtitle: Text(
          clockedIn
              ? t('On shift')
              : online
                  ? t('Online')
                  : t('Off'),
          style: TextStyle(color: statusColor, fontSize: 12.5),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$delivered',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
            Text(t('delivered today'),
                style: const TextStyle(color: kMuted, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _approvalCard(Map r) {
    final id = r['id'] as int;
    final busy = _busy.contains(id);
    final inAt = _fmtTime(r['requested_clock_in']);
    final outAt = _fmtTime(r['requested_clock_out']);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: kNavy),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r['worker_name']?.toString() ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: kInk)),
                ),
                Text(r['work_date']?.toString() ?? '',
                    style: const TextStyle(color: kMuted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${t('Clock in')}: $inAt   ·   ${t('Clock out')}: $outAt',
              style: const TextStyle(color: kInk, fontSize: 13),
            ),
            if ((r['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r['reason'].toString(),
                  style: const TextStyle(color: kMuted, fontSize: 12.5)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _act(r, false),
                    icon: const Icon(Icons.close, size: 18, color: kDanger),
                    label: Text(t('Reject'),
                        style: const TextStyle(color: kDanger)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kSuccess),
                    onPressed: busy ? null : () => _act(r, true),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(t('Approve')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _onlineTile(Map u) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kBlueLight,
          child: Text(_initials(u['full_name']?.toString() ?? '?'),
              style: const TextStyle(color: kNavy, fontWeight: FontWeight.w700)),
        ),
        title: Text(u['full_name']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
        subtitle: Text(u['role_display']?.toString() ?? '',
            style: const TextStyle(color: kMuted)),
        trailing: const Pill('online', kSuccess),
      ),
    );
  }

  static String _fmtTime(dynamic iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    return d == null ? '—' : DateFormat('HH:mm').format(d);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
