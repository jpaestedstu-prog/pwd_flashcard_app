import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/connectivity_state.dart';
import 'package:pwdpwdpwd/widgets/connectivity_banner.dart';

/// Telling someone they are offline when they are not.
///
/// Two separate faults produced the same false claim.
///
/// The banner stays mounted while online so it can slide in — merely
/// translated off-screen — and an off-screen widget still publishes its
/// semantics. Screen-reader users were told "You're offline" on every screen,
/// permanently. For a visually-impaired learner the spoken tree *is* the
/// interface, so a stale label there is the bug, not a cosmetic detail.
///
/// And `results.every((r) => r == none)` is vacuously true on an empty list,
/// so an unsettled reading from the platform read as "offline" rather than
/// "not known yet".
void main() {
  group('isOfflineForDisplay', () {
    test('an empty reading is not a claim that we are offline', () {
      // `every` on an empty iterable is true — the trap this exists to close.
      expect(isOfflineForDisplay(const []), isFalse);
    });

    test('an explicit none is offline', () {
      expect(isOfflineForDisplay(const [ConnectivityResult.none]), isTrue);
    });

    test('any real transport is online', () {
      expect(isOfflineForDisplay(const [ConnectivityResult.wifi]), isFalse);
      expect(isOfflineForDisplay(const [ConnectivityResult.mobile]), isFalse);
      expect(isOfflineForDisplay(const [ConnectivityResult.ethernet]), isFalse);
      expect(isOfflineForDisplay(const [ConnectivityResult.vpn]), isFalse);
    });

    test('a mixed reading counts as online', () {
      expect(
        isOfflineForDisplay(const [
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]),
        isFalse,
      );
    });
  });

  group('ConnectivityBanner', () {
    testWidgets('says nothing to a screen reader while online', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectivityBanner(child: Scaffold(body: Text('Home'))),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp("offline", caseSensitive: false)),
        findsNothing,
        reason: 'a hidden banner must not keep announcing itself',
      );
      handle.dispose();
    });

    testWidgets('does not cover the app while online', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectivityBanner(child: Scaffold(body: Text('Home'))),
        ),
      );
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('never swallows taps meant for the app', (tester) async {
      // The banner sits over the top of every route, including app-bar
      // controls; it is IgnorePointer for exactly this reason.
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectivityBanner(
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Title'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => taps++,
                  ),
                ],
              ),
              body: const Text('Home'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
