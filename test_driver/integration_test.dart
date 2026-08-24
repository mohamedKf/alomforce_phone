// Driver for screenshot-taking integration tests.
//
// takeScreenshot() inside a test hands the bytes back here, because the test
// runs on the device and cannot write to the developer's disk. Everything
// lands in build/screenshots/.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('build/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
