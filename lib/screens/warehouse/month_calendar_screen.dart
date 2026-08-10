// month_calendar_screen.dart — a month grid of the worker's work days.
//
// Each day that has a shift is filled and shows the hours worked; tap a day to
// see its clock-in/out. Arrows move between months. Week starts on Sunday.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'correction_request_screen.dart';

class MonthCalendarScreen extends StatefulWidget {
  const MonthCalendarScreen({super.key});

  @override
  State<MonthCalendarScreen> createState() => _MonthCalendarScreenState();
}

class _MonthCalendarScreenState extends State<MonthCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, Map> _days = {};
  Map? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = DateFormat('yyyy-MM').format(_month);
      final data = await api.get('/attendance/month/', query: {'month': m});
      final days = <String, Map>{};
      for (final d in (data['days'] as List? ?? [])) {
        days[d['date'] as String] = d as Map;
      }
      if (mounted) {
        setState(() {
          _data = data as Map;
          _days = days;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Work calendar'))),
      body: _error != null
          ? EmptyState(Icons.cloud_off, _error.toString(),
              actionLabel: t('Retry'), onAction: _load)
          : Column(
              children: [
                _monthBar(),
                if (_loading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else ...[
                  _summaryStrip(),
                  _weekdayHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [_grid(), _legend()]),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _monthBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
              onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text(DateFormat('MMMM yyyy').format(_month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
          ),
          IconButton(
              onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  Widget _summaryStrip() {
    final worked = _data?['days_worked'] ?? 0;
    final mins = (_data?['total_minutes'] ?? 0) as int;
    final h = mins ~/ 60, m = mins % 60;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
          color: kBlueLight, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('$worked', t('days worked')),
          _stat('${h}h ${m}m', t('this month')),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: kNavy)),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      );

  Widget _weekdayHeader() {
    final labels = [t('Sun'), t('Mon'), t('Tue'), t('Wed'), t('Thu'), t('Fri'), t('Sat')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(l,
                        style: const TextStyle(
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _grid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Sunday-based: how many blanks before day 1. Dart weekday: Mon=1..Sun=7.
    final leading = first.weekday % 7;
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final worked = _days[key];
      final isToday = date == todayMidnight;
      final isPast = date.isBefore(todayMidnight);
      cells.add(_dayCell(date, worked, isToday, isPast));
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: cells,
      ),
    );
  }

  // Israeli work week: Sun–Thu are workdays; Fri (5) and Sat (6) are weekend.
  bool _isWeekend(DateTime d) => d.weekday == DateTime.friday || d.weekday == DateTime.saturday;

  Widget _dayCell(DateTime date, Map? worked, bool isToday, bool isPast) {
    final has = worked != null;
    final open = has && worked['open'] == true;
    final mins = has ? (worked['minutes'] ?? 0) as int : 0;
    final hours = mins / 60;

    Color bg;
    Color fg;
    if (open) {
      bg = kWarn; // came, but didn't clock out
      fg = Colors.white;
    } else if (has) {
      bg = kBlue; // worked (clocked in and out)
      fg = Colors.white;
    } else if (_isWeekend(date)) {
      bg = const Color(0xFFEDF0F4); // weekend, no work
      fg = kMuted;
    } else if (isPast) {
      bg = kDanger; // a workday the worker didn't show up
      fg = Colors.white;
    } else {
      bg = Colors.white; // today / future workday, not yet worked
      fg = kInk;
    }

    return InkWell(
      onTap: () => _showDay(date, worked),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isToday ? kNavy : kLine, width: isToday ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
            if (has)
              Text(
                  open
                      ? '···'
                      : '${hours.toStringAsFixed(hours == hours.roundToDouble() ? 0 : 1)}h',
                  style: TextStyle(color: fg, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showDay(DateTime date, Map? worked) {
    String fmt(String? iso) => iso == null
        ? '—'
        : DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    final has = worked != null;
    final mins = has ? (worked['minutes'] ?? 0) as int : 0;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, d MMMM').format(date),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 12),
            if (has) ...[
              _kv(t('Clock in'), fmt(worked['clock_in'] as String?)),
              _kv(t('Clock out'),
                  worked['open'] == true ? t('Still open') : fmt(worked['clock_out'] as String?)),
              _kv(t('Worked'), '${mins ~/ 60}h ${mins % 60}m'),
            ] else
              Text(t('No shift recorded for this day.'),
                  style: TextStyle(color: kMuted)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(t('Request a fix')),
                onPressed: () {
                  Navigator.of(context).pop();
                  _openFix(date, worked);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFix(DateTime date, Map? worked) async {
    DateTime? parse(String? iso) => iso == null ? null : DateTime.parse(iso);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CorrectionRequestScreen(
        initialDate: date,
        initialClockIn: has(worked) ? parse(worked!['clock_in'] as String?) : null,
        initialClockOut: has(worked) ? parse(worked!['clock_out'] as String?) : null,
      ),
    ));
    _load();
  }

  bool has(Map? w) => w != null;

  Widget _legend() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _legendItem(kBlue, t('Worked')),
            _legendItem(kWarn, t("Didn't clock out")),
            _legendItem(kDanger, t('Absent')),
            _legendItem(const Color(0xFFEDF0F4), t('Weekend')),
          ],
        ),
      );

  Widget _legendItem(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kLine)),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: kMuted)),
            Text(v, style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
