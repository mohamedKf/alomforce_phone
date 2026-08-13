// The month dropdown must speak the app's language, not the device's.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('month names render in Hebrew and Arabic', () {
    final he = [for (var m = 1; m <= 12; m++)
        DateFormat.MMMM('he').format(DateTime(2000, m))];
    final ar = [for (var m = 1; m <= 12; m++)
        DateFormat.MMMM('ar').format(DateTime(2000, m))];
    // ignore: avoid_print
    print('he: ${he.take(4).join(", ")} …');
    // ignore: avoid_print
    print('ar: ${ar.take(4).join(", ")} …');

    expect(he.first, isNot('January'), reason: 'Hebrew must not fall back to English');
    expect(ar.first, isNot('January'), reason: 'Arabic must not fall back to English');
    expect(he.first, isNot(ar.first), reason: 'the two languages must differ');
    // Hebrew and Arabic scripts, not Latin.
    expect(RegExp(r'[֐-׿]').hasMatch(he.first), isTrue);
    expect(RegExp(r'[؀-ۿ]').hasMatch(ar.first), isTrue);
  });
}
