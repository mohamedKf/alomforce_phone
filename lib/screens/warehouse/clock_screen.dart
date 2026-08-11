// clock_screen.dart — clock in / out, live elapsed time, today/week totals, and
// a short shift history.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../theme.dart';
import '../../i18n.dart';
import '../../widgets.dart';
import 'month_calendar_screen.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Map? _current; // open shift, or null
  Map? _summary;
  Map? _payroll; // this month's pay estimate
  List<dynamic>? _history;
  Object? _error;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh the elapsed clock every second while clocked in.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_current != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final current = await api.get('/attendance/current/');
      final summary = await api.get('/attendance/summary/');
      final payroll = await api.get('/attendance/payroll/');
      // Recent shifts reset weekly: only this week's, from Sunday.
      final since = summary is Map ? summary['week_start']?.toString() : null;
      final history = await api.get('/attendance/',
          query: since != null ? {'since': since} : null);
      final rows =
          history is Map ? (history['results'] ?? []) : history;
      if (mounted) {
        setState(() {
          _current = current is Map ? current : null;
          _summary = summary as Map?;
          _payroll = payroll as Map?;
          _history = rows as List;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      if (_current == null) {
        await api.post('/attendance/clock_in/', {});
        if (mounted) showOk(context, t('Clocked in.'));
      } else {
        await api.post('/attendance/clock_out/', {});
        if (mounted) showOk(context, t('Clocked out.'));
      }
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: t('Retry'), onAction: _load);
    }
    if (_summary == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: Bounded(ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(),
          const SizedBox(height: 16),
          _totalsRow(),
          if (_payroll != null) ...[
            const SizedBox(height: 16),
            _payCard(),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MonthCalendarScreen())),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(t('Work calendar')),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          ),
          const SizedBox(height: 22),
          Text(t('This week'),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
          const SizedBox(height: 8),
          ..._historyList(),
        ],
      )),
    );
  }

  Widget _statusCard() {
    final clockedIn = _current != null;
    final since = clockedIn ? DateTime.tryParse(_current!['clock_in'] ?? '') : null;
    final elapsed = since != null ? DateTime.now().difference(since.toLocal()) : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: clockedIn ? [kBlue, kNavy] : [kNavy, kNavyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(clockedIn ? t('Clocked in') : t('Clocked out'),
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            elapsed != null ? _fmtDuration(elapsed) : '—',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
          if (since != null) ...[
            const SizedBox(height: 2),
            Text('since ${DateFormat('HH:mm').format(since.toLocal())}',
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _toggle,
              style: FilledButton.styleFrom(
                backgroundColor: clockedIn ? kDanger : kSuccess,
                minimumSize: const Size(0, 56),
              ),
              icon: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Icon(clockedIn ? Icons.logout : Icons.login),
              label: Text(clockedIn ? t('Clock out') : t('Clock in'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsRow() {
    final today = (_summary!['today_minutes'] ?? 0) as int;
    final week = (_summary!['week_minutes'] ?? 0) as int;
    return Row(
      children: [
        Expanded(child: _totalCard(t('Today'), today)),
        const SizedBox(width: 12),
        Expanded(child: _totalCard(t('This week'), week)),
      ],
    );
  }

  Widget _payCard() {
    final p = _payroll!;
    final basisLabel = {
      'hourly': 'By hour',
      'daily': 'By day',
      'monthly': 'Monthly salary',
    }[p['pay_basis']] ?? '';
    final ot = p['overtime_enabled'] == true;
    final reg = (p['regular_hours'] ?? 0).toString();
    final ot125 = (p['overtime_125_hours'] ?? 0) as num;
    final ot150 = (p['overtime_150_hours'] ?? 0) as num;
    final month = _monthLabel(p['month']?.toString());
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 18, color: kNavy),
                const SizedBox(width: 6),
                Text('Pay — $month',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
                const Spacer(),
                Text('₪ ${_money(p['total_pay'])}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: kNavy)),
              ],
            ),
            const SizedBox(height: 6),
            Text('$basisLabel · ${p['days_worked']} days · ${p['total_hours']} h',
                style: const TextStyle(color: kMuted, fontSize: 13)),
            const Divider(height: 20),
            _payRow(t('Base pay'), '₪ ${_money(p['base_pay'])}'),
            if (ot && (ot125 > 0 || ot150 > 0)) ...[
              _payRow('Overtime (${ot125 == 0 ? '' : '${_g(ot125)}h ×125%'}'
                  '${ot125 > 0 && ot150 > 0 ? ', ' : ''}'
                  '${ot150 == 0 ? '' : '${_g(ot150)}h ×150%'})',
                  '₪ ${_money(p['overtime_pay'])}'),
            ],
            if (!ot)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Overtime not paid for this worker',
                    style: TextStyle(color: kMuted, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            Text('$reg ${t('regular hours')}',
                style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _payRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: kInk))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
        ],
      ),
    );
  }

  Widget _totalCard(String label, int minutes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          children: [
            Text(_fmtHm(minutes),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  List<Widget> _historyList() {
    final rows = _history ?? [];
    if (rows.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: Text('No shifts yet.', style: TextStyle(color: kMuted))),
        )
      ];
    }
    return rows.take(14).map((s) => _shiftRow(s as Map)).toList();
  }

  Widget _shiftRow(Map s) {
    final inAt = DateTime.tryParse(s['clock_in'] ?? '')?.toLocal();
    final outAt = s['clock_out'] != null
        ? DateTime.tryParse(s['clock_out'])?.toLocal()
        : null;
    final open = s['is_open'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inAt != null ? DateFormat('EEE, d MMM').format(inAt) : '—',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
                const SizedBox(height: 2),
                Text(
                  '${inAt != null ? DateFormat('HH:mm').format(inAt) : '--:--'}'
                  ' → ${outAt != null ? DateFormat('HH:mm').format(outAt) : (open ? 'now' : '--:--')}',
                  style: const TextStyle(color: kMuted, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            if (open)
              const Pill('open', kSuccess)
            else
              Text(_fmtHm((s['duration_minutes'] ?? 0) as int),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
          ],
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static String _fmtHm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static String _money(dynamic v) {
    final n = (v is num) ? v : num.tryParse('$v') ?? 0;
    return NumberFormat('#,##0.00').format(n);
  }

  static String _g(num v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  static String _monthLabel(String? ym) {
    if (ym == null) return '';
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final date = DateTime.tryParse('$ym-01');
    return date != null ? DateFormat('MMMM yyyy').format(date) : ym;
  }
}
