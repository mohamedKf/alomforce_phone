// payslips_screen.dart — the worker's own monthly payslips (list + breakdown).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  List<dynamic>? _rows;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await api.get('/payslips/');
      final rows = data is Map ? (data['results'] ?? []) : data;
      if (mounted) setState(() => _rows = rows as List);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _period(Map p) {
    final y = int.tryParse('${p['year']}') ?? 2000;
    final m = int.tryParse('${p['month']}') ?? 1;
    return DateFormat('MMMM yyyy').format(DateTime(y, m));
  }

  String _money(dynamic v) {
    final d = double.tryParse('${v ?? 0}') ?? 0;
    return '₪ ${NumberFormat('#,##0.00').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('My payslips'))),
      body: _error != null
          ? EmptyState(Icons.cloud_off, _error.toString(),
              actionLabel: t('Retry'), onAction: _load)
          : _rows == null
              ? const Center(child: CircularProgressIndicator())
              : _rows!.isEmpty
                  ? EmptyState(Icons.receipt_long_outlined, t('No payslips yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _card(_rows![i] as Map),
                      ),
                    ),
    );
  }

  Widget _card(Map p) {
    final isFinal = p['status'] == 'final';
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(p),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_period(p),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
                    const SizedBox(height: 2),
                    Text(
                        '${p['days_worked'] ?? 0} ${t('days')} · '
                        '${p['total_hours'] ?? 0} ${t('h')}',
                        style: const TextStyle(color: kMuted, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(p['total_pay']),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17, color: kNavy)),
                  const SizedBox(height: 4),
                  Pill(t(isFinal ? 'Finalised' : 'Draft'),
                      isFinal ? kSuccess : kWarn),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(Map p) {
    final adjustments = (p['adjustments'] as List?) ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_period(p),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 14),
            _line(t('Base pay'), _money(p['base_pay'])),
            if ((double.tryParse('${p['overtime_pay'] ?? 0}') ?? 0) != 0)
              _line(t('Overtime'), _money(p['overtime_pay'])),
            for (final a in adjustments)
              _line((a['label'] ?? '').toString(), _money(a['amount'])),
            const Divider(height: 24),
            _line(t('Total'), _money(p['total_pay']), bold: true),
            const SizedBox(height: 8),
            Text(
                '${p['days_worked'] ?? 0} ${t('days')} · '
                '${p['total_hours'] ?? 0} ${t('h')}',
                style: const TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    color: bold ? kInk : kMuted,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: bold ? 16 : 14)),
            Text(v,
                style: TextStyle(
                    color: kInk,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: bold ? 17 : 14)),
          ],
        ),
      );
}
