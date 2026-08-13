// Drives the invoices screen on a device against the deployed server.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alomforce_phone/api.dart';
import 'package:alomforce_phone/i18n.dart';
import 'package:alomforce_phone/screens/manager/invoices_screen.dart';
import 'package:alomforce_phone/screens/manager/invoice_form_screen.dart';

const server = 'https://alomforce-production.up.railway.app';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invoices screen and add form', (tester) async {
    await api.setServer(server);
    await api.logout();
    await api.login('300000007', 'Alomforce!2026');

    await tester.pumpWidget(const MaterialApp(home: InvoicesScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    // Let the real request land.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final tiles = find.textContaining('₪');
    debugPrint('QA-OK   [invoices] rows rendered: ${tiles.evaluate().length}');
    expect(find.text(t('Invoices')), findsWidgets,
        reason: 'the screen title should render');

    // Switch to the billed side.
    final billed = find.text(t('Billed'));
    if (billed.evaluate().isNotEmpty) {
      await tester.tap(billed.first);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      debugPrint('QA-OK   [invoices] switched to income without error');
    }

    // The add form must open and stand up with no photo taken.
    await tester.pumpWidget(const MaterialApp(home: InvoiceFormScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(t('Camera')), findsOneWidget);
    expect(find.text(t('Gallery')), findsOneWidget);
    expect(find.text(t('File')), findsOneWidget);
    debugPrint('QA-OK   [invoices] add form offers camera, gallery and file');

    // Saving with no total must be refused locally, not sent.
    final save = find.text(t('Save invoice'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(t('Enter the total.')), findsOneWidget);
    debugPrint('QA-OK   [invoices] empty total is refused before sending');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
