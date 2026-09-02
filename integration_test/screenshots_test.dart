// Takes the screenshots used in presentations and store listings.
//
// Signs in against the deployed server so the screens show real orders,
// clients and stock rather than empty states -- a screenshot of an empty list
// tells nobody anything.
//
// Run:  flutter drive --driver=test_driver/integration_test.dart \
//         --target=integration_test/screenshots_test.dart -d <simulator-id>
//
// Output: build/screenshots/*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alomforce_phone/api.dart';
import 'package:alomforce_phone/main.dart' as app;
import 'package:alomforce_phone/state.dart';

const server = 'http://127.0.0.1:8001';
const manager = ['203456785', 'Alom!2026'];
const warehouse = ['000000018', 'Alom!2026'];
const driver = ['055555555', 'Alom!2026'];

late IntegrationTestWidgetsFlutterBinding binding;

/// Let the screen finish loading, then capture it.
///
/// pumpAndSettle alone is not enough: these screens are waiting on real
/// network calls, and settling only means no animation is running.
Future<void> shot(WidgetTester tester, String name,
    {int settleSeconds = 3}) async {
  for (var i = 0; i < settleSeconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await binding.takeScreenshot(name);
}

Future<void> signIn(WidgetTester tester, List<String> who) async {
  await api.setServer(server);
  await api.logout();
  await api.login(who[0], who[1]);
  appState.onLoggedIn();
  // Swapping the whole home screen for another role takes more than a
  // settle: the first capture after this caught the previous role's screen
  // still on display.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 800));
}

/// Tap the nth bottom-navigation destination.
///
/// By position, not by label: the app is running in Hebrew, and matching
/// English text found nothing at all.
Future<bool> tapTab(WidgetTester tester, int index) async {
  final destinations = find.byType(NavigationDestination);
  if (destinations.evaluate().length <= index) return false;
  await tester.tap(destinations.at(index));
  await tester.pumpAndSettle(const Duration(milliseconds: 800));
  return true;
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      as IntegrationTestWidgetsFlutterBinding;

  testWidgets('capture every screen worth showing', (tester) async {
    // iOS renders through a platform view that has to be converted before any
    // of it can be read back as an image.
    await binding.convertFlutterSurfaceToImage();

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // -- signed out --------------------------------------------------
    await api.setServer(server);
    await api.logout();
    appState.onLoggedIn();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await shot(tester, '01-login');

    // -- manager ------------------------------------------------------
    await signIn(tester, manager);
    await shot(tester, '02-manager-dashboard', settleSeconds: 5);

    // Dashboard, Team, Orders, Stock, Invoices, Me
    const managerTabs = {
      1: '03-manager-team',
      2: '04-orders',
      3: '05-stock',
      4: '06-invoices',
    };
    for (final entry in managerTabs.entries) {
      if (await tapTab(tester, entry.key)) {
        await shot(tester, entry.value, settleSeconds: 4);
      }
    }

    // -- warehouse ----------------------------------------------------
    await signIn(tester, warehouse);
    await shot(tester, '07-warehouse-clock', settleSeconds: 4);
    for (final entry in const {1: '08-orders-to-prepare',
                               2: '09-warehouse-stock'}.entries) {
      if (await tapTab(tester, entry.key)) {
        await shot(tester, entry.value, settleSeconds: 4);
      }
    }

    // The order itself, opened. The list shows numbers; the prepare screen
    // is where the cross-section drawings and the picking detail live, and
    // that is the screen worth photographing.
    if (await tapTab(tester, 1)) {
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final cards = find.byType(Card);
      if (cards.evaluate().isNotEmpty) {
        await tester.tap(cards.first);
        await shot(tester, '08b-order-prepare', settleSeconds: 6);
      }
    }

    // -- driver -------------------------------------------------------
    // A driver shares the warehouse home and gains a Deliveries tab, so
    // signing in alone leaves whatever tab was already open on screen.
    await signIn(tester, driver);
    if (await tapTab(tester, 3)) {
      await shot(tester, '10-driver-run', settleSeconds: 5);
    }
  });
}
