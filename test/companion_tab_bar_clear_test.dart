import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// The floating AI Buddy and the tab bar under it.
///
/// The buddy sat a fixed 84 dp above the bottom, but the tab bar grows with
/// the text: at 1.5x on a phone it is about 90 dp, and taller on a big
/// window, so the buddy sat on the top of the Progress tab. A learner with
/// tabs (a Student here) must find every tab clear of it.
class _Student extends ProfileNotifier {
  _Student(this.type);
  final DisabilityType type;

  @override
  UserProfile? build() => UserProfile(
    id: 'tabs-clear',
    name: 'Ana',
    role: UserRole.student,
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
  initialLocation: '/games',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          BottomNavShell(state: state, child: child),
      routes: [
        GoRoute(
          path: '/games',
          builder: (_, _) => const Scaffold(body: SizedBox.expand()),
        ),
      ],
    ),
  ],
);

final _launcher = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_CompanionLauncher',
);
final _tabs = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_AnimatedNavItem',
);

const _sizes = <String, Size>{
  'phone 320x568': Size(320, 568),
  'Villaon at Largest 320x711': Size(320, 711),
  'phone 360x640': Size(360, 640),
  'Villaon 423x941': Size(423, 941),
  'phone sideways 640x360': Size(640, 360),
  'Honor upright 686x1097': Size(686, 1097),
  'Honor sideways 1097x608': Size(1097, 608),
  'computer 1280x800': Size(1280, 800),
  'computer 1920x1080': Size(1920, 1080),
};

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('tab_bar_buddy_clear');
  });
  tearDownAll(closeSweepBoxes);

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('$name: every tab is clear of the AI Buddy', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final old = FlutterError.onError;
      final errors = <String>[];
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final scale in const [1.0, 1.3, 1.5]) {
          for (final type in const [DisabilityType.none, DisabilityType.visual]) {
            final where = '$name, ${scale}x, ${type.name}';
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final router = _router();
            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [
                  profileProvider.overrideWith(() => _Student(type)),
                  routerProvider.overrideWithValue(router),
                  ttsServiceProvider.overrideWithValue(_QuietTts()),
                  soundServiceProvider.overrideWithValue(_SilentSound()),
                ],
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  locale: const Locale('en'),
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
            expect(_tabs, findsNWidgets(5), reason: '$where: the tabs');
            final buddy = tester.getRect(_launcher).deflate(1);
            for (final tab in _tabs.evaluate()) {
              final rect = tester.getRect(find.byWidget(tab.widget));
              final under = rect.intersect(buddy);
              expect(
                under.width > 0 && under.height > 0,
                isFalse,
                reason: '$where: a tab $rect is under the buddy $buddy',
              );
            }
            expect(errors, isEmpty, reason: '$where: $errors');
            await tester.pumpWidget(const SizedBox());
            for (var t = 0; t < 3; t++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          }
        }
      } finally {
        FlutterError.onError = old;
      }
    });
  }
}
