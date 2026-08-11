// driver_home.dart — the driver's deliveries, shown as a tab inside the worker
// home (a driver is a stock worker who also delivers mid-day).
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'delivery_detail.dart';

/// The Deliveries tab: To-deliver / Delivered, used inside WarehouseHome for
/// the driver role.
class DeliveriesTab extends StatelessWidget {
  const DeliveriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              labelColor: kBlue,
              unselectedLabelColor: kMuted,
              indicatorColor: kBlue,
              tabs: [Tab(text: t('To deliver')), Tab(text: t('Delivered'))],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [
              DeliveriesList(done: false),
              DeliveriesList(done: true),
            ]),
          ),
        ],
      ),
    );
  }
}

class DeliveriesList extends StatefulWidget {
  final bool done;
  const DeliveriesList({super.key, required this.done});

  @override
  State<DeliveriesList> createState() => _DeliveriesListState();
}

class _DeliveriesListState extends State<DeliveriesList>
    with AutomaticKeepAliveClientMixin {
  List<dynamic>? _rows;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await api.get('/orders/deliveries/',
          query: {'done': widget.done ? 'true' : 'false'});
      if (mounted) setState(() => _rows = (data as List));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: 'Retry', onAction: _load);
    }
    if (_rows == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows!.isEmpty) {
      return EmptyState(
          widget.done ? Icons.inbox_outlined : Icons.local_shipping_outlined,
          widget.done ? 'No deliveries yet.' : 'Nothing to deliver right now.',
          actionLabel: 'Refresh', onAction: _load);
    }
    return ResponsiveCards(
      onRefresh: _load,
      padding: const EdgeInsets.all(14),
      itemHeight: 140,
      itemCount: _rows!.length,
      itemBuilder: (_, i) => _DeliveryCard(_rows![i], onOpened: _load),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Map delivery;
  final VoidCallback onOpened;
  const _DeliveryCard(this.delivery, {required this.onOpened});

  @override
  Widget build(BuildContext context) {
    final signed = delivery['signed'] == true;
    final address = [delivery['address'], delivery['city']]
        .where((s) => (s ?? '').toString().isNotEmpty)
        .join(' · ');
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DeliveryDetail(delivery: delivery)));
          onOpened();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(delivery['client_name'] ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: kInk)),
                  ),
                  Pill(signed ? 'Signed' : 'To deliver',
                      signed ? kSuccess : kBlue),
                ],
              ),
              const SizedBox(height: 4),
              Text('${delivery['number']}  ·  ${delivery['total_weight_kg']} kg'
                  '  ·  ${delivery['line_count']} lines',
                  style: const TextStyle(color: kMuted, fontSize: 13)),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 15, color: kMuted),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(address,
                          style: const TextStyle(color: kInk, fontSize: 13))),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
