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
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// ◀ ▶ along the tab bar stay on the tabs, on a short window.
///
/// On a tablet held sideways the Home page builds cards past its bottom edge,
/// behind the tab bar, where they sit level with the tabs. ◀ from Cards went to
/// one of them, out of sight, instead of the Home tab beside it (found with the
/// D-pad reach matrix run sideways, 9 Nov). Scrolled, a row of tiles runs
/// behind the bar by its lower edge only: level with the tabs by that hidden
/// edge, it took ◀ and ▶ from Cards (the same matrix, a Player's Home and a
/// Student's with visual, hearing or motor needs).
class _Learner extends ProfileNotifier {
  _Learner(this.role);
  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
    id: 'dpad-tabs-${role.name}',
    name: 'Learner',
    role: role,
    createdAt: DateTime(2026),
  );
}

class _GazeOn extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          BottomNavShell(state: state, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/flashcards', builder: (_, _) => const DeckListScreen()),
        GoRoute(path: '/games', builder: (_, _) => const GameHubScreen()),
        GoRoute(path: '/stories', builder: (_, _) => const StoryListScreen()),
        GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
      ],
    ),
  ],
);

String _labelOf(FocusNode n) {
  var label = '';
  n.context?.visitAncestorElements((e) {
    final w = e.widget;
    if (w is Semantics && (w.properties.label ?? '').isNotEmpty) {
      label = w.properties.label!;
      return false;
    }
    return true;
  });
  return label;
}

/// The tab whose label starts with [name]: in the tab bar, wholly inside the
/// window (the Home page has a "Games" tile of its own, part hidden behind the
/// bar).
FocusNode _tab(String name, double windowHeight) {
  for (final n in FocusManager.instance.rootScope.traversalDescendants) {
    if (n is FocusScopeNode || n.context == null) continue;
    final r = n.rect;
    if (_labelOf(n).startsWith(name) &&
        r.top > windowHeight - 100 &&
        r.bottom <= windowHeight + 1) {
      return n;
    }
  }
  throw StateError('no $name tab');
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('dpad_tab_bar_sideways');
    for (final role in const [UserRole.student, UserRole.player]) {
      await HiveService.markTutorialSeen('dpad-tabs-${role.name}');
      await DailyLoginReward.claimReward('dpad-tabs-${role.name}');
    }
  });
  tearDownAll(closeSweepBoxes);
  setUp(() => gazeHomeGrid.clearGrid());

  Future<void> pumpHome(WidgetTester tester, UserRole role) async {
    tester.view.physicalSize = const Size(1097, 608);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _Learner(role)),
          gazeSettingsProvider.overrideWith(_GazeOn.new),
          routerProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  Future<FocusNode?> press(
    WidgetTester tester,
    FocusNode from,
    LogicalKeyboardKey key,
  ) async {
    from.requestFocus();
    await tester.pump();
    for (FocusScopeNode? s = from.nearestScope;
        s != null;
        s = s.enclosingScope) {
      final c = s.context;
      if (c == null || !c.mounted) continue;
      FocusTraversalGroup.maybeOf(c)?.invalidateScopeData(s);
    }
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return FocusManager.instance.primaryFocus;
  }

  Future<void> closeUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('sideways, ◀ and ▶ step along the tabs', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester, UserRole.student);

    final home = _tab('Home', 608);
    final cards = _tab('Cards', 608);
    final games = _tab('Games', 608);
    expect(
      await press(tester, cards, LogicalKeyboardKey.arrowLeft),
      same(home),
      reason: '◀ from Cards: the Home tab, not a card out of sight',
    );
    expect(
      await press(tester, home, LogicalKeyboardKey.arrowRight),
      same(cards),
      reason: '▶ from Home: the Cards tab',
    );
    expect(
      await press(tester, cards, LogicalKeyboardKey.arrowRight),
      same(games),
      reason: '▶ from Cards: the Games tab',
    );

    await closeUp(tester);
    semantics.dispose();
  });

  testWidgets('scrolled, a row of tiles running behind the bar does not take '
      '◀ ▶ from the tabs', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHome(tester, UserRole.player);

    final home = _tab('Home', 608);
    final cards = _tab('Cards', 608);
    final games = _tab('Games', 608);
    final barTop = cards.rect.top;

    // A tile to the left of the Cards tab, scrolled so its lower edge runs
    // 30 dp behind the bar while its middle stays in sight above it.
    FocusNode? tile;
    for (final n in FocusManager.instance.rootScope.traversalDescendants) {
      if (n is FocusScopeNode || n.context == null) continue;
      final scrollable = Scrollable.maybeOf(n.context!);
      if (scrollable == null ||
          axisDirectionToAxis(scrollable.axisDirection) != Axis.vertical) {
        continue;
      }
      final r = n.rect;
      if (r.height < 80 || r.height > 300) continue;
      if (r.center.dx >= cards.rect.left || r.right <= 0) continue;
      final position = scrollable.position;
      final to = position.pixels + r.bottom - (barTop + 30);
      if (to < position.minScrollExtent || to > position.maxScrollExtent) {
        continue;
      }
      position.jumpTo(to);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tile = n;
      break;
    }
    expect(tile, isNotNull, reason: 'a tile to run behind the bar');
    final r = tile!.rect;
    expect(r.bottom, closeTo(barTop + 30, 1),
        reason: 'its lower edge behind the bar');
    expect(r.center.dy, lessThan(barTop), reason: 'its middle in sight');

    expect(
      await press(tester, cards, LogicalKeyboardKey.arrowLeft),
      same(home),
      reason: '◀ from Cards: the Home tab, not "${_labelOf(tile)}" above it',
    );
    expect(
      await press(tester, cards, LogicalKeyboardKey.arrowRight),
      same(games),
      reason: '▶ from Cards: the Games tab, not a tile above the bar',
    );
    expect(
      await press(tester, home, LogicalKeyboardKey.arrowRight),
      same(cards),
      reason: '▶ from Home: the Cards tab',
    );

    await closeUp(tester);
    semantics.dispose();
  });
}
