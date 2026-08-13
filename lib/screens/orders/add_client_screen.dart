// add_client_screen.dart — quickly add a new client while creating an order.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _tax = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _mapLink = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _tax, _city, _address, _mapLink]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = t('Business name is required.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await api.post('/clients/', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'tax_id': _tax.text.trim(),
        'city': _city.text.trim(),
        'delivery_address': _address.text.trim(),
        // The server turns this into the delivery coordinate; the driver's
        // Waze button then navigates to the pin instead of the street name.
        'location_url': _mapLink.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(created as Map);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Add client'))),
      body: Bounded(ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_name, t('Business name'), required: true),
          _field(_phone, t('Phone'), keyboard: TextInputType.phone),
          _field(_tax, t('Tax ID')),
          _field(_city, t('City')),
          _field(_address, t('Delivery address'), lines: 2),
          _field(_mapLink, t('Map link'), keyboard: TextInputType.url),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              t('Share the place from Google Maps, Waze or Apple Maps and '
                  'paste the link. The driver is sent to this exact point.'),
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: kDanger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52), backgroundColor: kBlue),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? t('Saving…') : t('Save client')),
          ),
        ],
      )),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, TextInputType? keyboard, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
