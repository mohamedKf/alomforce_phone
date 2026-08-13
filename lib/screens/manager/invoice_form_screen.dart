// invoice_form_screen.dart — add a supplier invoice, from a photo or by hand.
//
// The photo route sends the image to the server, which reads it with GPT
// vision and returns suggested values. They land in this form rather than in
// the database: a model misreading a total by one digit is a plausible
// failure, and an unreviewed one would go straight into the books.
//
// Every field is editable whether or not the scan ran, so an office with
// scanning switched off, an unreadable photo, or no signal all end up in the
// same place -- typing the invoice in, which is what they did before.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';
import '../../widgets.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _number = TextEditingController();
  final _party = TextEditingController();
  final _taxId = TextEditingController();
  final _category = TextEditingController();
  final _subtotal = TextEditingController();
  final _vat = TextEditingController();
  final _total = TextEditingController();

  DateTime _issued = DateTime.now();
  Uint8List? _fileBytes;
  String _fileName = '';

  bool _scanning = false;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    for (final c in [_number, _party, _taxId, _category, _subtotal, _vat,
        _total]) {
      c.dispose();
    }
    super.dispose();
  }

  // -- picking the document ---------------------------------------------

  Future<void> _fromCamera() async {
    final shot = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
    if (shot != null) await _use(await shot.readAsBytes(), shot.name, 'image/jpeg');
  }

  Future<void> _fromGallery() async {
    final shot = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    if (shot != null) await _use(await shot.readAsBytes(), shot.name, 'image/jpeg');
  }

  Future<void> _fromFiles() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    final isPdf = (f.extension ?? '').toLowerCase() == 'pdf';
    await _use(bytes, f.name, isPdf ? 'application/pdf' : 'image/jpeg');
  }

  Future<void> _use(Uint8List bytes, String name, String type) async {
    // `type` is carried by the multipart upload itself; the server reads
    // the content type from the part rather than a field we send.
    setState(() {
      _fileBytes = bytes;
      _fileName = name;
      _error = null;
      _notice = null;
    });
    await _scan();
  }

  // -- reading it --------------------------------------------------------

  Future<void> _scan() async {
    if (_fileBytes == null) return;
    setState(() {
      _scanning = true;
      _notice = null;
    });
    try {
      final r = await api.uploadBytes('/invoices/scan/',
          field: 'file', bytes: _fileBytes!, filename: _fileName);
      if (r is! Map) return;

      if (r['available'] != true) {
        // Scanning is switched off. Not a failure -- just type it in.
        setState(() => _notice = (r['detail'] ?? '').toString());
        return;
      }
      if (r['ok'] != true) {
        setState(() => _notice = (r['detail'] ?? '').toString());
        return;
      }
      final fields = Map<String, dynamic>.from(r['fields'] as Map);
      if (fields.values.every((v) => v == null || '$v'.isEmpty)) {
        setState(() => _notice = t('Nothing could be read from that photo. '
            'Enter the details by hand.'));
        return;
      }
      // Nothing is written into the form until the person says so. They are
      // holding the paper: they are the only one who can tell whether the
      // model read 1,180 or 1,780, and a wrong figure they never saw would go
      // into the books with their name on it.
      if (!mounted) return;
      final approved = await _confirmScan(fields);
      if (approved != true) {
        setState(() => _notice = t('Reading discarded. Enter the details by '
            'hand.'));
        return;
      }
      _fill(fields);
      setState(() => _notice = t('Filled from the photo. Check it before '
          'saving.'));
    } catch (e) {
      // The scan is a convenience; losing it must not lose the invoice.
      setState(() => _notice = t('Could not read the photo. Enter the details '
          'by hand.'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Show what was read and let the person accept or reject it.
  ///
  /// Deliberately a decision, not a notification: the alternative is the form
  /// silently changing under them, which is how a misread total gets saved
  /// without anyone having looked at it.
  Future<bool?> _confirmScan(Map<String, dynamic> f) {
    final labels = <String, String>{
      'party_name': t('Supplier'),
      'number': t('Invoice number'),
      'party_tax_id': t('Tax ID'),
      'issued_at': t('Invoice date'),
      'category': t('Category'),
      'subtotal': t('Before VAT'),
      'vat': t('VAT'),
      'total': t('Total'),
    };
    final found = labels.entries
        .where((e) => (f[e.key] ?? '').toString().isNotEmpty)
        .toList();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18, color: kBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('Read from the photo'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: kInk)),
              ),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(t('Check these against the paper before using them.'),
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final e in found)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(e.value,
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 13)),
                            ),
                            Expanded(
                              child: Text('${f[e.key]}',
                                  style: TextStyle(
                                      color: kInk,
                                      fontSize: e.key == 'total' ? 17 : 14,
                                      fontWeight: e.key == 'total'
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t('Type it myself')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: kBlue),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(t('Use these')),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _fill(Map<String, dynamic> f) {
    void set(TextEditingController c, String key) {
      final v = f[key];
      if (v != null && v.toString().isNotEmpty) c.text = v.toString();
    }

    set(_number, 'number');
    set(_party, 'party_name');
    set(_taxId, 'party_tax_id');
    set(_category, 'category');
    set(_subtotal, 'subtotal');
    set(_vat, 'vat');
    set(_total, 'total');
    final date = DateTime.tryParse((f['issued_at'] ?? '').toString());
    if (date != null) setState(() => _issued = date);
  }

  // -- saving ------------------------------------------------------------

  Future<void> _save() async {
    if (_total.text.trim().isEmpty) {
      setState(() => _error = t('Enter the total.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fields = <String, String>{
        'direction': 'expense',
        'number': _number.text.trim(),
        'party_name': _party.text.trim(),
        'party_tax_id': _taxId.text.trim(),
        'category': _category.text.trim(),
        'issued_at': DateFormat('yyyy-MM-dd').format(_issued),
        'subtotal': _subtotal.text.trim().isEmpty ? '0' : _subtotal.text.trim(),
        'vat': _vat.text.trim().isEmpty ? '0' : _vat.text.trim(),
        'total': _total.text.trim(),
        // 'scanned' when a photo was read, so the books show where a figure
        // came from and a wrong one can be traced back to its image.
        'source': _fileBytes != null ? 'scanned' : 'manual',
      };

      if (_fileBytes != null) {
        await api.uploadBytes('/invoices/', field: 'file',
            bytes: _fileBytes!, filename: _fileName, fields: fields);
      } else {
        await api.post('/invoices/', fields);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(t('Add invoice'))),
      body: Bounded(ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. The document itself. First, because photographing the paper is
          // the whole point -- everything below is what the photo filled in.
          _card(
            icon: Icons.receipt_long_outlined,
            title: t('The invoice'),
            children: [
              Row(children: [
                Expanded(child: _sourceButton(
                    Icons.photo_camera_outlined, t('Camera'), _fromCamera)),
                const SizedBox(width: 8),
                Expanded(child: _sourceButton(
                    Icons.photo_library_outlined, t('Gallery'), _fromGallery)),
                const SizedBox(width: 8),
                Expanded(child: _sourceButton(
                    Icons.description_outlined, t('File'), _fromFiles)),
              ]),
              if (_fileName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.attach_file, size: 16, color: kMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ),
                  if (_scanning)
                    const SizedBox(height: 14, width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kBlue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_notice!,
                      style: const TextStyle(color: kInk, fontSize: 12)),
                ),
              ],
            ],
          ),

          // 2. Who it is from.
          _card(
            icon: Icons.store_outlined,
            title: t('Supplier'),
            children: [
              _field(_party, t('Supplier name')),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _field(_number, t('Invoice number'))),
                const SizedBox(width: 12),
                Expanded(child: _field(_taxId, t('Tax ID'),
                    keyboard: TextInputType.number)),
              ]),
            ],
          ),

          // 3. When, and what kind of spend.
          _card(
            icon: Icons.event_outlined,
            title: t('Details'),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _dateField()),
                const SizedBox(width: 12),
                Expanded(child: _field(_category, t('Category'))),
              ]),
            ],
          ),

          // 4. Money. The total is given its own emphasis: it is the number
          // that has to be right, and the one somebody checks against the paper.
          _card(
            icon: Icons.payments_outlined,
            title: t('Amounts'),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _field(_subtotal, t('Before VAT'),
                    keyboard: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 12),
                Expanded(child: _field(_vat, t('VAT'),
                    keyboard: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 12),
              _field(_total, t('Total'),
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  emphasis: true),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: kDanger)),
          ],
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54), backgroundColor: kBlue),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? t('Saving…') : t('Save invoice'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      )),
    );
  }

  /// A titled group. Fields belong to a subject -- supplier, amounts -- and
  /// reading one long column gives no clue where one subject ends.
  Widget _card({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 17, color: kBlue),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: kInk, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _sourceButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(horizontal: 4)),
      onPressed: _scanning ? null : onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    );
  }

  Widget _dateField() {
    return InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _issued,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (picked != null) setState(() => _issued = picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: t('Invoice date'), border: const OutlineInputBorder()),
        child: Text(DateFormat('yyyy-MM-dd').format(_issued)),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard, bool emphasis = false}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: TextStyle(
        fontSize: emphasis ? 20 : 15,
        fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
        color: kInk,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: emphasis ? '₪ ' : null,
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: emphasis ? 16 : 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: emphasis,
        fillColor: emphasis ? kBlue.withValues(alpha: .06) : null,
      ),
    );
  }
}
