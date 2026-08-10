// Smoke test: the theme builds.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alomforce_phone/theme.dart';

void main() {
  test('theme builds light', () {
    expect(buildTheme().brightness, Brightness.light);
  });
}
