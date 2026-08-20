// correction_request_screen.dart — ask a manager to fix a day's clock in/out.
//
// Clocking is once per day and can't be edited, so a mistake (wrong time, forgot
// to clock out, missed a day) is raised here for a manager to approve.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

class CorrectionRequestScreen extends StatefulWidget {
  /// Optional prefill when opened from a day in the calendar: the day's date
  /// and its existing clock-in/out (so the worker edits what's there).
  final DateTime? initialDate;
  final DateTime? initialClockIn;
  final DateTime? initialClockOut;
  const CorrectionRequestScreen({
    super.key,
    this.initialDate,
    this.initialClockIn,
    this.initialClockOut,
  });

  @override
  State<CorrectionRequestScreen> createState() => _CorrectionRequestScreenState();
}

class _CorrectionRequestScreenState extends State<CorrectionRequestScreen> {
  late DateTime _date = widget.initialDate ?? DateTime.now();
  late TimeOfDay? _inTime = widget.initialClockIn == null
      ? null
      : TimeOfDay.fromDateTime(widget.initialClockIn!.toLocal());
  late TimeOfDay? _outTime = widget.initialClockOut == null
      ? null
      : TimeOfDay.fromDateTime(widget.initialClockOut!.toLocal());
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;
  List<dynamic>? _mine;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final data = await api.get('/corrections/');
      final rows = data is Map ? (data['results'] ?? []) : data;
      if (mounted) setState(() => _mine = rows as List);
    } catch (_) {}
  }

  DateTime? _combine(TimeOfDay? t) => t == null
      ? null
      : DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _submit() async {
    if (_inTime == null && _outTime == null) {
      setState(() => _error = t('Set a new clock-in or clock-out time.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.post('/corrections/', {
        'work_date': DateFormat('yyyy-MM-dd').format(_date),
        'requested_clock_in': _combine(_inTime)?.toUtc().toIso8601String(),
        'requested_clock_out': _combine(_outTime)?.toUtc().toIso8601String(),
        'reason': _reason.text.trim(),
      });
      if (mounted) {
        showOk(context, t('Request sent to your manager.'));
        setState(() {
          _inTime = null;
          _outTime = null;
          _reason.clear();
        });
        _loadMine();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Request a time fix'))),
      body: Bounded(ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            _pickerRow(t('Date'), DateFormat('EEE, d MMM yyyy').format(_date), _pickDate),
            const Divider(height: 20),
            _pickerRow(t('Clock in'),
                _inTime == null ? t('Not set') : _inTime!.format(context),
                () => _pickTime(true)),
            const Divider(height: 20),
            _pickerRow(t('Clock out'),
                _outTime == null ? t('Not set') : _outTime!.format(context),
                () => _pickTime(false)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: t('Reason'),
                hintText: t('e.g. Forgot to clock out'),
                border: const OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: kDanger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52), backgroundColor: kBlue),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? t('Sending…') : t('Send request')),
          ),
          if (_mine != null && _mine!.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(t('My requests'),
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
            const SizedBox(height: 8),
            ..._mine!.map(_requestTile),
          ],
        ],
      )),
    );
  }

  Widget _requestTile(dynamic r) {
    final status = (r['status'] ?? '').toString();
    final color = status == 'approved'
        ? kSuccess
        : status == 'rejected'
            ? kDanger
            : kWarn;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLine)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['work_date']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
                if ((r['reason'] ?? '').toString().isNotEmpty)
                  Text(r['reason'].toString(),
                      style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
          ),
          Pill((r['status_display'] ?? status).toString(), color),
        ],
      ),
    );
  }

  Widget _pickerRow(String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: kMuted)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
            const Icon(Icons.chevron_right, color: kMuted),
          ],
        ),
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isIn) async {
    final t = await showTimePicker(
        context: context,
        initialTime: (isIn ? _inTime : _outTime) ??
            TimeOfDay(hour: isIn ? 8 : 17, minute: 0));
    if (t != null) setState(() => isIn ? _inTime = t : _outTime = t);
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kLine)),
        child: Column(children: children),
      );
}
