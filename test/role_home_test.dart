// Which home each role lands on. Office was falling through to the
// placeholder, so it had no invoices page -- or any page at all.
import 'package:flutter_test/flutter_test.dart';
import 'package:alomforce_phone/main.dart';
import 'package:alomforce_phone/screens/manager/manager_home.dart';
import 'package:alomforce_phone/screens/warehouse/warehouse_home.dart';
import 'package:alomforce_phone/screens/role_placeholder.dart';

void main() {
  test('office and manager share a home', () {
    expect(homeForRole('office'), isA<ManagerHome>());
    expect(homeForRole('manager'), isA<ManagerHome>());
  });

  test('workers and drivers keep the worker home', () {
    expect(homeForRole('warehouse'), isA<WarehouseHome>());
    expect(homeForRole('driver'), isA<WarehouseHome>());
  });

  test('a role with no phone app still gets the placeholder', () {
    expect(homeForRole('client'), isA<RolePlaceholder>());
    expect(homeForRole('something-new'), isA<RolePlaceholder>());
  });
}
