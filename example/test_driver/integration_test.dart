import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Where the web view device test's screenshots go, relative to `example/`.
const shotRoot = 'build/web_view_device';

/// Drives the web view device test on Chrome (F-01 US-08 FR-01) and writes
/// each screenshot the test takes as `<name>.png` under [shotRoot].
Future<void> main() {
  return integrationDriver(
    onScreenshot: (name, image, [args]) async {
      final file = File('$shotRoot/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(image);
      return true;
    },
  );
}
