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
      _fill(Map<String, dynamic>.from(r['fields'] as Map));
      setState(() => _notice = t('Read from the photo. Check it before saving.'));
    } catch (e) {
      // The scan is a convenience; losing it must not lose the invoice.
      setState(() => _notice = t('Could not read the photo. Enter the details '
          'by hand.'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
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
      appBar: AppBar(title: Text(t('Add invoice'))),
      body: Bounded(ListView(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.attach_file, size: 16, color: kMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(_fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 12))),
              if (_scanning)
                const SizedBox(
                    height: 14, width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_notice!,
                  style: const TextStyle(color: kInk, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 18),
          _field(_party, t('Supplier')),
          _field(_number, t('Invoice number')),
          _field(_taxId, t('Tax ID'), keyboard: TextInputType.number),
          _dateField(),
          _field(_category, t('Category')),
          _field(_subtotal, t('Before VAT'),
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _field(_vat, t('VAT'),
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          _field(_total, t('Total'),
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: kDanger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52), backgroundColor: kBlue),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? t('Saving…') : t('Save invoice')),
          ),
        ],
      )),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
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
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
