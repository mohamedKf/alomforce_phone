// orders_to_prepare.dart — the queue of orders the warehouse needs to prepare.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../orders/new_order_screen.dart';
import 'order_prepare_screen.dart';

// The three filters and the order statuses each covers.
const _filters = [
  ('Not done yet', ['confirmed', 'picking']),
  ('Ready to send', ['ready', 'out_for_delivery']),
  ('Done', ['delivered']),
];

const statusColors = {
  'draft': kMuted,
  'submitted': kWarn,
  'confirmed': kBlue,
  'picking': Color(0xFF7C3AED),
  'ready': Color(0xFF0E7490),
  'out_for_delivery': Color(0xFF0369A1),
  'delivered': kSuccess,
  'cancelled': kDanger,
};

class OrdersToPrepare extends StatefulWidget {
  const OrdersToPrepare({super.key});

  @override
  State<OrdersToPrepare> createState() => _OrdersToPrepareState();
}

class _OrdersToPrepareState extends State<OrdersToPrepare> {
  List<dynamic>? _orders;
  Object? _error;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = <dynamic>[];
      for (final s in _filters[_filter].$2) {
        final data = await api.get('/orders/', query: {'status': s});
        final rows = data is Map ? (data['results'] ?? []) : data;
        results.addAll(rows as List);
      }
      results.sort((a, b) => (b['ordered_at'] ?? '').toString().compareTo(
          (a['ordered_at'] ?? '').toString()));
      if (mounted) setState(() => _orders = results);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _newOrder() async {
    final created = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewOrderScreen()));
    if (created != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        backgroundColor: kBlue,
        icon: const Icon(Icons.add),
        label: Text(t('New order')),
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (var i = 0; i < _filters.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(t(_filters[i].$1)),
                selected: _filter == i,
                onSelected: (_) {
                  setState(() {
                    _filter = i;
                    _orders = null;
                  });
                  _load();
                },
                selectedColor: kBlue,
                labelStyle: TextStyle(
                    color: _filter == i ? Colors.white : kInk,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: t('Retry'), onAction: _load);
    }
    if (_orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders!.isEmpty) {
      return EmptyState(Icons.inbox_outlined, t('No orders here.'),
          actionLabel: t('Retry'), onAction: _load);
    }
    return ResponsiveCards(
      onRefresh: _load,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemHeight: 132,
      itemCount: _orders!.length,
      itemBuilder: (_, i) => _OrderCard(order: _orders![i], onChanged: _load),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onChanged;
  const _OrderCard({required this.order, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? '').toString();
    final lines = (order['lines'] ?? []) as List;
    final prepared = lines.where((l) => l['prepared'] == true).length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OrderPrepareScreen(orderId: order['id'] as int)));
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(order['number'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
                  const Spacer(),
                  Pill((order['status_display'] ?? status).toString(),
                      statusColors[status] ?? kMuted),
                ],
              ),
              const SizedBox(height: 6),
              Text(order['client_name'] ?? '',
                  style: const TextStyle(color: kInk, fontSize: 15)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.scale_outlined, size: 16, color: kMuted),
                  const SizedBox(width: 4),
                  Text('${order['total_weight_kg'] ?? 0} kg',
                      style: const TextStyle(color: kMuted, fontSize: 13)),
                  const SizedBox(width: 16),
                  const Icon(Icons.checklist, size: 16, color: kMuted),
                  const SizedBox(width: 4),
                  Text('$prepared / ${lines.length} ${t('lines')}',
                      style: const TextStyle(color: kMuted, fontSize: 13)),
                  const Spacer(),
                  if ((order['required_by'] ?? '') != '')
                    Text('by ${order['required_by']}',
                        style: const TextStyle(color: kWarn, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
