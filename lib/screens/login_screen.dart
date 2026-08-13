// login_screen.dart — AlomForce sign-in. White card on a navy field.
import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
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
      showError(context, t('Enter your ID number and password.'));
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
                          label: Text(t('Server settings'),
                              style: const TextStyle(color: Colors.white70)),
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
    // Not a const list any more: the tagline is translated at build time.
    // 'AlomForce' stays literal -- it is the product's name, not a phrase.
    return Column(
      children: [
        const Icon(Icons.hexagon_outlined, color: Colors.white, size: 46),
        const SizedBox(height: 12),
        const Text('AlomForce',
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: .5)),
        const SizedBox(height: 6),
        Text(t('Aluminium profiles — workshop'),
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
          Text(t('Sign in'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kInk)),
          const SizedBox(height: 4),
          Text(t('Enter your ID number and password.'),
              style: const TextStyle(color: kMuted)),
          const SizedBox(height: 22),
          TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t('ID number'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: !_reveal,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: t('Password'),
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
                : Text(t('Sign in')),
          ),
        ],
      ),
    );
  }
}
