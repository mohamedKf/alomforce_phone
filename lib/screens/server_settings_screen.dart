// server_settings_screen.dart — point the app at a backend (LAN dev / prod).
import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../widgets.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _url = TextEditingController(text: api.serverUrl);
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _testing = true);
    final url = _url.text.trim();
    final ok = await api.testServer(url);
    if (!mounted) return;
    setState(() => _testing = false);
    if (!ok) {
      showError(context, "Couldn't reach that server.");
      return;
    }
    await api.setServer(url);
    if (mounted) {
      showOk(context, 'Server saved.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Server settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t('Backend address'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:8000',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('Use the AlomForce server address. On the same Wi-Fi as the '
                'office computer, that is its LAN IP and port.'),
            style: const TextStyle(color: Color(0xFF6B7785), fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _testing ? null : _save,
            child: _testing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(t('Test & save')),
          ),
        ],
      ),
    );
  }
}
