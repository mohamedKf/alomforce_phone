// scan_screen.dart — look up a profile by its number.
//
// Camera QR scanning was removed (its MLKit dependency can't build for the iOS
// simulator). Enter the profile number printed on the label to open it; on a
// real device this is what a scanned QR resolves to anyway.
import 'package:flutter/material.dart';

import '../../theme.dart';
import 'profile_detail.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manual = TextEditingController();
  bool _handling = false;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _open(String raw) async {
    // Tolerate a scheme prefix, so a pasted QR payload still resolves.
    final number = raw.trim().replaceFirst(RegExp(r'^.*[:/]'), '').trim();
    if (number.isEmpty || _handling) return;
    setState(() => _handling = true);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(number: number)));
    if (mounted) setState(() => _handling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a profile')),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag, size: 56, color: kMuted),
                    SizedBox(height: 14),
                    Text('Enter the profile number from the label.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Profile number',
                    style: TextStyle(fontWeight: FontWeight.w600, color: kInk)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        autofocus: true,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.go,
                        onSubmitted: _open,
                        decoration: const InputDecoration(
                            hintText: 'e.g. 04901',
                            prefixIcon: Icon(Icons.tag)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _open(_manual.text),
                      style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
                      child: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
