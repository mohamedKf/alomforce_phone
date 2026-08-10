// profile_detail.dart — what a scanned QR resolves to: the profile and the
// series (group) it belongs to.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../theme.dart';
import '../../widgets.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String number;
  const ProfileDetailScreen({required this.number, super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  Map? _profile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await api.get('/catalog/profiles/${widget.number}/');
      if (mounted) setState(() => _profile = data as Map);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.number)),
      body: _error != null
          ? EmptyState(Icons.help_outline,
              'No profile matches "${widget.number}".',
              actionLabel: 'Retry', onAction: _load)
          : _profile == null
              ? const Center(child: CircularProgressIndicator())
              : _body(),
    );
  }

  Widget _body() {
    final p = _profile!;
    final series = (p['series_codes'] ?? []) as List;
    final image = p['section_image'];
    final weightG = p['weight_g_per_m'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (image != null)
          Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLine),
            ),
            padding: const EdgeInsets.all(12),
            child: Image.network(image.toString(), fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.image_not_supported, color: kMuted, size: 40)),
          ),
        const SizedBox(height: 16),
        Text(p['number'] ?? '',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kNavy)),
        if ((p['description'] ?? '') != '') ...[
          const SizedBox(height: 4),
          Text(p['description'],
              style: const TextStyle(fontSize: 16, color: kInk)),
        ],
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _row('Weight', weightG != null ? '$weightG g/m' : '—'),
                const Divider(height: 1),
                _row('Weight', p['weight_kg_per_m'] != null
                    ? '${p['weight_kg_per_m']} kg/m'
                    : '—'),
                const Divider(height: 1),
                _rowWidget('Series (group)', _seriesChips(series)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _seriesChips(List series) {
    if (series.isEmpty) return const Text('—', style: TextStyle(color: kMuted));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        for (final s in series) Pill(s.toString(), kBlue),
      ],
    );
  }

  Widget _row(String label, String value) => _rowWidget(
        label,
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
      );

  Widget _rowWidget(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kMuted)),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}
