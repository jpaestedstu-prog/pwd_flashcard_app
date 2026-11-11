import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/services/daily_login_reward_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/controllers/companion_controller.dart';
import 'package:pwdpwdpwd/features/companion/models/companion_presentation.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_clearance.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/shell_modal_observer.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/navigation/nav_bar_sizes.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// The AI Buddy as a floating action button (CompanionFab).
///
/// The owner asked for it on 10 Nov: a floating button on the screen, never an
/// item in the navigation bar (a trial build that day docked it at the end of
/// the tabs), never over the system's gesture area or a cutout, never over a
/// tab or another floating thing, the same place and the same look on every
/// hub, on a phone, a tablet and a computer. Here the real button over the
/// real hubs: where it rests, that the tabs keep the whole bar, that a drag
/// leaves it where it is, and that its panel opens over its corner.
class _Who {
  const _Who(this.name, this.role, this.type, {this.guest = false});
  final String name;
  final UserRole role;
  final DisabilityType type;
  final bool guest;

  String get id => 'buddy-fab-$name';
}

class _Profile extends ProfileNotifier {
  _Profile(this.who);
  final _Who who;

  @override
  UserProfile? build() => UserProfile(
    id: who.id,
    name: who.name,
    role: who.role,
    disabilityType: who.type,
    isGuestPlayer: who.guest,
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

GoRouter _router(_Who who, String at) => GoRouter(
  initialLocation: at,
  routes: [
    ShellRoute(
      // As the app's router: the shell hears what is pushed on its navigator.
      observers: [shellModalObserver],
      builder: (context, state, child) =>
          BottomNavShell(state: state, child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => who.guest
              ? const PlayerHomeScreen()
              : who.role == UserRole.child
              ? const ChildHomeScreen()
              : const HomeScreen(),
        ),
        GoRoute(path: '/flashcards', builder: (_, _) => const DeckListScreen()),
        GoRoute(path: '/games', builder: (_, _) => const GameHubScreen()),
        GoRoute(path: '/stories', builder: (_, _) => const StoryListScreen()),
        GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
        // A page opened inside the shell, under its bar (Settings).
        GoRoute(
          path: '/settings',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('A page'))),
        ),
      ],
    ),
  ],
);

const _player = _Who('Player', UserRole.player, DisabilityType.none);
const _visual = _Who('Student', UserRole.student, DisabilityType.visual);
const _child = _Who('Child', UserRole.child, DisabilityType.none);
const _guest = _Who('Guest', UserRole.player, DisabilityType.none, guest: true);

final _launcher = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_CompanionLauncher',
);
final _tabs = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_AnimatedNavItem',
);
final _panel = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_PanelAnchor',
);

Widget _app(GoRouter router, _Who who, void Function(BuildContext) seen) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        profileProvider.overrideWith(() => _Profile(who)),
        routerProvider.overrideWithValue(router),
        ttsServiceProvider.overrideWithValue(_QuietTts()),
        soundServiceProvider.overrideWithValue(_SilentSound()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) {
          seen(context);
          return CompanionHost(child: child ?? const SizedBox.shrink());
        },
      ),
    );

void main() {
  group('where it rests, worked out', () {
    Future<void> at(
      WidgetTester tester,
      Size size,
      double scale,
      void Function(BuildContext) check,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(bottom: 24, right: 10),
            textScaler: TextScaler.linear(scale),
          ),
          child: Builder(
            builder: (context) {
              check(context);
              return const SizedBox();
            },
          ),
        ),
      );
    }

    final normal = CompanionPresentation.forProfile(
      DisabilityType.none,
      const AppSettings(),
    );

    testWidgets('a floating button: 16 dp in on a phone, 24 on a tablet', (
      tester,
    ) async {
      await at(tester, const Size(360, 640), 1, (context) {
        final r = CompanionFab.rect(context, normal, hasTabBar: true);
        expect(r.size, const Size(60, 60));
        expect(r.right, 360 - 10 - 16, reason: 'clear of the cutout side');
        expect(
          r.bottom,
          640 - 24 - NavBarSizes.of(context).bar - 16,
          reason: 'above the tab bar and the gesture bar',
        );
        final guest = CompanionFab.rect(context, normal, hasTabBar: false);
        expect(guest.bottom, 640 - 24 - 16, reason: 'a guest has no tabs');
      });
      await at(tester, const Size(686, 1097), 1, (context) {
        final r = CompanionFab.rect(context, normal, hasTabBar: true);
        expect(r.right, 686 - 10 - 24);
      });
    });

    testWidgets('it grows with the text, to 1.25x', (tester) async {
      await at(tester, const Size(360, 640), 1.5, (context) {
        expect(CompanionFab.size(context, normal), 75);
        expect(
          CompanionFab.clearance(context, normal),
          75 + 16 + 8,
          reason: 'the room a list keeps below its last row',
        );
      });
    });
  });

  group('over the real hubs', () {
    setUpAll(() async {
      await loadRealFonts();
      await openSweepBoxes('buddy_fab');
      for (final who in const [_player, _visual, _child, _guest]) {
        await HiveService.markTutorialSeen(who.id);
        await DailyLoginReward.claimReward(who.id);
      }
    });
    tearDownAll(closeSweepBoxes);
    tearDown(shellModalObserver.reset);

    const sizes = <String, Size>{
      'phone 360x640': Size(360, 640),
      'Villaon at Largest 320x711': Size(320, 711),
      'Villaon 423x941': Size(423, 941),
      'phone sideways 640x360': Size(640, 360),
      'Honor upright 686x1097': Size(686, 1097),
      'Honor sideways 1097x608': Size(1097, 608),
      'computer 1280x800': Size(1280, 800),
      'computer 1920x1080': Size(1920, 1080),
    };

    const cases = <(_Who, String)>[
      (_player, '/home'),
      (_player, '/games'),
      (_visual, '/flashcards'),
      (_child, '/home'),
      (_child, '/stories'),
      (_guest, '/home'),
      (_guest, '/games'),
    ];

    for (final (who, page) in cases) {
      testWidgets('${who.name} $page: floats above the bar, off every tab, '
          'stays put, and opens its panel over its corner', (tester) async {
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
          for (final MapEntry(key: name, value: size) in sizes.entries) {
            for (final scale in const [1.0, 1.5]) {
              final where = '${who.name} $page, $name, ${scale}x';
              tester.view.physicalSize = size;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              late BuildContext appContext;
              await tester.pumpWidget(
                _app(_router(who, page), who, (c) => appContext = c),
              );
              for (var t = 0; t < 25; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }

              expect(_launcher, findsOneWidget, reason: '$where: the buddy');
              final container = ProviderScope.containerOf(appContext);
              final look = container.read(companionPresentationProvider);
              final rest = CompanionFab.rect(
                appContext,
                look,
                hasTabBar: !who.guest,
              );
              final buddy = tester.getRect(_launcher);
              expect(
                (buddy.left - rest.left).abs() < 0.5 &&
                    (buddy.top - rest.top).abs() < 0.5,
                isTrue,
                reason: '$where: at $rest, not $buddy',
              );
              final margin = CompanionFab.margin(appContext);
              expect(
                buddy.right,
                moreOrLessEquals(size.width - margin, epsilon: 0.5),
                reason: '$where: in the right-hand corner',
              );

              if (!who.guest) {
                // A floating button, not a tab: the five tabs share the whole
                // bar, and it rests above the bar, over none of them.
                expect(_tabs, findsNWidgets(5), reason: '$where: the tabs');
                final tabs = [
                  for (final t in _tabs.evaluate())
                    tester.getRect(find.byWidget(t.widget)),
                ];
                final barTop = tabs
                    .map((r) => r.top)
                    .reduce((a, b) => a < b ? a : b);
                expect(
                  buddy.bottom,
                  lessThanOrEqualTo(barTop - margin + 0.5),
                  reason: '$where: above the tab bar, with room to spare',
                );
                final row = tabs.last.right - tabs.first.left;
                expect(
                  row,
                  greaterThan(
                    (size.width >= 1200 ? 760 : size.width) - 2,
                  ),
                  reason: '$where: the tabs have the whole bar ($row)',
                );
              } else {
                expect(
                  buddy.bottom,
                  lessThanOrEqualTo(size.height - 24 - margin + 0.5),
                  reason: '$where: above the gesture bar',
                );
              }

              // A drag goes nowhere: it rests in the same place on every hub.
              await tester.drag(_launcher, const Offset(-120, -200));
              await tester.pump(const Duration(milliseconds: 300));
              expect(
                tester.getRect(_launcher),
                buddy,
                reason: '$where: still in its corner after a drag',
              );

              // Its panel opens over its corner, standing on the tab bar.
              container.read(companionControllerProvider.notifier).open();
              for (var t = 0; t < 6; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(_panel, findsOneWidget, reason: '$where: the panel');
              final panel = tester.getRect(
                find
                    .descendant(of: _panel, matching: find.byType(SizedBox))
                    .first,
              );
              expect(
                panel.bottom,
                lessThanOrEqualTo(buddy.bottom + margin - 4),
                reason: '$where: the panel $panel stands above the bar',
              );
              expect(panel.left, greaterThanOrEqualTo(0), reason: where);
              expect(
                panel.right,
                moreOrLessEquals(
                  size.width - (size.width - buddy.right).clamp(12, 999),
                  epsilon: 0.5,
                ),
                reason: '$where: the panel $panel lines up with the button',
              );
              container.read(companionControllerProvider.notifier).close();
              for (var t = 0; t < 6; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(_launcher, findsOneWidget, reason: '$where: back');

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

    // Home's first-visit tour is drawn in the screen, with no route, and the
    // button floated over it, bright and tappable. It steps aside while the
    // tour (or a celebration, or a new sticker's card) is up.
    testWidgets('the button steps aside under Home\'s first-visit tour', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(423, 941);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // A learner who has not seen the tour (no markTutorialSeen for them).
      const newcomer = _Who('Newcomer', UserRole.player, DisabilityType.none);
      await tester.pumpWidget(_app(_router(newcomer, '/home'), newcomer, (_) {}));
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Skip'), findsOneWidget, reason: 'the tour is up');
      expect(_launcher, findsNothing, reason: 'not over the tour');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    // Settings opened from Home's gear is pushed onto the shell's navigator:
    // the bar stays, and its tabs stay readable by a screen reader (they were
    // hidden there: the shell took the page for a pop-up, 10 Nov). The
    // floating button is for the hubs: on Settings it would rest on the
    // switches down the right-hand side.
    testWidgets('a page pushed inside the shell keeps the tabs readable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(423, 941);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = _router(_player, '/home');
      await tester.pumpWidget(_app(router, _player, (_) {}));
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_launcher, findsOneWidget, reason: 'on Home');
      router.push('/settings');
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('A page'), findsOneWidget);
      expect(_launcher, findsNothing, reason: 'not over a page like Settings');
      // What a screen reader can reach: the live tree from its root.
      final read = <String>{};
      bool visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (!node.isMergedIntoParent && !data.flagsCollection.isHidden) {
          read.add(data.label.split('\n').first);
        }
        node.visitChildren(visit);
        return true;
      }

      for (final view in tester.binding.renderViews) {
        final root = view.owner?.semanticsOwner?.rootSemanticsNode;
        if (root != null) visit(root);
      }
      for (final tab in const ['Home', 'Cards', 'Games', 'Stories', 'Progress']) {
        expect(read, contains(tab), reason: 'the $tab tab is still read');
      }
      router.pop();
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_launcher, findsOneWidget, reason: 'back on Home');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      semantics.dispose();
    });
  });
}
