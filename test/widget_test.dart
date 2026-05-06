// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/main.dart';

const _appBoxes = <String>[
  'profiles',
  'settings',
  'progress',
  'custom_cards',
  'sessions',
  'classrooms',
  'classroom_members',
  'home_groups',
  'home_group_members',
  'error_logs',
];

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/widget_test');
    for (final name in _appBoxes) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlashLearnApp()));

    // Advance the clock just enough for the first build to settle, but
    // *not* long enough for the splash's 3 s navigation timer to fire.
    // pumpAndSettle would deadlock here because the splash's particle
    // animations loop forever via flutter_animate.repeat().
    await tester.pump(const Duration(milliseconds: 100));

    // App should render without errors
    expect(find.byType(FlashLearnApp), findsOneWidget);

    // Pump the widget down explicitly so the splash's dispose() runs
    // and cancels its navigation Timer before the test framework's
    // pending-timer guard fires.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
