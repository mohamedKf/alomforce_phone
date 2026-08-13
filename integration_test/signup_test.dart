// Registration and invoice entry, driven on a device against the deployed
// server. Assertions go through t(), because the app renders in the user's
// language and an English literal fails on a Hebrew or Arabic screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alomforce_phone/api.dart';
import 'package:alomforce_phone/i18n.dart';
import 'package:alomforce_phone/screens/register_screen.dart';
import 'package:alomforce_phone/screens/manager/invoice_form_screen.dart';

const server = 'https://alomforce-production.up.railway.app';

Future<void> settle(WidgetTester tester, {int ticks = 30}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up and add an invoice', (tester) async {
    await api.setServer(server);
    await api.logout();

    // ---- REGISTRATION ---------------------------------------------------
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await settle(tester, ticks: 20);

    // The manager option only shows when the server has a code configured.
    final managerTab = find.text(t('Manager'));
    debugPrint('QA-OK   [signup] manager option offered: '
        '${managerTab.evaluate().isNotEmpty}');

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = stamp.substring(stamp.length - 6);

    final fields = find.byType(TextField);
    expect(fields, findsWidgets, reason: 'the form should render its fields');

    // Fill by label so a reordered form does not silently type into the
    // wrong box.
    Future<void> type(String label, String value) async {
      final f = find.widgetWithText(TextField, label);
      if (f.evaluate().isEmpty) {
        debugPrint('QA-BUG  [signup] no field labelled "$label"');
        return;
      }
      await tester.enterText(f.first, value);
      await tester.pump(const Duration(milliseconds: 80));
    }

    await type(t('Business name'), 'QA Phone Signup $tail');
    await type(t('First name'), 'פון');
    await type(t('Last name'), 'בדיקה');
    await type(t('Phone'), '052-51$tail');
    await type(t('Password'), 'Str0ng!Passw0rd');
    await type(t('Repeat password'), 'MISMATCH');

    await tester.tap(find.text(t('Create account')).last);
    await settle(tester, ticks: 8);
    if (find.text(t('The two passwords do not match.')).evaluate().isNotEmpty) {
      debugPrint('QA-OK   [signup] mismatched passwords caught before sending');
    } else {
      debugPrint('QA-BUG  [signup] mismatched passwords were not reported');
    }

    await type(t('Repeat password'), 'Str0ng!Passw0rd');
    await tester.tap(find.text(t('Create account')).last);
    await settle(tester, ticks: 60);

    if (api.isLoggedIn && api.role == 'client') {
      debugPrint('QA-OK   [signup] registered and signed in as a client');
    } else {
      debugPrint('QA-BUG  [signup] registration did not sign in '
          '(loggedIn=${api.isLoggedIn} role=${api.role})');
    }

    // ---- INVOICE ENTRY BY HAND -----------------------------------------
    // As the office: a manager, entering an invoice with no photo.
    await api.logout();
    await api.login('300000007', 'Alomforce!2026');
    await tester.pumpWidget(const MaterialApp(home: InvoiceFormScreen()));
    await settle(tester, ticks: 10);

    Future<void> typeIn(String label, String value) async {
      final f = find.widgetWithText(TextField, label);
      if (f.evaluate().isEmpty) {
        debugPrint('QA-BUG  [invoice] no field labelled "$label"');
        return;
      }
      await tester.enterText(f.first, value);
      await tester.pump(const Duration(milliseconds: 80));
    }

    await typeIn(t('Supplier'), 'QA Supplier $tail');
    await typeIn(t('Invoice number'), 'QA-$tail');
    await typeIn(t('Before VAT'), '100');
    await typeIn(t('VAT'), '18');
    await typeIn(t('Total'), '118');

    final save = find.text(t('Save invoice'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester, ticks: 50);

    final made = await api.get('/invoices/',
        query: {'direction': 'expense', 'search': 'QA Supplier $tail'});
    final rows = made is Map ? (made['results'] ?? []) : made;
    if ((rows as List).isNotEmpty) {
      debugPrint('QA-OK   [invoice] saved by hand and readable back '
          '(total ${rows.first['total']}, source ${rows.first['source']})');
      debugPrint('QA-CLEANUP invoice=${rows.first['id']}');
    } else {
      debugPrint('QA-BUG  [invoice] the invoice typed in was not saved');
    }
    debugPrint('QA-CLEANUP phone_signup_tail=$tail');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
