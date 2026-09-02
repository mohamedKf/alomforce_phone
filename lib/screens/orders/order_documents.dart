// order_documents.dart — the papers that came with an order, on a phone.
//
// An aluminium order is rarely worked from the order lines alone. It comes
// with a fabrication drawing, an architect's elevation, or a cutting list the
// customer worked out themselves — as a PDF if the office got it by email, and
// as a sheet of paper on the counter if the fabricator walked in with it. So
// the phone can do both: attach a file, or photograph the paper where it is
// standing.
//
// Anyone in the workshop can add one; they are the ones holding the paper.
// Only the office can remove one, because the sheet is what somebody is
// cutting to.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

const _kinds = [
  ('drawing', 'Drawing'),
  ('other', 'Other'),
];

class OrderDocumentsScreen extends StatefulWidget {
  const OrderDocumentsScreen({super.key, required this.order});

  final Map order;

  @override
  State<OrderDocumentsScreen> createState() => _OrderDocumentsScreenState();
}

class _OrderDocumentsScreenState extends State<OrderDocumentsScreen> {
  List _rows = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  int get _orderId => widget.order['id'] as int;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.get('/orders/$_orderId/attachments/');
      if (!mounted) return;
      setState(() {
        _rows = data is List ? data : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiError ? e.message : t('Could not load the documents.');
      });
    }
  }

  // -- adding ------------------------------------------------------------

  Future<void> _pick() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: kNavy),
              title: Text(t('Photograph the sheet')),
              subtitle: Text(t('For a paper copy on the counter')),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kNavy),
              title: Text(t('Choose a photo')),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: kNavy),
              title: Text(t('Choose a file')),
              subtitle: Text(t('A PDF the engineer sent')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      switch (choice) {
        case 'camera':
        case 'gallery':
          final shot = await ImagePicker().pickImage(
            source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
            // A bar schedule is read for its numbers, so it needs more
            // resolution than a receipt: 2000px keeps a 13-row sheet legible.
            imageQuality: 88,
            maxWidth: 2400,
          );
          if (shot == null) return;
          await _send(await shot.readAsBytes(), shot.name);
          break;
        case 'file':
          final picked = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic']);
          if (picked == null || picked.files.isEmpty) return;
          final f = picked.files.first;
          final bytes = f.bytes ?? await File(f.path!).readAsBytes();
          await _send(bytes, f.name);
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _send(Uint8List bytes, String filename) async {
    // Which sheet it is, and for which plan. Asked once, here, rather than
    // left blank — a yard with six unlabelled photos on an order is no better
    // off than one with none.
    final details = await _askDetails(filename);
    if (details == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.uploadBytes(
        '/orders/$_orderId/attachments/',
        field: 'file',
        bytes: bytes,
        filename: filename,
        fields: {'kind': details.$1, 'note': details.$2},
      );
      if (!mounted) return;
      showOk(context, t('Document added.'));
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiError ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(String, String)?> _askDetails(String filename) {
    var kind = 'drawing';
    final note = TextEditingController();
    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(filename,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: kInk, fontSize: 15)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: InputDecoration(
                  labelText: t('What is it'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final (value, label) in _kinds)
                    DropdownMenuItem(value: value, child: Text(t(label))),
                ],
                onChanged: (v) => setSheet(() => kind = v ?? kind),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: t('Note'),
                  hintText: t('Which plan, e.g. +6.12'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: kBlue),
                onPressed: () =>
                    Navigator.pop(ctx, (kind, note.text.trim())),
                child: Text(t('Add')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- opening and removing ----------------------------------------------

  Future<void> _open(Map row) async {
    // The file is behind the API, so it needs the token. url_launcher cannot
    // carry one; the bytes are fetched here and written where the system
    // viewer can reach them.
    //
    // A generated document has no stored file: it is rendered from the order
    // when it is asked for, so it always matches the order as it stands. The
    // server sends the path for every row, which is what to follow -- there
    // is more than one generated document now, and guessing the route here
    // fetched the wrong one.
    final path = (row['path'] ?? '').toString().isNotEmpty
        ? row['path'].toString().replaceFirst('/api', '')
        : '/orders/$_orderId/attachments/${row['id']}/';
    setState(() => _busy = true);
    try {
      final bytes = await api.getBytes(path);
      final dir = Directory.systemTemp.createTempSync('alomforce');
      final file = File('${dir.path}/${row['filename'] ?? 'document'}');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await launchUrl(Uri.file(file.path));
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiError ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Map row) async {
    if (row['generated'] == true) {
      // Nothing to remove: it is not a file. It stops being listed when the
      // order stops having bars on it.
      setState(() => _error = t('The cutting list is made from the order.'));
      return;
    }
    try {
      await api.delete('/orders/$_orderId/attachments/${row['id']}/', {});
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiError && e.status == 403
          // Not a failure to explain away: the sheet is what the floor is
          // bending to, and taking it away is an office decision.
          ? t('Only the office can remove a document.')
          : (e is ApiError ? e.message : e.toString());
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Documents')),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _pick,
        backgroundColor: kBlue,
        icon: const Icon(Icons.add),
        label: Text(t('Add')),
      ),
      body: Bounded(RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            Text('${widget.order['number'] ?? ''}  ·  '
                '${widget.order['client_name'] ?? ''}',
                style: const TextStyle(color: kMuted)),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: kDanger)),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 40, color: kMuted),
                    const SizedBox(height: 10),
                    Text(t('Nothing attached yet.'),
                        style: const TextStyle(color: kMuted)),
                    const SizedBox(height: 4),
                    Text(t('Photograph the bar schedule or attach the PDF.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              )
            else
              ..._rows.map(_tile),
          ],
        ),
      )),
    );
  }

  Widget _tile(dynamic row) {
    final isPdf = row['is_pdf'] == true;
    return Card(
      child: ListTile(
        onTap: () => _open(row as Map),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kBlueLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kLine),
          ),
          child: Icon(
              row['generated'] == true
                  ? Icons.auto_awesome_motion_outlined
                  : (isPdf ? Icons.picture_as_pdf_outlined
                           : Icons.image_outlined),
              color: kNavy, size: 20),
        ),
        title: Text('${row['filename'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
        subtitle: Text([
          row['kind_display'],
          if ((row['note'] ?? '').toString().isNotEmpty) row['note'],
          if ((row['uploaded_by_name'] ?? '').toString().isNotEmpty)
            row['uploaded_by_name'],
        ].where((s) => (s ?? '').toString().isNotEmpty).join(' · ')),
        trailing: row['generated'] == true
            ? Pill(t('Live'), kNavy)
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: kDanger),
                onPressed: () => _remove(row as Map),
              ),
      ),
    );
  }
}
