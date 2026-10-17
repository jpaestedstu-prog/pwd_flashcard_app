import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/system_bars.dart';

/// The status and navigation bars after a full-screen page. On the Honor
/// (Android 16) one visit to the full-screen sign player left the clock and
/// battery hidden for the rest of the session: edge to edge, which the pages
/// asked for on the way out, no longer shows bars an immersive page hid.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restore shows both bars, then goes back to edge to edge', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await SystemBars.restore();

    final chrome = calls
        .where((c) => c.method.startsWith('SystemChrome.setEnabledSystemUI'))
        .toList();
    expect(chrome.map((c) => c.method), [
      'SystemChrome.setEnabledSystemUIOverlays',
      'SystemChrome.setEnabledSystemUIMode',
    ]);
    expect(
      chrome.first.arguments,
      unorderedEquals(['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
    );
    expect(chrome.last.arguments, 'SystemUiMode.edgeToEdge');
  });

  test('no page leaves full screen with edge to edge alone', () {
    // Every page that hides the bars must give them back through
    // SystemBars.restore; only the app's start asks for edge to edge itself.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.endsWith('lib/main.dart') ||
          path.endsWith('lib/core/utils/system_bars.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (RegExp(r'setEnabledSystemUIMode\(\s*SystemUiMode\.edgeToEdge')
          .hasMatch(source)) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'use SystemBars.restore() to leave a full-screen page');
  });
}
