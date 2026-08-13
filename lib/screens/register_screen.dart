// register_screen.dart — create an account without one.
//
// Two kinds, because they are genuinely different people: a client registering
// their company, and a manager who was given the register code. The manager
// option only appears when the server says a code is configured, so a
// deployment with registration switched off does not advertise a door that
// does not open.
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
  final _business = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _asManager = false;
  bool _managerOffered = false;
  bool _busy = false;
  bool _reveal = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkManagerOption();
  }

  /// Ask the server whether a register code exists. The code itself is never
  /// sent -- only whether the option should be shown at all.
  Future<void> _checkManagerOption() async {
    try {
      final cfg = await api.get('/config/');
      if (mounted) {
        setState(() => _managerOffered = cfg['manager_registration'] == true);
      }
    } catch (_) {
      // Offline or unreachable: leave the manager option hidden rather than
      // showing a form that cannot succeed.
    }
  }

  @override
  void dispose() {
    for (final c in [_business, _first, _last, _phone, _idNumber, _code,
        _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _localProblem() {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      return t('Enter your first and last name.');
    }
    if (_asManager) {
      if (_idNumber.text.trim().isEmpty) return t('Enter your ID number.');
      if (_code.text.trim().isEmpty) return t('Enter the register code.');
    } else {
      if (_business.text.trim().isEmpty) return t('Enter your business name.');
    }
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
        asManager: _asManager,
        businessName: _business.text.trim(),
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
      body: Bounded(ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_managerOffered) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t('Client'))),
                ButtonSegment(value: true, label: Text(t('Manager'))),
              ],
              selected: {_asManager},
              onSelectionChanged: (s) => setState(() {
                _asManager = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 18),
          ],
          if (_asManager) ...[
            _field(_idNumber, t('ID number'), keyboard: TextInputType.number),
            _field(_code, t('Register code')),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                t('Ask the business owner for the register code.'),
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ),
          ] else
            _field(_business, t('Business name')),
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
      )),
    );
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
