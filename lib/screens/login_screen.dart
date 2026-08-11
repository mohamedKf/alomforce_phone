// login_screen.dart — AlomForce sign-in. White card on a navy field.
import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'server_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _reveal = false;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    final pw = _password.text;
    if (id.isEmpty || pw.isEmpty) {
      showError(context, 'Enter your ID number and password.');
      return;
    }
    setState(() => _busy = true);
    try {
      await api.login(id, pw);
      appState.onLoggedIn();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                // The sign-in card is capped and centred rather than filling
                // the width: stretched across a tablet the fields run the whole
                // screen, which reads as a form that lost its layout. Phones
                // are narrower than the cap, so they are unaffected.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      // Stretch inside the cap so the card fills the 420 rather
                      // than shrinking to its intrinsic width.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        _brand(),
                        const SizedBox(height: 28),
                        _card(context),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const ServerSettingsScreen())),
                          icon: const Icon(Icons.dns_outlined, color: Colors.white70, size: 18),
                          label: const Text('Server settings',
                              style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: const [
        Icon(Icons.hexagon_outlined, color: Colors.white, size: 46),
        SizedBox(height: 12),
        Text('AlomForce',
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: .5)),
        SizedBox(height: 6),
        Text('Aluminium profiles — workshop',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sign in',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kInk)),
          const SizedBox(height: 4),
          const Text('Enter your ID number and password.',
              style: TextStyle(color: kMuted)),
          const SizedBox(height: 22),
          TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'ID number',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: !_reveal,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility,
                    color: kMuted),
                onPressed: () => setState(() => _reveal = !_reveal),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}
