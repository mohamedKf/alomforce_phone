// stock_screen.dart — browse stock with photos and filters (series, type,
// finish), and record movements (receive / pick / adjust).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Absolute URL for a section image (handles a relative /media/ path too).
String? imageUrl(dynamic raw) {
  final s = (raw ?? '').toString();
  if (s.isEmpty) return null;
  return s.startsWith('http') ? s : '${api.serverUrl}$s';
}

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<dynamic>? _items;
  Object? _error;

  // Filter option lists (from /stock/options/) and the current selection.
  List<dynamic> _series = [];
  List<dynamic> _types = [];
  List<String> _finishes = [];
  String? _fSeries;
  String? _fType;
  String? _fFinish;

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
      final o = await api.get('/stock/options/');
      if (mounted) {
        setState(() {
          _series = (o['series'] as List?) ?? [];
          _types = (o['roles'] as List?) ?? [];
          _finishes = ((o['finishes'] as List?) ?? []).cast<String>();
        });
      }
    } catch (_) {}
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final query = <String, String>{};
      final text = _search.text.trim();
      if (text.isNotEmpty) query['search'] = text;
      if (_fSeries != null) query['series'] = _fSeries!;
      if (_fType != null) query['role'] = _fType!;
      if (_fFinish != null) query['finish'] = _fFinish!;
      final data = await api.get('/stock/', query: query);
      final rows = data is Map ? (data['results'] ?? []) : data;
      if (mounted) setState(() => _items = rows as List);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _hasFilter => _fSeries != null || _fType != null || _fFinish != null;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              _series.map((s) => (s['code'].toString(), s['name'].toString())).toList(),
              (v) => setState(() => _fSeries = v)),
          _chip(t('Type'), _typeLabel,
              _types.map((r) => (r['value'].toString(), t(r['label'].toString()))).toList(),
              (v) => setState(() => _fType = v)),
          _chip(t('Finish'), _fFinish,
              _finishes.map((f) => (f, f)).toList(),
              (v) => setState(() => _fFinish = v)),
          if (_hasFilter)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _fSeries = null;
                    _fType = null;
                    _fFinish = null;
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
            onTap: () => Navigator.pop(context, '__all__'),
          ),
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
      return EmptyState(Icons.inventory_2_outlined, t('No stock found.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _StockCard(item: _items![i], onChanged: _load),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final Map item;
  final VoidCallback onChanged;
  const _StockCard({required this.item, required this.onChanged});

  Color get _qtyColor {
    final qty = (item['quantity'] ?? 0) as int;
    if (qty <= 0) return kDanger;
    if (item['needs_reorder'] == true) return kWarn;
    return kSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final finish = (item['finish'] ?? '').toString();
    final lenM = (int.tryParse('${item['length_mm'] ?? 0}') ?? 0) / 1000;
    final series = ((item['series_codes'] as List?) ?? []).join(', ');
    final types = ((item['types'] as List?) ?? [])
        .map((ty) => t(ty['label'].toString()))
        .join(' · ');
    final img = imageUrl(item['section_image']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(img),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['number'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
                      if ((item['description'] ?? '').toString().isNotEmpty)
                        Text(item['description'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kInk, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (series.isNotEmpty) series,
                          if (types.isNotEmpty) types,
                        ].join('  ·  '),
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item['quantity'] ?? 0}',
                        style: TextStyle(
                            color: _qtyColor, fontWeight: FontWeight.w700, fontSize: 18)),
                    Text(t('bars'), style: const TextStyle(color: kMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (finish.isNotEmpty) finish,
                if (lenM > 0) '${_g(lenM)} m',
                if ((item['warehouse'] ?? '') != '') item['warehouse'],
              ].join(' · '),
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _btn(context, t('Receive'), 'receive', Icons.add, kSuccess),
                const SizedBox(width: 6),
                _btn(context, t('Pick'), 'pick', Icons.remove, kNavy),
                const SizedBox(width: 6),
                _btn(context, t('Adjust'), 'adjust', Icons.tune, kMuted),
              ],
            ),
          ],
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

  Widget _btn(BuildContext c, String label, String mode, IconData icon, Color color) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _move(c, mode),
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 13)),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 42)),
      ),
    );
  }

  Future<void> _move(BuildContext context, String mode) async {
    final titles = {
      'receive': t('Receive stock'),
      'pick': t('Pick / ship'),
      'adjust': t('Adjust count')
    };
    final labels = {
      'receive': t('Bars received'),
      'pick': t('Bars picked'),
      'adjust': t('Counted quantity')
    };
    final current = (item['quantity'] ?? 0) as int;
    final controller = TextEditingController(text: mode == 'adjust' ? '$current' : '');
    final noteCtl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${titles[mode]} — ${item['number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t('On hand')}: $current ${t('bars')}',
                style: const TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: labels[mode]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtl,
              decoration: InputDecoration(labelText: t('Note (optional)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Save'))),
        ],
      ),
    );
    if (result != true) return;
    final qty = int.tryParse(controller.text.trim());
    if (qty == null) return;
    Map body;
    if (mode == 'adjust') {
      final delta = qty - current;
      if (delta == 0) return;
      body = {'movement_type': 'adjustment', 'quantity': delta};
    } else {
      body = {'movement_type': mode == 'receive' ? 'receipt' : 'pick', 'quantity': qty};
    }
    body['note'] = noteCtl.text.trim();
    try {
      await api.post('/stock/${item['id']}/move/', body);
      if (context.mounted) showOk(context, t('Stock updated.'));
      onChanged();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  static String _g(num v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
