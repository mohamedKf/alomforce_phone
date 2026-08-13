// The amounts must agree whichever one you type, and must not fight back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alomforce_phone/api.dart';
import 'package:alomforce_phone/i18n.dart';
import 'package:alomforce_phone/screens/manager/invoice_form_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, String>> amounts(WidgetTester tester) async {
    String read(String label) {
      final f = find.widgetWithText(TextField, label);
      final w = tester.widget<TextField>(f.first);
      return w.controller?.text ?? '';
    }
    return {
      'net': read(t('Before VAT')),
      'vat': read(t('VAT')),
      'total': read(t('Total')),
    };
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(
        find.widgetWithText(TextField, label).first, value);
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('VAT works in both directions', (tester) async {
    await api.setServer('https://alomforce-production.up.railway.app');
    await tester.pumpWidget(const MaterialApp(home: InvoiceFormScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    // Forward: net -> vat + total.
    await type(tester, t('Before VAT'), '1000');
    var a = await amounts(tester);
    debugPrint('QA net=1000 -> vat=${a['vat']} total=${a['total']}');
    expect(a['vat'], '180.00');
    expect(a['total'], '1180.00');

    // Backwards: total -> net + vat.
    await type(tester, t('Total'), '2950');
    a = await amounts(tester);
    debugPrint('QA total=2950 -> net=${a['net']} vat=${a['vat']}');
    expect(a['net'], '2500.00');
    expect(a['vat'], '450.00');

    // An edited VAT is respected, and the total follows it.
    await type(tester, t('Before VAT'), '100');
    await type(tester, t('VAT'), '5');
    a = await amounts(tester);
    debugPrint('QA net=100 vat=5 -> total=${a['total']}');
    expect(a['total'], '105.00');

    // Clearing a field must not wipe the others or crash.
    await type(tester, t('Total'), '');
    a = await amounts(tester);
    debugPrint('QA cleared total -> net=${a['net']} vat=${a['vat']}');
    expect(a['net'], isNotEmpty);

    debugPrint('QA-OK   [vat] arithmetic holds in both directions');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
