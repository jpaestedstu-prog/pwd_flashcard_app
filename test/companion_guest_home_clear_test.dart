import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_clearance.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// The AI Buddy's floating button over the guest home.
///
/// On a phone at the largest text the guest home no longer fits, and it
/// scrolled under the buddy resting in the bottom-right corner: "How was it?"
/// sat under it (the Honor in a phone-sized window, 8 Nov; the owner asked
/// for it fixed on 9 Nov). The guest home is a short page of a few big
/// buttons, the guest's whole menu, so it keeps clear of the button outright
/// ([roomBesideBuddy]). Here the real button floats over the real page, and
/// no button may be under it at any scroll position.
class _Guest extends ProfileNotifier {
  _Guest(this.type);
  final DisabilityType type;

  @override
  UserProfile? build() => UserProfile(
    id: 'guest-clear',
    name: 'Guest Player',
    role: UserRole.player,
    isGuestPlayer: true,
    disabilityType: type,
    createdAt: DateTime(2026),
  );
}

class _QuietTts extends TtsService {
  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakEnglish(String text) async {}
  @override
  Future<void> speakFilipino(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> dispose() async {}
}

class _SilentSound implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          BottomNavShell(state: state, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const PlayerHomeScreen()),
      ],
    ),
  ],
);

final _launcher = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_CompanionLauncher',
);

/// Every screen size the guest home is used at: phones upright and sideways
/// (the Villaon at its owner's Display size and at the largest), the Honor
/// both ways, a computer window.
const _sizes = <String, Size>{
  'phone 320x568': Size(320, 568),
  'Villaon at Largest 320x711': Size(320, 711),
  'phone 360x640': Size(360, 640),
  'phone 360x800': Size(360, 800),
  'phone 411x914': Size(411, 914),
  'Villaon 423x941': Size(423, 941),
  'phone sideways 640x360': Size(640, 360),
  'Villaon at Largest sideways 711x320': Size(711, 320),
  'Villaon sideways 941x423': Size(941, 423),
  'Honor upright 686x1097': Size(686, 1097),
  'Honor sideways 1097x608': Size(1097, 608),
  'computer 1280x800': Size(1280, 800),
};

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('guest_buddy_clear');
  });
  tearDownAll(closeSweepBoxes);

  test('the room beside the button, worked out', () {
    // A phone held upright: no column of 360 clears it, so the page stops
    // above it.
    final phone = roomBesideBuddy(
      width: 360,
      column: 320,
      button: 75,
      margin: 16,
    );
    expect(phone.column, 320);
    expect(phone.bottom, 75 + 16 + 8);
    // The Honor upright: a column a little narrower clears it.
    final tablet = roomBesideBuddy(
      width: 686,
      column: 600,
      button: 85,
      margin: 24,
    );
    expect(tablet.bottom, 0);
    expect(tablet.column, lessThan(600));
    expect(tablet.column, greaterThanOrEqualTo(360));
    expect(686 / 2 + tablet.column / 2, lessThanOrEqualTo(686 - 24 - 85 - 8));
    // A computer window: the column is already clear.
    final wide = roomBesideBuddy(
      width: 1280,
      column: 600,
      button: 60,
      margin: 24,
    );
    expect((wide.column, wide.bottom), (600, 0));
  });

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('$name: no guest-home button is under the AI Buddy', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      // A gesture bar, as on the Villaon.
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final old = FlutterError.onError;
      final errors = <String>[];
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final scale in const [1.0, 1.5]) {
          for (final type in const [DisabilityType.none, DisabilityType.visual]) {
            for (final lang in const ['en', 'fil']) {
              final where = '$name, ${scale}x, ${type.name}, $lang';
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              final router = _router();
              await tester.pumpWidget(
                ProviderScope(
                  key: UniqueKey(),
                  overrides: [
                    profileProvider.overrideWith(() => _Guest(type)),
                    routerProvider.overrideWithValue(router),
                    ttsServiceProvider.overrideWithValue(_QuietTts()),
                    soundServiceProvider.overrideWithValue(_SilentSound()),
                  ],
                  child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    locale: Locale(lang),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    routerConfig: router,
                    builder: (context, child) =>
                        CompanionHost(child: child ?? const SizedBox.shrink()),
                  ),
                ),
              );
              for (var t = 0; t < 15; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(_launcher, findsOneWidget, reason: '$where: the buddy');
              final buddy = tester.getRect(_launcher).deflate(1);

              final page = find.byType(PlayerHomeScreen);
              final scrollable = find
                  .descendant(of: page, matching: find.byType(Scrollable))
                  .first;
              final viewport = tester.getRect(scrollable);
              final position = tester
                  .state<ScrollableState>(scrollable)
                  .position;
              final buttons = find.descendant(
                of: page,
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              );
              expect(buttons, findsWidgets);

              final step = position.viewportDimension * 0.4;
              var offset = 0.0;
              while (true) {
                position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
                await tester.pump();
                for (final element in buttons.evaluate()) {
                  final rect = tester.getRect(find.byWidget(element.widget));
                  final shown = rect.intersect(viewport);
                  if (shown.width <= 0 || shown.height <= 0) continue;
                  final under = shown.intersect(buddy);
                  final label = find
                      .descendant(
                        of: find.byWidget(element.widget),
                        matching: find.byType(Text),
                      )
                      .evaluate()
                      .map((e) => (e.widget as Text).data)
                      .join(' ');
                  expect(
                    under.width > 0 && under.height > 0,
                    isFalse,
                    reason:
                        '$where, scrolled ${position.pixels.round()}: '
                        '"$label" $rect is under the buddy $buddy',
                  );
                }
                if (offset >= position.maxScrollExtent) break;
                offset += step;
              }
              expect(errors, isEmpty, reason: '$where: $errors');

              await tester.pumpWidget(const SizedBox());
              for (var t = 0; t < 3; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
            }
          }
        }
      } finally {
        FlutterError.onError = old;
      }
    });
  }
}
