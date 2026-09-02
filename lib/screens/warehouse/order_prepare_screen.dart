// order_prepare_screen.dart — prepare one order: weigh lines off the scale,
// note shortages, tick lines off, and move the order along.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'orders_to_prepare.dart' show statusColors;
import 'stock_screen.dart' show imageUrl;

// What the "advance" button does next, per current status. The warehouse worker
// takes an order up to 'ready' only — marking it delivered is the driver's job.
const _nextStatus = {
  'confirmed': ['picking', 'Start picking'],
  'picking': ['ready', 'Mark ready'],
};

// The statuses this picker offers on the header.
//
// 'draft' is deliberately absent: the worker app creates orders as confirmed,
// and no screen here lists drafts, so offering it would let someone move an
// order into a state the app itself cannot show it in again.
const _allStatuses = [
  ('submitted', 'Submitted'),
  ('confirmed', 'Confirmed'),
  ('picking', 'Picking'),
  ('ready', 'Ready for delivery'),
  ('out_for_delivery', 'Out for delivery'),
  ('delivered', 'Delivered'),
  ('cancelled', 'Cancelled'),
];

class OrderPrepareScreen extends StatefulWidget {
  final int orderId;
  const OrderPrepareScreen({required this.orderId, super.key});

  @override
  State<OrderPrepareScreen> createState() => _OrderPrepareScreenState();
}

class _OrderPrepareScreenState extends State<OrderPrepareScreen> {
  Map? _order;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.get('/orders/${widget.orderId}/');
      if (mounted) setState(() => _order = data as Map);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _lineAction(Map body) async {
    setState(() => _saving = true);
    try {
      final data = await api.post('/orders/${widget.orderId}/line_action/', body);
      if (mounted) setState(() => _order = data as Map);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeStatus() async {
    final current = (_order!['status'] ?? '').toString();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t('Change status'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
          ),
          for (final (value, label) in _allStatuses)
            ListTile(
              title: Text(t(label)),
              trailing: value == current
                  ? const Icon(Icons.check, color: kBlue)
                  : null,
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    );
    if (choice == null || choice == current) return;
    setState(() => _saving = true);
    try {
      final data =
          await api.post('/orders/${widget.orderId}/set_status/', {'status': choice});
      if (mounted) setState(() => _order = data as Map);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _advance(String status) async {
    setState(() => _saving = true);
    try {
      await api.post('/orders/${widget.orderId}/set_status/', {'status': status});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  // -- per-line actions --

  Future<void> _setLoaded(Map line) async {
    final ordered = (line['total_length_m'] ?? '').toString();
    final controller = TextEditingController(
        text: (line['delivered_length_m'] ?? line['total_length_m'] ?? '').toString());
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${t('Loaded')} — ${line['number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t('Ordered')}: $ordered ${t('m')}',
                style: const TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: t('Loaded metres'), suffixText: t('m')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(t('Save'))),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      await _lineAction({'line_id': line['id'], 'delivered_length_m': value});
    }
  }

  Future<void> _weigh(Map line) async {
    final current = (line['effective_weight_kg'] ?? '').toString();
    final controller = TextEditingController(
        text: line['weight_kg_override']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${t('Weigh')} ${line['number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t('Catalog estimate')}: $current ${t('kg')}',
                style: const TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: t('Scale reading (kg)'), suffixText: t('kg')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(t('Save'))),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      await _lineAction({'line_id': line['id'], 'weight_kg': value});
    }
  }

  Future<void> _shortage(Map line) async {
    final controller =
        TextEditingController(text: (line['shortage_note'] ?? '').toString());
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${t('Report shortage')} — ${line['number']}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
              labelText: t('What is missing / short?'),
              hintText: t('e.g. only 3 of 5 bars in stock')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(t('Save'))),
        ],
      ),
    );
    if (value != null) {
      await _lineAction({'line_id': line['id'], 'shortage_note': value});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_order?['number']?.toString() ?? t('Order'))),
      body: _error != null
          ? EmptyState(Icons.cloud_off, _error.toString(),
              actionLabel: t('Retry'), onAction: _load)
          : _order == null
              ? const Center(child: CircularProgressIndicator())
              : _body(),
      bottomNavigationBar: _order == null ? null : _bottomBar(),
    );
  }

  Widget _body() {
    final lines = (_order!['lines'] ?? []) as List;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          Text(t('Lines'),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _lineCard(l as Map),
              )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _headerCard() {
    final status = (_order!['status'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_order!['client_name'] ?? '',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _saving ? null : _changeStatus,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Pill((_order!['status_display'] ?? status).toString(),
                        statusColors[status] ?? kMuted),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more, size: 18, color: kMuted),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.scale, size: 18, color: kNavy),
                const SizedBox(width: 6),
                Text('${_order!['total_weight_kg'] ?? 0} ${t('kg total')}',
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
                if ((_order!['required_by'] ?? '') != '') ...[
                  const Spacer(),
                  const Icon(Icons.event, size: 16, color: kWarn),
                  const SizedBox(width: 4),
                  Text('${t('by')} ${_order!['required_by']}',
                      style: const TextStyle(color: kWarn)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(Map line) {
    final prepared = line['prepared'] == true;
    final lenM = (int.tryParse('${line['length_mm'] ?? 0}') ?? 0) / 1000;
    // Bars needed is computed server-side: bar count if given, else total length
    // ÷ bar length (the line's, or the 6 m standard) rounded up.
    final barsNeeded = line['bars_needed'];
    final shortage = (line['shortage_note'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The cross-section. A fitter recognises a profile by its
                // shape long before reading the number off it, and in a
                // workshop that picture is the difference between pulling
                // 1700 and pulling 1701.
                _section(line['section_image']),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The number with what it is: "1700" alone means
                      // nothing on a picking list.
                      Text([
                        line['number'] ?? '',
                        if ((line['description'] ?? '').toString().isNotEmpty)
                          line['description'],
                      ].join('  '),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15, color: kInk)),
                      if ((line['series_name'] ?? '').toString().isNotEmpty)
                        Text(line['series_name'],
                            style: const TextStyle(color: kMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Checkbox(
                  value: prepared,
                  onChanged: _saving
                      ? null
                      : (v) => _lineAction(
                          {'line_id': line['id'], 'prepared': v ?? false}),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _need(t('Bars needed'), barsNeeded != null ? '$barsNeeded' : '—'),
            _need(t('Total length'), '${line['total_length_m']} ${t('m')}'),
            _need(t('Bar length'), '${lenM > 0 ? _g(lenM) : 6} ${t('m')}'),
            if (line['delivered_length_m'] != null)
              _need(t('Loaded'), '${line['delivered_length_m']} ${t('m')}'),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.scale_outlined, size: 15, color: kMuted),
                const SizedBox(width: 4),
                Text('${line['effective_weight_kg']} ${t('kg')}',
                    style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
                if (line['weight_kg_override'] != null) ...[
                  const SizedBox(width: 6),
                  Pill(t('weighed'), kSuccess),
                ],
              ],
            ),
            if (shortage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_outlined, size: 16, color: kDanger),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(shortage,
                            style: const TextStyle(color: kDanger, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : () => _setLoaded(line),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text(t('Loaded')),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : () => _weigh(line),
                  icon: const Icon(Icons.scale, size: 18),
                  label: Text(t('Weigh')),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : () => _shortage(line),
                  icon: const Icon(Icons.report_problem_outlined, size: 18, color: kWarn),
                  label: Text(t('Missing'), style: const TextStyle(color: kWarn)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _bottomBar() {
    final status = (_order!['status'] ?? '').toString();
    final next = _nextStatus[status];
    if (next == null) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving ? null : () => _advance(next[0]),
          icon: const Icon(Icons.arrow_forward),
          label: Text(t(next[1])),
        ),
      ),
    );
  }

  /// The profile's cross-section drawing, or a placeholder that says so.
  ///
  /// Sized to be readable at arm's length on a phone held in a gloved hand,
  /// not as a decorative thumbnail.
  Widget _section(dynamic raw) {
    final url = imageUrl(raw);
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: kBlueLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kLine),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(3),
      child: url == null
          ? const Icon(Icons.image_not_supported_outlined,
              color: kMuted, size: 20)
          : Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined, color: kMuted, size: 20)),
    );
  }

  Widget _need(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text('$label:', style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(width: 6),
            Text(value,
                style: const TextStyle(
                    color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static String _g(num v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
