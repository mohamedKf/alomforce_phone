// new_order_screen.dart — a stock worker / driver creates an order for a client.
//
// Pick (or add) a client, add profile lines from the catalog (photos + filters)
// with total metres, then save. Weight and price are computed on the server.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../warehouse/stock_screen.dart' show imageUrl;
import 'catalog_picker_screen.dart';
import 'client_picker_screen.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  Map? _client;
  final List<Map> _lines = []; // {profile, description, total_length_m}
  bool _saving = false;
  String? _error;

  Future<void> _pickClient() async {
    final chosen = await Navigator.of(context).push<Map>(
        MaterialPageRoute(builder: (_) => const ClientPickerScreen()));
    if (chosen != null && mounted) setState(() => _client = chosen);
  }

  Future<void> _addLine() async {
    // 1) Browse the catalog (photos + Series/Type filters) and pick a profile.
    final profile = await Navigator.of(context).push<Map>(
        MaterialPageRoute(builder: (_) => const CatalogPickerScreen()));
    if (profile == null || !mounted) return;
    // 2) Enter the total metres for that profile.
    final metres = await _askMetres(profile);
    if (metres == null || !mounted) return;
    setState(() => _lines.add({
          'profile': profile['number'],
          'description': profile['description'],
          'section_image': profile['section_image'],
          'total_length_m': metres,
        }));
  }

  Future<String?> _askMetres(Map profile) async {
    final ctl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${profile['number']} · ${profile['description'] ?? ''}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: t('Total metres'),
                border: const OutlineInputBorder(),
                suffixText: t('m'),
              ),
              onSubmitted: (_) => _confirmMetres(ctx, ctl.text),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50), backgroundColor: kBlue),
              onPressed: () => _confirmMetres(ctx, ctl.text),
              child: Text(t('Add')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmMetres(BuildContext ctx, String text) {
    final m = double.tryParse(text.trim());
    if (m != null && m > 0) Navigator.of(ctx).pop(m.toStringAsFixed(2));
  }

  Future<void> _save() async {
    if (_client == null) {
      setState(() => _error = t('Choose a client first.'));
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = t('Add at least one line.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final order = await api.post('/orders/', {
        'client': _client!['id'],
        'lines': _lines
            .map((l) => {
                  'profile': l['profile'],
                  'total_length_m': l['total_length_m'],
                })
            .toList(),
      });
      if (mounted) {
        showOk(context, t('Order created.'));
        Navigator.of(context).pop(order);
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
      appBar: AppBar(title: Text(t('New order'))),
      body: Bounded(ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Client card
          Card(
            child: ListTile(
              leading: const Icon(Icons.business_outlined, color: kNavy),
              title: Text(_client?['name']?.toString() ?? t('Choose client'),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _client == null ? kMuted : kInk)),
              subtitle: _client == null
                  ? null
                  : Text([_client!['city'], _client!['phone']]
                      .where((s) => (s ?? '').toString().isNotEmpty)
                      .join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickClient,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(t('Lines'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: Text(t('Add line')),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text(t('No lines yet.'),
                      style: const TextStyle(color: kMuted))),
            )
          else
            ..._lines.asMap().entries.map((e) => _lineTile(e.key, e.value)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: kDanger)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52), backgroundColor: kBlue),
            icon: const Icon(Icons.check),
            label: Text(_saving ? t('Saving…') : t('Create order')),
            onPressed: _saving ? null : _save,
          ),
        ],
      )),
    );
  }

  Widget _lineTile(int i, Map line) {
    final url = imageUrl(line['section_image']);
    return Card(
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: kBlueLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: url == null
              ? const Icon(Icons.image_not_supported_outlined, color: kMuted, size: 18)
              : Image.network(url, fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, color: kMuted, size: 18)),
        ),
        title: Text(line['profile']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
        subtitle: Text([
          if ((line['description'] ?? '').toString().isNotEmpty) line['description'],
          '${line['total_length_m']} ${t('m')}',
        ].join(' · ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: kDanger),
          onPressed: () => setState(() => _lines.removeAt(i)),
        ),
      ),
    );
  }
}
