// Host side of `flutter drive` for the integration tests: runs them on the
// device and saves every `takeScreenshot` to build/walkthrough/<name>.png
// (WALKTHROUGH_DIR overrides the folder, e.g. one per simulator in CI).

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Directory(
    Platform.environment['WALKTHROUGH_DIR'] ?? 'build/walkthrough',
  )..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
