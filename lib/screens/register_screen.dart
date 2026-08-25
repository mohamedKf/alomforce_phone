// register_screen.dart — create a staff account, by invite only.
//
// Registration is gated by a register code the business owner / provider hands
// out: no code, no account. Client self-registration is intentionally not
// offered here — the client-facing screens don't exist yet, so letting someone
// sign up as a client would only dead-end them. If the server has no register
// code configured, this screen shows an "ask your provider" notice instead of a
// form that cannot succeed.
import 'package:flutter/material.dart';

import '../api.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _offered = false; // server has a register code configured
  bool _checking = true;
  bool _busy = false;
  bool _reveal = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  /// Ask the server whether a register code exists. The code itself is never
  /// sent — only whether registration should be offered at all.
  Future<void> _checkRegistration() async {
    try {
      final cfg = await api.get('/config/');
      if (mounted) {
        setState(() {
          _offered = cfg['manager_registration'] == true;
          _checking = false;
        });
      }
    } catch (_) {
      // Offline / server not set: show the notice, not a form that can't work.
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _idNumber, _code, _password,
        _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _localProblem() {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      return t('Enter your first and last name.');
    }
    if (_idNumber.text.trim().isEmpty) return t('Enter your ID number.');
    if (_code.text.trim().isEmpty) return t('Enter the register code.');
    if (_phone.text.trim().isEmpty) return t('Enter a phone number.');
    if (_password.text.length < 8) {
      return t('Use a password of at least 8 characters.');
    }
    // Caught here rather than at the server: a mistyped password that is
    // accepted locks the person out of the account they just made.
    if (_password.text != _confirm.text) {
      return t('The two passwords do not match.');
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _localProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.register(
        asManager: true,
        businessName: '',
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        phone: _phone.text.trim(),
        idNumber: _idNumber.text.trim(),
        registerCode: _code.text.trim(),
        password: _password.text,
      );
      appState.onLoggedIn();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('Create account'))),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _offered
              ? _form()
              : _inviteNotice(),
    );
  }

  Widget _inviteNotice() {
    return Bounded(Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_lock_outlined, size: 60, color: kMuted),
            const SizedBox(height: 16),
            Text(t('Registration is by invite'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: kInk)),
            const SizedBox(height: 8),
            Text(
              t('Ask your provider for a register code, then try again.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('Back')),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _form() {
    return Bounded(ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _field(_idNumber, t('ID number'), keyboard: TextInputType.number),
        _field(_code, t('Register code')),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            t('Ask the business owner for the register code.'),
            style: const TextStyle(color: kMuted, fontSize: 12),
          ),
        ),
        _field(_first, t('First name')),
        _field(_last, t('Last name')),
        _field(_phone, t('Phone'), keyboard: TextInputType.phone),
        _field(_password, t('Password'), obscure: true),
        _field(_confirm, t('Repeat password'), obscure: true),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: const TextStyle(color: kDanger)),
        ],
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52), backgroundColor: kBlue),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? t('Creating…') : t('Create account')),
        ),
      ],
    ));
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        obscureText: obscure && !_reveal,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: obscure
              ? IconButton(
                  icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility,
                      color: kMuted),
                  onPressed: () => setState(() => _reveal = !_reveal),
                )
              : null,
        ),
      ),
    );
  }
}
