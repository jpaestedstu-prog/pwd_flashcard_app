import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/services/daily_login_reward_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// The AI Buddy's floating button and the learner hubs: Home, Cards, Games,
/// Stories, Progress.
///
/// The button floats in the bottom-right corner over all of them (the owner
/// asked for a floating button, never a tab, 10 Nov). Its history: in 1.4.3
/// a hub's last row could end under it, so a tap meant for a card, an answer
/// or the last mood face opened the tutor; round 8 then stopped every hub short
/// of it, which left an empty band (upright) or column (sideways) with the
/// cards cut off at its edge. Now a hub runs under it, as under any floating
/// action button, and keeps room at the end of its list. Here the real button
/// over each real hub, on phones and tablets, upright and sideways, and on
/// computers: the list runs on under the button (no band, no column), the
/// button is clear of the tab bar and the gesture bar, nothing it rests over
/// is out of reach (every control under it at one scroll position is clear of
/// it at another), and at the end of the list nothing is under it.
class _Learner {
  const _Learner(this.name, this.role, this.type, {this.guest = false});
  final String name;
  final UserRole role;
  final DisabilityType type;
  final bool guest;

  String get id => 'buddy-hub-$name';
}

class _Profile extends ProfileNotifier {
  _Profile(this.learner);
  final _Learner learner;

  @override
  UserProfile? build() => UserProfile(
    id: learner.id,
    name: learner.name,
    role: learner.role,
    disabilityType: learner.type,
    isGuestPlayer: learner.guest,
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

const _hubTypes = <String, Type>{
  '/flashcards': DeckListScreen,
  '/games': GameHubScreen,
  '/stories': StoryListScreen,
  '/progress': ProgressScreen,
};

GoRouter _router(_Learner who, String at) => GoRouter(
  initialLocation: at,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          BottomNavShell(state: state, child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => who.role == UserRole.child
              ? const ChildHomeScreen()
              : const HomeScreen(),
        ),
        GoRoute(path: '/flashcards', builder: (_, _) => const DeckListScreen()),
        GoRoute(path: '/games', builder: (_, _) => const GameHubScreen()),
        GoRoute(path: '/stories', builder: (_, _) => const StoryListScreen()),
        GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
      ],
    ),
  ],
);

const _learners = <_Learner>[
  // A guest opens Cards and Games from its home (which has its own test).
  _Learner('Guest', UserRole.player, DisabilityType.none, guest: true),
  _Learner('Player', UserRole.player, DisabilityType.none),
  // The bigger buddy (68 dp) of a learner with low vision.
  _Learner('Student', UserRole.student, DisabilityType.visual),
  _Learner('Child', UserRole.child, DisabilityType.none),
];

List<String> _pagesFor(_Learner who) => who.guest
    ? const ['/flashcards', '/games']
    : const ['/home', '/flashcards', '/games', '/stories', '/progress'];

const _sizes = <String, Size>{
  'phone 360x640': Size(360, 640),
  'Villaon at Largest 320x711': Size(320, 711),
  'Villaon 423x941': Size(423, 941),
  'phone sideways 640x360': Size(640, 360),
  'Honor upright 686x1097': Size(686, 1097),
  'Honor sideways 1097x608': Size(1097, 608),
  'computer 1280x800': Size(1280, 800),
};

final _launcher = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_CompanionLauncher',
);

/// Every node a learner can tap, with where it is on the screen.
List<(String, Rect)> _tappable(WidgetTester tester) {
  final out = <(String, Rect)>[];
  bool visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if ((data.hasAction(SemanticsAction.tap) ||
            data.hasAction(SemanticsAction.longPress)) &&
        !node.isMergedIntoParent &&
        !data.flagsCollection.isHidden) {
      var rect = node.rect;
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        final t = n.transform;
        if (t != null) rect = MatrixUtils.transformRect(t, rect);
      }
      out.add((data.label.split('\n').first, rect));
    }
    node.visitChildren(visit);
    return true;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return out;
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('buddy_hubs_clear');
    // In real async, out here: a Hive write begun inside a widget test holds
    // up every later one in the file. The tour and the daily reward would
    // each cover the hub being measured.
    for (final who in _learners) {
      await HiveService.markTutorialSeen(who.id);
      await DailyLoginReward.claimReward(who.id);
    }
  });
  tearDownAll(closeSweepBoxes);

  for (final who in _learners) {
    for (final page in _pagesFor(who)) {
      testWidgets('${who.name} $page: nothing to tap is under the AI Buddy', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tester.view.devicePixelRatio = 1;
        // A gesture bar, as on the Villaon.
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final old = FlutterError.onError;
        FlutterError.onError = (d) {};
        try {
          for (final MapEntry(key: name, value: size) in _sizes.entries) {
            for (final scale in const [1.0, 1.5]) {
              final where = '${who.name} $page, $name, ${scale}x';
              tester.view.physicalSize = size;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              final router = _router(who, page);
              await tester.pumpWidget(
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
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    routerConfig: router,
                    builder: (context, child) =>
                        CompanionHost(child: child ?? const SizedBox.shrink()),
                  ),
                ),
              );
              for (var t = 0; t < 25; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              expect(_launcher, findsOneWidget, reason: '$where: the buddy');
              final buddy = tester.getRect(_launcher).deflate(1);

              final hubType = page == '/home'
                  ? (who.role == UserRole.child ? ChildHomeScreen : HomeScreen)
                  : _hubTypes[page]!;
              final hub = find.byType(hubType);
              expect(hub, findsOneWidget, reason: where);
              // The hub's own list: its outermost vertical scrollable. A list
              // inside it (the Stories grid) runs on past the screen, so its
              // own box is not what shows.
              final lists = find
                  .descendant(of: hub, matching: find.byType(Scrollable))
                  .evaluate()
                  .where(
                    (e) =>
                        axisDirectionToAxis(
                          (e.widget as Scrollable).axisDirection,
                        ) ==
                        Axis.vertical,
                  )
                  .toList();
              expect(lists, isNotEmpty, reason: '$where: the list');
              final list = find.byWidget(lists.first.widget);
              final viewport = tester.getRect(list);
              final position = tester.state<ScrollableState>(list).position;

              // No band and no column kept for the button: the list runs on
              // under it, across the whole hub, and it floats over the list,
              // clear of the bar and the gesture bar below.
              expect(
                viewport.bottom,
                greaterThan(buddy.bottom),
                reason: '$where: the list runs on under the button',
              );
              expect(
                viewport.right,
                moreOrLessEquals(tester.getRect(hub).right, epsilon: 1),
                reason: '$where: no column kept at the side',
              );
              expect(
                buddy.bottom,
                lessThanOrEqualTo(size.height - 24 - 16 + 1),
                reason: '$where: the button is above the gesture bar',
              );
              if (page == '/progress') {
                expect(
                  tester
                      .getRect(
                        find.descendant(
                          of: hub,
                          matching: find.byType(FlexibleSpaceBar),
                        ),
                      )
                      .right,
                  moreOrLessEquals(size.width, epsilon: 1),
                  reason: '$where: the header band keeps the full width',
                );
              }

              // Where each control was seen under the button, and where clear.
              final under = <String, double>{};
              final clear = <String>{};
              String keyOf(String label, Rect r) =>
                  '$label @${(r.center.dx / 8).round()}';
              final step = position.viewportDimension * 0.4;
              var offset = 0.0;
              while (true) {
                position.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 50));
                for (final (label, rect) in _tappable(tester)) {
                  // The buddy itself ("Open AI Tutor", or "Open Buddy" for a
                  // child): its own node, wherever it is.
                  if (rect.inflate(2).contains(buddy.topLeft) &&
                      rect.inflate(2).contains(buddy.bottomRight) &&
                      rect.width < buddy.width + 8) {
                    continue;
                  }
                  final shown = rect.intersect(viewport);
                  if (shown.width <= 0 || shown.height <= 0) continue;
                  final overlap = shown.intersect(buddy);
                  final key = keyOf(label, rect);
                  if (overlap.width > 0 && overlap.height > 0) {
                    under[key] = position.pixels;
                    // At the end of the list nothing may be under it: that
                    // is what the room each hub keeps there is for.
                    expect(
                      position.pixels < position.maxScrollExtent - 0.5,
                      isTrue,
                      reason:
                          '$where, at the end of the list: "$label" $rect is '
                          'under the button $buddy',
                    );
                  } else {
                    clear.add(key);
                  }
                }
                if (offset >= position.maxScrollExtent) break;
                offset += step;
              }
              final stuck = [
                for (final MapEntry(key: key, value: at) in under.entries)
                  if (!clear.contains(key)) '$key (scrolled ${at.round()})',
              ];
              expect(
                stuck,
                isEmpty,
                reason:
                    '$where: under the button wherever they show, so out of '
                    'reach: $stuck',
              );

              await tester.pumpWidget(const SizedBox());
              for (var t = 0; t < 3; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
            }
          }
        } finally {
          FlutterError.onError = old;
          semantics.dispose();
        }
      });
    }
  }
}
