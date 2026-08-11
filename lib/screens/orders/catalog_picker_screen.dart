// catalog_picker_screen.dart — browse the catalog (photos + Series/Type filters)
// and pick a profile for an order line. Returns the chosen listing map.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../warehouse/stock_screen.dart' show imageUrl;

class CatalogPickerScreen extends StatefulWidget {
  const CatalogPickerScreen({super.key});

  @override
  State<CatalogPickerScreen> createState() => _CatalogPickerScreenState();
}

class _CatalogPickerScreenState extends State<CatalogPickerScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<dynamic>? _items;
  Object? _error;

  List<dynamic> _series = [];
  List<dynamic> _types = [];
  String? _fSeries;
  String? _fType;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final series = await api.get('/catalog/series/');
      final roles = await api.get('/catalog/listings/roles/');
      if (mounted) {
        setState(() {
          _series = series is List ? series : (series['results'] ?? []);
          _types = roles is List ? roles : [];
        });
      }
    } catch (_) {}
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final q = <String, String>{};
      if (_search.text.trim().isNotEmpty) q['search'] = _search.text.trim();
      if (_fSeries != null) q['series'] = _fSeries!;
      if (_fType != null) q['role'] = _fType!;
      final data = await api.get('/catalog/listings/', query: q);
      final rows = data is Map ? (data['results'] ?? []) : data;
      if (mounted) setState(() => _items = rows as List);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _hasFilter => _fSeries != null || _fType != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Choose a profile'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: t('Search profile number…'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load();
                        }),
              ),
            ),
          ),
          _filterBar(),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(t('Series'), _fSeries,
              _series
                  .map((s) => (
                        s['code'].toString(),
                        '${s['code']}  ${s['family_name'] ?? ''}'.trim()
                      ))
                  .toList(),
              (v) => setState(() => _fSeries = v)),
          _chip(t('Type'), _typeLabel,
              _types
                  .map((r) => (r['value'].toString(), t(r['label'].toString())))
                  .toList(),
              (v) => setState(() => _fType = v)),
          if (_hasFilter)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _fSeries = null;
                    _fType = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.clear, size: 16),
                label: Text(t('Clear')),
              ),
            ),
        ],
      ),
    );
  }

  String? get _typeLabel {
    if (_fType == null) return null;
    final m = _types.firstWhere((r) => r['value'] == _fType, orElse: () => null);
    return m == null ? _fType : t(m['label'].toString());
  }

  Widget _chip(String label, String? selectedLabel,
      List<(String, String)> options, ValueChanged<String?> onPick) {
    final active = selectedLabel != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ActionChip(
        avatar: Icon(Icons.arrow_drop_down,
            size: 20, color: active ? Colors.white : kMuted),
        label: Text(active ? '$label: $selectedLabel' : label,
            style: TextStyle(color: active ? Colors.white : kInk, fontSize: 13)),
        backgroundColor: active ? kBlue : Colors.white,
        side: BorderSide(color: active ? kBlue : kLine),
        onPressed: () => _pick(label, options, onPick),
      ),
    );
  }

  Future<void> _pick(String title, List<(String, String)> options,
      ValueChanged<String?> onPick) async {
    final choice = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
          ),
          ListTile(
              title: Text(t('All')),
              onTap: () => Navigator.pop(context, '__all__')),
          for (final (value, label) in options)
            ListTile(title: Text(label), onTap: () => Navigator.pop(context, value)),
        ],
      ),
    );
    if (choice == null) return;
    onPick(choice == '__all__' ? null : choice);
    _load();
  }

  Widget _list() {
    if (_error != null) {
      return EmptyState(Icons.cloud_off, _error.toString(),
          actionLabel: t('Retry'), onAction: _load);
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (_items!.isEmpty) {
      return EmptyState(Icons.inventory_2_outlined, t('No profiles found.'));
    }
    return ResponsiveCards(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      itemHeight: 92,
      itemCount: _items!.length,
      itemBuilder: (_, i) => _card(_items![i] as Map),
    );
  }

  Widget _card(Map m) {
    final img = imageUrl(m['section_image']);
    final meta = [
      m['series_code'],
      if ((m['role_display'] ?? '').toString().isNotEmpty) t(m['role_display'].toString()),
    ].where((s) => (s ?? '').toString().isNotEmpty).join('  ·  ');
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(m),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kLine)),
          child: Row(
            children: [
              _thumb(img),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['number']?.toString() ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
                    if ((m['description'] ?? '').toString().isNotEmpty)
                      Text(m['description'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kInk, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(meta, style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(String? url) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: kBlueLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.image_not_supported_outlined, color: kMuted, size: 22)
          : Image.network(url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, color: kMuted, size: 22)),
    );
  }
}
