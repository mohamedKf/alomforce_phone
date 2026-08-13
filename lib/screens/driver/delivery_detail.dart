// delivery_detail.dart — one delivery: who, where (Waze), load on the truck,
// sign on arrival, then send the signed note to the client on WhatsApp.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'signature_pad.dart';

class DeliveryDetail extends StatefulWidget {
  final Map delivery;
  const DeliveryDetail({super.key, required this.delivery});

  @override
  State<DeliveryDetail> createState() => _DeliveryDetailState();
}

class _DeliveryDetailState extends State<DeliveryDetail> {
  late final Map _d = Map.of(widget.delivery);
  bool _busy = false;

  bool get _signed => _d['signed'] == true;
  bool get _hasLocation =>
      _d['latitude'] != null && _d['longitude'] != null ||
      (_d['address'] ?? '').toString().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final address = [_d['address'], _d['city']]
        .where((s) => (s ?? '').toString().isNotEmpty)
        .join(', ');
    final status = (_d['status'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(_d['number']?.toString() ?? t('Delivery'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            Row(children: [
              Expanded(
                child: Text(_d['client_name'] ?? '—',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
              ),
              Pill(t(_d['status_display']?.toString() ?? 'To deliver'),
                  _signed ? kSuccess : kBlue),
            ]),
            const SizedBox(height: 12),
            _row(Icons.scale_outlined,
                '${_d['total_weight_kg']} ${t('kg')}  ·  ${_d['line_count']} ${t('lines')}'),
            if (address.isNotEmpty) _row(Icons.place_outlined, address),
            if ((_d['client_phone'] ?? '').toString().isNotEmpty)
              _row(Icons.phone_outlined, _d['client_phone'].toString()),
            if ((_d['required_by'] ?? '').toString().isNotEmpty)
              _row(Icons.event_outlined, '${t('Required by')} ${_d['required_by']}'),
          ]),
          const SizedBox(height: 16),
          if (_hasLocation)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.navigation_outlined),
              label: Text(t('Open in Waze')),
              onPressed: _openWaze,
            ),
          const SizedBox(height: 10),
          if (_signed) ...[
            _card([
              Row(children: [
                const Icon(Icons.verified, color: kSuccess),
                const SizedBox(width: 8),
                Text(t('Delivered & signed'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: kInk, fontSize: 15)),
              ]),
              if ((_d['signed_at'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                    '${t('Signed')} ${_d['signed_at'].toString().replaceFirst('T', ' ').split('.').first}',
                    style: const TextStyle(color: kMuted, fontSize: 13)),
              ],
            ]),
            const SizedBox(height: 10),
            // One button per person the note goes to. WhatsApp opens outside
            // the app and handles one chat at a time, so this cannot be a
            // single "send to both" -- two buttons is the honest shape, and it
            // doubles as the re-send: they stay here for any signed delivery.
            Text(t('Send the delivery note'),
                style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 6),
            _sendButton(
              label: _recipientName.isEmpty
                  ? t('Send to the person who signed')
                  : '${t('Send to')} $_recipientName',
              phone: _recipientPhone,
            ),
            const SizedBox(height: 8),
            _sendButton(
              label: _clientContact.isEmpty
                  ? t('Send to the client')
                  : '${t('Send to')} $_clientContact',
              phone: _clientPhone,
            ),
          ] else ...[
            if (status == 'ready')
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(_busy ? t('Saving…') : t('Load on truck')),
                onPressed: _busy ? null : _start,
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52), backgroundColor: kBlue),
              icon: const Icon(Icons.draw_outlined),
              label: Text(t('Sign & complete delivery')),
              onPressed: _openSignature,
            ),
          ],
        ],
      ),
    );
  }

  // -- actions ---------------------------------------------------------

  Future<void> _openWaze() async {
    final lat = _d['latitude'], lng = _d['longitude'];
    final url = (lat != null && lng != null)
        ? 'https://waze.com/ul?ll=$lat,$lng&navigate=yes'
        : 'https://waze.com/ul?q=${Uri.encodeComponent([
              _d['address'],
              _d['city']
            ].where((s) => (s ?? '').toString().isNotEmpty).join(', '))}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final r = await api.post('/orders/${_d['id']}/start_delivery/', {});
      if (mounted && r is Map) setState(() => _d.addAll(r));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSignature() async {
    final result = await Navigator.of(context).push<Map>(MaterialPageRoute(
        builder: (_) => SignaturePad(
              orderId: _d['id'] as int,
              orderNumber: _d['number']?.toString() ?? '',
              clientName: _d['client_name']?.toString() ?? '',
              clientPhone: _d['client_phone']?.toString() ?? '',
            )));
    if (result != null && mounted) {
      setState(() {
        _d['signed'] = true;
        _d['signed_at'] = result['delivery_signed_at'] ?? _d['signed_at'];
        _d['status'] = 'delivered';
        _d['status_display'] = 'Delivered';
        _d['public_url'] = result['public_url'] ?? _d['public_url'];
        // Recipient details come back from the server, so the send buttons
        // below work from stored data rather than this screen's memory.
        for (final k in ['recipient_name', 'recipient_phone', 'client_phone',
            'client_contact_name']) {
          if ((result[k] ?? '').toString().isNotEmpty) _d[k] = result[k];
        }
      });
      // Straight to the person who just signed; the client's own contact is
      // one tap away on the button underneath.
      _sendWhatsApp(_recipientPhone);
    }
  }

  // Who the note goes to. Both come from the server, so a re-send still works
  // days later in an app that has been restarted since the signature.
  String get _recipientName => (_d['recipient_name'] ?? '').toString().trim();
  String get _recipientPhone => (_d['recipient_phone'] ?? '').toString().trim();
  String get _clientContact =>
      (_d['client_contact_name'] ?? '').toString().trim();
  String get _clientPhone => (_d['client_phone'] ?? '').toString().trim();

  Widget _sendButton({required String label, required String phone}) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: const Color(0xFF25D366)),
      icon: const Icon(Icons.chat),
      label: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: () => _sendWhatsApp(phone),
    );
  }

  /// Open WhatsApp with the signed note's link, addressed to [phone].
  ///
  /// An empty number still opens WhatsApp with the message ready, so the
  /// driver can pick the chat by hand rather than hitting a dead end.
  Future<void> _sendWhatsApp(String rawPhone) async {
    final link = (_d['public_url'] ?? '').toString();
    final msg = t('Delivery note {number} for {client}. View & download: {link}')
        .replaceFirst('{number}', _d['number']?.toString() ?? '')
        .replaceFirst('{client}', _d['client_name']?.toString() ?? '')
        .replaceFirst('{link}', link);
    final phone = _waPhone(rawPhone);
    final url = phone.isEmpty
        ? 'https://wa.me/?text=${Uri.encodeComponent(msg)}'
        : 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Normalise an Israeli number to wa.me form: digits only, 0-prefix → 972.
  String _waPhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '972${d.substring(1)}';
    return d;
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 17, color: kMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: kInk, fontSize: 14))),
        ]),
      );
}
