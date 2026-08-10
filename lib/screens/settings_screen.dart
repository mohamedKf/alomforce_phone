// settings_screen.dart — in-app settings: server connection and app language.
import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'qr_scan_screen.dart';

const _languages = {'en': 'English', 'he': 'עברית', 'ar': 'العربية'};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _server = TextEditingController(text: api.serverUrl);
  late String _lang = api.language;
  String _serverNote = '';
  bool _testing = false;

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final scanned = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (scanned == null || scanned.isEmpty || !mounted) return;
    // The app appends /api itself, so drop a trailing /api if the QR included it.
    var url = scanned.trim();
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    if (url.endsWith('/api/')) url = url.substring(0, url.length - 5);
    // Fill the field with the scanned URL and test & save straight away.
    _server.text = url;
    setState(() {});
    await _saveServer();
  }

  Future<void> _saveServer() async {
    final url = _server.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _testing = true;
      _serverNote = 'Testing…';
    });
    final ok = await api.testServer(url);
    if (!ok) {
      setState(() {
        _testing = false;
        _serverNote = t("Couldn't reach that server.");
      });
      return;
    }
    await api.setServer(url);
    setState(() {
      _testing = false;
      _serverNote = t('Saved. Sign out and back in if you changed servers.');
    });
    if (mounted) showOk(context, t('Server saved.'));
  }

  Future<void> _saveLanguage(String code) async {
    setState(() => _lang = code);
    await api.setLanguage(code);
    appState.languageChanged(); // rebuild the app in the new language + direction
    if (mounted) showOk(context, t('Language saved.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(t('Server'), Icons.dns_outlined, [
            Text(t('Where the app connects to the AlomForce backend.'),
                style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                  labelText: t('Server address'),
                  hintText: 'http://192.168.1.10:8001',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: t('Scan QR'),
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanQr,
                  )),
            ),
            if (_serverNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_serverNote, style: const TextStyle(color: kMuted, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _scanQr,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text(t('Scan QR')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _testing ? null : _saveServer,
                  child: Text(_testing ? t('Testing…') : t('Test & save')),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          _card(t('Language'), Icons.language, [
            Text(t('The app language.'),
                style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 8),
            ..._languages.entries.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.value),
                  trailing: _lang == e.key
                      ? const Icon(Icons.check_circle, color: kBlue)
                      : const Icon(Icons.radio_button_unchecked, color: kLine),
                  onTap: () => _saveLanguage(e.key),
                )),
            const Text(
                'Note: the interface is currently English; full Hebrew/Arabic '
                'translation is coming.',
                style: TextStyle(color: kMuted, fontSize: 11.5)),
          ]),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: kNavy, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
            ]),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}
