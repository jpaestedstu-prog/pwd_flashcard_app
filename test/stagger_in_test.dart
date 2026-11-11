import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/services/daily_login_reward_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/core/utils/reduced_motion.dart';
import 'package:pwdpwdpwd/core/widgets/stagger_in.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// A list item's staggered entrance plays only while its list first appears.
///
/// The decks on Cards each waited by their place in the list before fading in,
/// counted from when they were built, which in a list that builds as it
/// scrolls is when they scroll into view: the twelfth deck sat blank for more
/// than a second, and at opacity 0 it had no semantics, so TalkBack and the
/// arrow keys could not find it (Cards held sideways on the Honor, 10 Nov).
Rect _semRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    final m = n.transform;
    if (m != null) rect = MatrixUtils.transformRect(m, rect);
  }
  return rect;
}

/// The labels a screen reader can reach right now, with where they are.
Map<String, Rect> _read(WidgetTester tester) {
  final out = <String, Rect>{};
  bool visit(SemanticsNode node) {
    final d = node.getSemanticsData();
    if (d.label.isNotEmpty && !d.flagsCollection.isHidden) {
      out[d.label] = _semRect(node);
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

Widget _list({bool reduced = false}) => MaterialApp(
  home: ReducedMotionScope(
    reduced: reduced,
    child: Scaffold(
      body: ListView.builder(
        itemCount: 60,
        itemExtent: 100,
        itemBuilder: (context, index) => StaggerIn(
          index: index,
          base: const Duration(milliseconds: 200),
          step: const Duration(milliseconds: 80),
          child: Semantics(label: 'Item $index', child: const SizedBox()),
          builder: (child, delay) =>
              child.animate().fadeIn(duration: 400.ms, delay: delay),
        ),
      ),
    ),
  ),
);

class _Profile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'stagger-player',
    name: 'Player',
    role: UserRole.player,
    createdAt: DateTime(2026),
  );
}

void main() {
  testWidgets('the first items stagger in; later ones appear at once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_list());
    await tester.pump();
    // Still waiting their turn: not drawn, so not read either.
    expect(_read(tester).keys, isNot(contains('Item 0')));
    // A delayed effect starts from a timer, then runs frame by frame.
    for (var t = 0; t < 15; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_read(tester).keys, contains('Item 0'));
    expect(_read(tester).keys, contains('Item 4'));

    // Far down the list, built as they scroll in: there, and read, at once.
    final position = tester.state<ScrollableState>(
      find.byType(Scrollable),
    ).position;
    position.jumpTo(3000);
    await tester.pump();
    final read = _read(tester);
    for (final i in [30, 31, 32, 33, 34]) {
      expect(read.keys, contains('Item $i'), reason: 'item $i scrolled in');
    }
    semantics.dispose();
  });

  testWidgets('with Reduced Motion nothing animates in', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_list(reduced: true));
    await tester.pump();
    expect(_read(tester).keys, contains('Item 0'));
    expect(_read(tester).keys, contains('Item 4'));
    expect(find.byType(Animate), findsNothing);
    semantics.dispose();
  });

  group('the decks on Cards', () {
    setUpAll(() async {
      await loadRealFonts();
      await openSweepBoxes('stagger_in');
      await HiveService.markTutorialSeen('stagger-player');
      await DailyLoginReward.claimReward('stagger-player');
    });
    tearDownAll(closeSweepBoxes);

    for (final MapEntry(key: name, value: size) in const {
      'phone 360x640': Size(360, 640),
      'Honor sideways 1097x608': Size(1097, 608),
    }.entries) {
      testWidgets('$name: every deck on screen is read, as it scrolls in', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = GoRouter(
          initialLocation: '/flashcards',
          routes: [
            ShellRoute(
              builder: (c, s, child) => BottomNavShell(state: s, child: child),
              routes: [
                GoRoute(
                  path: '/flashcards',
                  builder: (_, _) => const DeckListScreen(),
                ),
                GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith(_Profile.new),
              routerProvider.overrideWithValue(router),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        final list = find.byType(Scrollable).first;
        final position = tester.state<ScrollableState>(list).position;
        final missing = <String>{};
        for (var at = 0.0; at <= position.maxScrollExtent + 1; at += 200) {
          position.jumpTo(at.clamp(0, position.maxScrollExtent));
          // One frame: a learner scrolling, or TalkBack moving on, does not
          // wait for anything.
          await tester.pump();
          final read = _read(tester);
          final decks = find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').contains(' deck. '),
          );
          for (final e in decks.evaluate()) {
            final label = (e.widget as Semantics).properties.label!;
            final drawn = tester.getRect(find.byWidget(e.widget));
            if (drawn.intersect(Offset.zero & size).height < 40) continue;
            if (!read.containsKey(label)) missing.add(label.split('.').first);
          }
        }
        expect(missing, isEmpty, reason: 'decks on screen but not read');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
        semantics.dispose();
      });
    }
  });
}
