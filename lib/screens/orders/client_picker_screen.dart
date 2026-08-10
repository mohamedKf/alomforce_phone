// client_picker_screen.dart — choose a client for a new order, or add one.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'add_client_screen.dart';

class ClientPickerScreen extends StatefulWidget {
  const ClientPickerScreen({super.key});

  @override
  State<ClientPickerScreen> createState() => _ClientPickerScreenState();
}

class _ClientPickerScreenState extends State<ClientPickerScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<dynamic>? _clients;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final q = <String, String>{'active': 'true'};
      if (_search.text.trim().isNotEmpty) q['search'] = _search.text.trim();
      final data = await api.get('/clients/', query: q);
      final rows = data is Map ? (data['results'] ?? []) : data;
      if (mounted) setState(() => _clients = rows as List);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _addNew() async {
    final created = await Navigator.of(context).push<Map>(
        MaterialPageRoute(builder: (_) => const AddClientScreen()));
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Choose client'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: t('Search clients'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48), backgroundColor: kBlue),
              icon: const Icon(Icons.person_add_alt),
              label: Text(t('Add new client')),
              onPressed: _addNew,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: t('Retry'), onAction: _load);
    }
    if (_clients == null) return const Center(child: CircularProgressIndicator());
    if (_clients!.isEmpty) {
      return EmptyState(Icons.person_off_outlined, t('No clients found.'));
    }
    return ListView.separated(
      itemCount: _clients!.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = _clients![i] as Map;
        final sub = [c['city'], c['phone']]
            .where((s) => (s ?? '').toString().isNotEmpty)
            .join(' · ');
        return ListTile(
          title: Text(c['name']?.toString() ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
          subtitle: sub.isEmpty ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pop(c),
        );
      },
    );
  }
}
