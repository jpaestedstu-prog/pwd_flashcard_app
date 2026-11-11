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
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/dpad_reach.dart';
import 'support/real_fonts.dart';

/// Held sideways, the AI Buddy's floating button rests in the bottom-right
/// corner, over the hub, above the tab bar. Someone on arrow keys, a
/// controller or a switch has to be able to get to it there: an arrow
/// pointing at the buddy lands on it, on every hub, for every kind of
/// learner.
class _Learner {
  const _Learner(this.name, this.role, {this.guest = false});
  final String name;
  final UserRole role;
  final bool guest;

  String get id => 'dpad-side-$name';
}

class _Profile extends ProfileNotifier {
  _Profile(this.who);
  final _Learner who;

  @override
  UserProfile? build() => UserProfile(
    id: who.id,
    name: who.name,
    role: who.role,
    isGuestPlayer: who.guest,
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
          builder: (context, state) => who.role == UserRole.child
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
      ],
    ),
  ],
);

const _hubs = ['/home', '/flashcards', '/games', '/stories', '/progress'];

const _learners = <_Learner>[
  // A guest opens Cards and Games from its home.
  _Learner('Guest', UserRole.player, guest: true),
  _Learner('Player', UserRole.player),
  _Learner('Student', UserRole.student),
  _Learner('Child', UserRole.child),
];

const _sizes = <String, Size>{
  'Honor sideways': Size(1097, 608),
  'phone sideways': Size(640, 360),
};

bool _isBuddy(String label) =>
    label.startsWith('Open AI Tutor') || label.startsWith('Open Buddy');

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('dpad_buddy_sideways');
    // In real async, out here: the tour and the Daily Reward would each cover
    // the hub being walked.
    for (final who in _learners) {
      await HiveService.markTutorialSeen(who.id);
      await DailyLoginReward.claimReward(who.id);
    }
  });
  tearDownAll(closeSweepBoxes);
  setUp(() => gazeHomeGrid.clearGrid());

  for (final who in _learners) {
    final pages = who.guest ? const ['/flashcards', '/games'] : _hubs;
    for (final page in pages) {
      for (final MapEntry(key: name, value: size) in _sizes.entries) {
        testWidgets('${who.name} $page, $name: an arrow reaches the buddy', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final old = FlutterError.onError;
          FlutterError.onError = (d) {};
          addTearDown(() => FlutterError.onError = old);

          Future<void> pumpPage() async {
            await tester.pumpWidget(const SizedBox.shrink());
            gazeHomeGrid.clearGrid();
            final router = _router(who, page);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  profileProvider.overrideWith(() => _Profile(who)),
                  gazeSettingsProvider.overrideWith(_GazeOn.new),
                  routerProvider.overrideWithValue(router),
                ],
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  locale: const Locale('en'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  shortcuts: dpadShortcuts,
                  actions: dpadActions,
                  routerConfig: router,
                  builder: (context, child) =>
                      CompanionHost(child: child ?? const SizedBox.shrink()),
                ),
              ),
            );
            for (var t = 0; t < 25; t++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          }

          await pumpPage();
          final straight = <String>{};
          final reached = await walkArrowKeys(
            tester,
            devicePixelRatio: 1,
            straight: straight,
          );
          for (final keys in const [
            [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight],
            [LogicalKeyboardKey.arrowRight],
          ]) {
            await pumpPage();
            for (final key in keys) {
              reached.addAll(
                await runArrowKeys(
                  tester,
                  devicePixelRatio: 1,
                  key: key,
                  straight: straight,
                ),
              );
            }
          }

          await pumpPage();
          final report = await surveyDpadReach(tester, devicePixelRatio: 1);
          final buddy = [
            for (final t in report.targets.values)
              if (_isBuddy(t.label)) t.label,
          ];
          expect(buddy, isNotEmpty, reason: 'the buddy is on the $page hub');
          expect(
            reached,
            containsAll(buddy),
            reason: 'the arrow keys reach the buddy',
          );
          expect(
            straight,
            containsAll(buddy),
            reason: 'an arrow pointing at the buddy lands on it',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 6));
          semantics.dispose();
        });
      }
    }
  }
}
