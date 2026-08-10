// qr_scan_screen.dart — scan a server QR (from the desktop) to get its URL.
//
// mobile_scanner 7.x uses Apple's native Vision framework on iOS (no MLKit), so
// it builds for the simulator too — though a real camera only exists on device.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../i18n.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Scan server QR'))),
      body: kIsWeb
          ? Center(child: Text(t('Scanning runs on the phone.')))
          : Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(onDetect: _onDetect),
                // A framing guide.
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t('Point at the server QR on the desktop'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
    );
  }
}
