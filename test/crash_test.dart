// Crash reporting: an endpoint is named without the record it was asked
// for, so a broken route reports once, not once per order.
import 'package:flutter_test/flutter_test.dart';
import 'package:alomforce_phone/crash.dart';

void main() {
  test('ids in the path fold into one endpoint', () {
    expect(Crash.endpointKey('/api/orders/12/share/'), '/orders/{id}/share/');
    expect(Crash.endpointKey('/api/orders/13/share/'), '/orders/{id}/share/');
    expect(Crash.endpointKey('/orders/7'), '/orders/{id}');
  });

  test('a path with no ids is left alone', () {
    expect(Crash.endpointKey('/api/config/'), '/config/');
    expect(Crash.endpointKey('/api/profiles/extal:C90/'), '/profiles/extal:C90/');
  });

  test('nothing is sent without a DSN', () {
    expect(crash.enabled, isFalse);
    // A no-op rather than a throw when Sentry never started.
    crash.report('/api/orders/1/', 502);
  });
}
