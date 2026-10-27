import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/services/daily_login_reward_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/dpad_reach.dart';
import 'support/real_fonts.dart';

/// Every control on every learner tab, for every kind of learner, on every
/// D-pad the app has: the gaze cursor and the game controller (which walk
/// the cells a hub publishes, and the tab bar), and the arrow keys of a
/// keyboard, a remote, a switch box or the web app (which move focus).
/// Guest Player, Player with Progress, and Student and Child under each
/// accessibility type — the hubs change with all three.

/// Who is at the tablet, for one run of the matrix.
class _Learner {
  const _Learner(this.name, this.role, this.type, {this.guest = false});
  final String name;
  final UserRole role;
  final DisabilityType type;
  final bool guest;
}

class _StubProfile extends ProfileNotifier {
  _StubProfile(this.learner);
  final _Learner learner;

  @override
  UserProfile? build() => UserProfile(
        id: 'dpad-${learner.name}',
        name: learner.name,
        role: learner.role,
        disabilityType: learner.type,
        isGuestPlayer: learner.guest,
        createdAt: DateTime(2026),
      );
}

class _GazeOn extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

GoRouter _router(_Learner who, String at) => GoRouter(
      initialLocation: at,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              BottomNavShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => who.guest
                  ? const PlayerHomeScreen()
                  : who.role == UserRole.child
                      ? const ChildHomeScreen()
                      : const HomeScreen(),
            ),
            GoRoute(
              path: '/flashcards',
              builder: (context, state) => const DeckListScreen(),
            ),
            GoRoute(
              path: '/games',
              builder: (context, state) => const GameHubScreen(),
            ),
            GoRoute(
              path: '/stories',
              builder: (context, state) => const StoryListScreen(),
            ),
            GoRoute(
              path: '/progress',
              builder: (context, state) => const ProgressScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );

const _types = DisabilityType.values;

final _learners = <_Learner>[
  const _Learner('Guest', UserRole.player, DisabilityType.none, guest: true),
  const _Learner('Player', UserRole.player, DisabilityType.none),
  for (final t in _types) _Learner('Student-${t.name}', UserRole.student, t),
  for (final t in _types) _Learner('Child-${t.name}', UserRole.child, t),
];

List<String> _pagesFor(_Learner who) => who.guest
    // A guest's home opens Games and Cards; there is no tab bar.
    ? const ['/home', '/games', '/flashcards']
    : const ['/home', '/flashcards', '/games', '/stories', '/progress',
        '/settings'];

const _size = Size(686, 1097); // the Honor tablet, in dp
const _dpr = 1.0;

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('dpad_reach');
    // Out here, in real async: a Hive write begun inside a widget test
    // blocks every later write in the file. The first-visit tour and the
    // daily reward would each cover the hub being measured.
    for (final who in _learners) {
      await HiveService.markTutorialSeen('dpad-${who.name}');
      await DailyLoginReward.claimReward('dpad-${who.name}');
    }
  });
  tearDownAll(closeSweepBoxes);
  setUp(() => gazeHomeGrid.clearGrid());

  for (final who in _learners) {
    for (final page in _pagesFor(who)) {
      testWidgets('${who.name} $page: every tap target on the D-pad',
          (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = _size * _dpr;
        tester.view.devicePixelRatio = _dpr;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Future<void> pumpPage() async {
          await tester.pumpWidget(const SizedBox.shrink());
          gazeHomeGrid.clearGrid();
          final router = _router(who, page);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileProvider.overrideWith(() => _StubProfile(who)),
                gazeSettingsProvider.overrideWith(_GazeOn.new),
                // The AI Buddy reads where the router is.
                routerProvider.overrideWithValue(router),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                locale: const Locale('en'),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                // The app's own arrow keys (see dpad_keys.dart).
                shortcuts: dpadShortcuts,
                actions: dpadActions,
                routerConfig: router,
                // The AI Buddy floats over every hub from here, as in the
                // app: beside the router, so it is the D-pad's hardest
                // control to reach.
                builder: (context, child) =>
                    CompanionHost(child: child ?? const SizedBox.shrink()),
              ),
            ),
          );
          for (var t = 0; t < 25; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        // Arrow keys first, from pages nobody has touched: explored from
        // every control reached, and — as a learner goes — straight down to
        // the tab bar and along it each way, and right through the page.
        // Each records only what an arrow press landed on.
        await pumpPage();
        // And of those, what a press landed on going the way it points:
        // a control met only by a wrap round the page is one nobody finds.
        final straight = <String>{};
        final reached = await walkArrowKeys(
          tester,
          devicePixelRatio: _dpr,
          straight: straight,
        );
        for (final keys in const [
          [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight],
          [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft],
          [LogicalKeyboardKey.arrowRight],
        ]) {
          await pumpPage();
          for (final key in keys) {
            reached.addAll(
              await runArrowKeys(
                tester,
                devicePixelRatio: _dpr,
                key: key,
                straight: straight,
              ),
            );
          }
        }

        await pumpPage();
        final report = await surveyDpadReach(tester, devicePixelRatio: _dpr);
        final unreached = [
          for (final t in report.targets.values)
            if (t.label != '(unnamed)' && !reached.contains(t.label)) t,
        ];
        final onlyByWrap = [
          for (final t in report.targets.values)
            if (t.label != '(unnamed)' &&
                reached.contains(t.label) &&
                !straight.contains(t.label))
              t,
        ];
        for (final t in report.notInGrid) {
          debugPrint('REACH ${who.name} $page | not in grid: $t');
        }
        for (final t in report.notFocusable) {
          debugPrint('REACH ${who.name} $page | not focusable: $t');
        }
        for (final t in unreached) {
          debugPrint('REACH ${who.name} $page | arrows never reach: $t');
        }
        for (final t in onlyByWrap) {
          debugPrint('REACH ${who.name} $page | reached only by a wrap: $t');
        }
        for (final t in report.sharedCells) {
          debugPrint('REACH ${who.name} $page | shares a cell: $t with '
              '${t.sharesCellWith.join(', ')}');
        }
        debugPrint('REACH ${who.name} $page | ${report.targets.length} '
            'targets, ${report.notInGrid.length} not in grid, '
            '${report.notFocusable.length} not focusable, '
            '${unreached.length} unreached by arrows, '
            '${onlyByWrap.length} only by a wrap, '
            '${report.sharedCells.length} sharing a cell');

        expect(report.targets, isNotEmpty);
        // Gaze and the controller walk a hub's published grid. Settings is
        // not a hub: they move focus there, as the arrow keys do everywhere.
        if (page != '/settings') {
          expect(report.notInGrid.map((t) => '$t'), isEmpty,
              reason: 'every control on a hub is a gaze / controller cell');
        }
        expect(report.notFocusable.map((t) => '$t'), isEmpty,
            reason: 'every control takes D-pad focus');
        expect(unreached.map((t) => '$t'), isEmpty,
            reason: 'the arrow keys reach every control');
        expect(onlyByWrap.map((t) => '$t'), isEmpty,
            reason: 'every control is reached by an arrow pointing at it');
        expect(report.sharedCells.map((t) => '$t'), isEmpty,
            reason: 'a grid cell opens one thing');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
        semantics.dispose();
      });
    }
  }
}
