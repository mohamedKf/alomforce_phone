// signature_pad.dart — capture the recipient's signature and complete delivery.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../i18n.dart';
import '../../theme.dart';

class SignaturePad extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final String clientName;
  final String clientPhone;
  const SignaturePad({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.clientName = '',
    this.clientPhone = '',
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  // Each stroke is a list of points; a new stroke starts on pen-down.
  final List<List<Offset>> _strokes = [];
  // Pre-filled from the client, but editable — whoever actually receives the
  // goods may differ, and the WhatsApp copy can go to a different number.
  late final _name = TextEditingController(text: widget.clientName);
  late final _phone = TextEditingController(text: widget.clientPhone);
  bool _saving = false;
  String? _error;
  Size _canvasSize = Size.zero;

  bool get _hasInk => _strokes.any((s) => s.length > 1);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${t('Sign')} — ${widget.orderNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t('Received by (name)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t('Phone (for WhatsApp)'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.chat),
              ),
            ),
            const SizedBox(height: 14),
            Text(t('Signature'), style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                _canvasSize = Size(c.maxWidth, c.maxHeight);
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kLine),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GestureDetector(
                    onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                    onPanUpdate: (d) => setState(() {
                      if (_strokes.isNotEmpty) _strokes.last.add(d.localPosition);
                    }),
                    child: CustomPaint(
                      painter: _SignaturePainter(_strokes),
                      size: Size.infinite,
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: kDanger)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving || _strokes.isEmpty
                      ? null
                      : () => setState(() => _strokes.clear()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: kBlue),
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Confirm delivery'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _renderPng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _canvasSize == Size.zero ? const Size(600, 300) : _canvasSize;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes).paint(canvas, size);
    final img = await recorder
        .endRecording()
        .toImage(size.width.round(), size.height.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _submit() async {
    if (!_hasInk) {
      setState(() => _error = t('Please sign first.'));
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = t("Enter the recipient's name."));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final png = await _renderPng();
      final result = await api.uploadBytes(
        '/orders/${widget.orderId}/sign_delivery/',
        field: 'signature',
        bytes: png,
        filename: 'signature.png',
        fields: {'recipient_name': _name.text.trim()},
      );
      final out = <String, dynamic>{
        if (result is Map) ...Map<String, dynamic>.from(result),
        'to_phone': _phone.text.trim(),
      };
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = kInk
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
