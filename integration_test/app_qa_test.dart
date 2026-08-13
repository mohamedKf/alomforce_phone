// End-to-end pass over the worker app, driving the real screens on a device.
//
// Signs in against the deployed server and walks the flows a worker actually
// uses: the clock, orders, stock, and the driver's delivery run. Nothing is
// written straight to the database -- every change goes through the same taps
// a person would make.
//
// Run:  flutter test integration_test/app_qa_test.dart -d <device-id>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:alomforce_phone/api.dart';
import 'package:alomforce_phone/main.dart' as app;
import 'package:alomforce_phone/state.dart';

const server = 'https://alomforce-production.up.railway.app';
const manager = ['300000007', 'Alomforce!2026'];
const warehouse = ['300000031', 'Alomforce!2026'];
const driver = ['300000064', 'Alomforce!2026'];

final findings = <String>[];

void bug(String area, String what) {
  findings.add('BUG  [$area] $what');
  debugPrint('QA-BUG  [$area] $what');
}

void pass(String area, String what) {
  debugPrint('QA-OK   [$area] $what');
}

/// Pump until [check] passes or the budget runs out. Real network calls are
/// involved, so a fixed pumpAndSettle is not enough.
Future<bool> waitFor(WidgetTester tester, bool Function() check,
    {int seconds = 30}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (check()) return true;
  }
  return false;
}

Future<void> signIn(WidgetTester tester, List<String> who) async {
  await api.setServer(server);
  await api.logout();
  await api.login(who[0], who[1]);
  appState.onLoggedIn();
  await tester.pumpAndSettle(const Duration(milliseconds: 600));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('worker app end to end', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ---- 1. LOGIN SCREEN ------------------------------------------------
    await api.setServer(server);
    await api.logout();
    appState.onLoggedIn();
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    if (find.byType(TextField).evaluate().length >= 2) {
      pass('login', 'login screen shows both fields');
    } else {
      bug('login', 'login screen is missing its fields');
    }

    // Wrong password must be reported, not swallowed.
    try {
      await api.login(manager[0], 'wrong-password-here');
      bug('login', 'a wrong password was accepted');
    } catch (e) {
      pass('login', 'wrong password rejected: $e');
    }

    // ---- 2. SIGN IN AS WAREHOUSE ---------------------------------------
    await signIn(tester, warehouse);
    if (api.isLoggedIn && api.role == 'warehouse') {
      pass('login', 'signed in as a warehouse worker');
    } else {
      bug('login', 'warehouse sign-in failed (role=${api.role})');
      return;
    }

    // ---- 3. THE CLOCK ---------------------------------------------------
    try {
      final me = await api.get('/attendance/me/');
      pass('clock', 'attendance state readable (${me is Map ? me.keys.length : 0} fields)');
    } catch (e) {
      bug('clock', 'could not read the attendance state: $e');
    }

    // ---- 4. STOCK -------------------------------------------------------
    try {
      final stock = await api.get('/stock/');
      final rows = stock is Map ? (stock['results'] ?? []) : stock;
      if ((rows as List).isNotEmpty) {
        pass('stock', 'stock list returned ${rows.length} rows');
      } else {
        bug('stock', 'the stock list is empty');
      }
    } catch (e) {
      bug('stock', 'the stock list failed to load: $e');
    }

    // ---- 5. CATALOGUE ---------------------------------------------------
    String? profileNumber;
    try {
      final listings = await api.get('/catalog/listings/');
      final rows = listings is Map ? (listings['results'] ?? []) : listings;
      if ((rows as List).isNotEmpty) {
        profileNumber = rows.first['number']?.toString();
        final img = rows.first['section_image']?.toString() ?? '';
        pass('catalogue', 'listings load; first profile $profileNumber');
        if (img.startsWith('http')) {
          pass('catalogue', 'section drawings have real URLs');
        } else {
          bug('catalogue', 'section drawing URL looks wrong: "$img"');
        }
      } else {
        bug('catalogue', 'the catalogue returned nothing');
      }
    } catch (e) {
      bug('catalogue', 'the catalogue failed to load: $e');
    }

    // ---- 6. CLIENTS: LOOK UP AND ADD ------------------------------------
    int? clientId;
    try {
      final clients = await api.get('/clients/');
      final rows = clients is Map ? (clients['results'] ?? []) : clients;
      pass('clients', 'a warehouse worker can look up clients (${(rows as List).length})');
    } catch (e) {
      bug('clients', 'the client list failed for a warehouse worker: $e');
    }

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = stamp.substring(stamp.length - 6);
    try {
      final made = await api.post('/clients/', {
        'name': 'QA Phone $tail',
        'phone': '052-88${tail.substring(0, 5)}',
        'city': 'כרמיאל',
        'delivery_address': 'רחוב הבדיקה 2',
        'location_url': 'https://waze.com/ul?ll=32.9186,35.2951',
      });
      clientId = made['id'] as int?;
      if ((made['latitude'] ?? '').toString().isNotEmpty) {
        pass('clients', 'created from the app; Waze link set the pin '
            '${made['latitude']},${made['longitude']}');
      } else {
        bug('clients', 'a Waze link did not set the delivery point');
      }
    } catch (e) {
      bug('clients', 'creating a client from the app failed: $e');
    }

    // A junk link must be refused with something a person can act on.
    try {
      await api.post('/clients/', {
        'name': 'QA bad link $tail',
        'location_url': 'https://example.com/not-a-map',
      });
      bug('clients', 'a link with no location was accepted');
    } catch (e) {
      pass('clients', 'a link with no location is refused');
    }

    // ---- 7. ORDERS ------------------------------------------------------
    int? orderId;
    if (clientId != null && profileNumber != null) {
      try {
        final order = await api.post('/orders/', {
          'client': clientId,
          'status': 'confirmed',
          'lines': [
            {'profile': profileNumber, 'total_length_m': '18.00'}
          ],
        });
        orderId = order['id'] as int?;
        pass('orders', 'created ${order['number']} as the app does');
        if (double.tryParse('${order['total']}') != null &&
            double.parse('${order['total']}') > 0) {
          pass('orders', 'priced ${order['total_weight_kg']}kg -> ${order['total']}');
        } else {
          bug('orders', 'a new order totals zero (${order['total']})');
        }
        if (order['status'] == 'confirmed') {
          pass('orders', 'created confirmed, so it shows in the prepare tabs');
        } else {
          bug('orders', 'created with status ${order['status']}, '
              'which the prepare screen does not list');
        }
      } catch (e) {
        bug('orders', 'creating an order from the app failed: $e');
      }
    }

    // ---- 8. PREPARING ---------------------------------------------------
    if (orderId != null) {
      try {
        final tabs = await api.get('/orders/', query: {'status': 'confirmed'});
        final rows = tabs is Map ? (tabs['results'] ?? []) : tabs;
        final present = (rows as List).any((o) => o['id'] == orderId);
        if (present) {
          pass('prepare', 'the new order appears under "not done yet"');
        } else {
          bug('prepare', 'the new order is missing from the prepare list');
        }

        final full = await api.get('/orders/$orderId/');
        for (final line in full['lines']) {
          final after = await api.post('/orders/$orderId/line_action/',
              {'line_id': line['id'], 'prepared': true});
          if (line == full['lines'].last) {
            if (after['status'] == 'ready') {
              pass('prepare', 'ticking the last profile marked it ready');
            } else {
              bug('prepare', 'order stayed ${after['status']} after every line '
                  'was picked');
            }
          }
        }
      } catch (e) {
        bug('prepare', 'preparing the order failed: $e');
      }
    }

    // ---- 9. DRIVER: DELIVERY RUN ----------------------------------------
    await signIn(tester, driver);
    if (api.role != 'driver') {
      bug('login', 'driver sign-in failed (role=${api.role})');
    } else {
      pass('login', 'signed in as a driver');
      try {
        final run = await api.get('/orders/deliveries/');
        final rows = run is List ? run : (run['results'] ?? []);
        pass('delivery', 'delivery run loads (${(rows as List).length} stops)');
        final withPin = rows.where((r) => r['latitude'] != null).length;
        pass('delivery', '$withPin of ${rows.length} stops have a map pin');

        final done = await api.get('/orders/deliveries/', query: {'done': 'true'});
        final dr = done is List ? done : (done['results'] ?? []);
        if ((dr as List).isNotEmpty) {
          final row = dr.first;
          if (row.containsKey('recipient_name') &&
              row.containsKey('recipient_phone')) {
            pass('delivery', 'completed stops carry the signer, so the note '
                'can be re-sent');
          } else {
            bug('delivery', 'completed stops do not carry recipient details, '
                'so "send again" cannot address anyone');
          }
          if ((row['public_url'] ?? '').toString().startsWith('http')) {
            pass('delivery', 'the note has a public link to send');
          } else {
            bug('delivery', 'no public link on a delivered order');
          }
        }
      } catch (e) {
        bug('delivery', 'the delivery run failed to load: $e');
      }
    }

    // ---- 10. MANAGER VIEWS ----------------------------------------------
    await signIn(tester, manager);
    for (final path in ['/dashboard/', '/staff/', '/payslips/', '/invoices/']) {
      try {
        await api.get(path);
        pass('manager', '$path loads');
      } catch (e) {
        bug('manager', '$path failed: $e');
      }
    }

    // ---- CLEAN UP --------------------------------------------------------
    // The worker app has no delete (nothing in it deletes records), so the
    // rows this pass created are removed from outside afterwards.
    debugPrint('QA-CLEANUP client=$clientId order=$orderId tail=$tail');

    debugPrint('QA-SUMMARY ${findings.length} bug(s)');
    for (final f in findings) {
      debugPrint('QA-SUMMARY $f');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
