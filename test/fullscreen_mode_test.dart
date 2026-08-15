import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/fullscreen_provider.dart';
import 'package:pwdpwdpwd/widgets/fullscreen_host.dart';

import 'support/screen_matrix.dart';

/// Fullscreen ("presentation") mode: an educator hides the navigation chrome
/// so a shared tablet — propped in front of a class, or mirrored to a TV —
/// shows content edge to edge.
///
/// Two halves have to agree for the mode to mean anything: [BottomNavShell]
/// drops the tab bar, and [fullscreenBar] collapses each screen's app bar.
/// This file covers the second half (27 call sites depend on its contract),
/// the exit route out of the mode, and the educator switch that turns it on.

/// Stubs [profileProvider] so the Settings screen builds its Teacher variant
/// without `ProfileNotifier.build`'s Firebase remote-changes stream.
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: _role,
        createdAt: DateTime(2026),
      );
}

/// A screen bar of the shape the real call sites pass: a leading close button,
/// a title, and an action that lives only here.
AppBar _screenBar({bool automaticallyImplyLeading = true}) => AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Close',
        onPressed: () {},
      ),
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: const Text('Spelling Bee'),
      actions: [
        IconButton(
          icon: const Icon(Icons.pause_circle_outline_rounded),
          tooltip: 'Pause',
          onPressed: () {},
        ),
      ],
    );

/// The busiest bar in the app, mirroring the flashcard viewer's: three actions
/// — two icon buttons and a text pill that grows with the font scale — plus
/// the exit button the mode appends. This is the combination most likely to
/// run out of horizontal room in a 48dp strip on a narrow phone at 2.0x font.
AppBar _busyScreenBar() => AppBar(
      leading: const BackButton(),
      title: const Text('Animals'),
      actions: [
        IconButton(
          icon: const Icon(Icons.self_improvement_rounded),
          tooltip: 'I Need a Break',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.play_circle_rounded),
          tooltip: 'Start auto-play',
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('12 / 20'),
            ),
          ),
        ),
      ],
    );

Widget _host(AppBar bar) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            appBar: fullscreenBar(ref, bar),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

/// The [AppBar] the Scaffold actually got — the screen's own when the mode is
/// off, the one inside the slim bar when it is on.
AppBar _renderedBar(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar));

void main() {
  // Hive backs the accessibility services behind every [AppIconButton] (haptic
  // + tap sound), so the boxes have to exist before any tap in this file —
  // including the one on the exit-fullscreen button.
  setUpAll(() async {
    Hive.init('./build/test_cache/fullscreen_mode');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
    // The Settings screen's Cloud Sync tile reads the sync-queue box.
    await SyncQueueStorage.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('fullscreenBar', () {
    testWidgets('leaves the screen\'s own bar untouched when the mode is off',
        (tester) async {
      await tester.pumpWidget(_host(_screenBar()));

      // Everything the screen asked for is on screen, and nothing was added.
      expect(find.text('Spelling Bee'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Exit Fullscreen'), findsNothing);
      expect(_renderedBar(tester).preferredSize.height, kToolbarHeight);
    });

    testWidgets('collapses to the slim bar when the mode is on',
        (tester) async {
      await tester.pumpWidget(_host(_screenBar()));
      _containerOf(tester).read(fullscreenModeProvider.notifier).state = true;
      await tester.pump();

      // The title — the one part that is purely a label — gives up its space.
      expect(find.text('Spelling Bee'), findsNothing);
      // Everything a learner might need mid-activity stays: the screen's own
      // controls, its actions, and the way out of the mode.
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Exit Fullscreen'), findsOneWidget);
      expect(_renderedBar(tester).preferredSize.height,
          kFullscreenToolbarHeight);
      expect(kFullscreenToolbarHeight, lessThan(kToolbarHeight));
    });

    testWidgets('the bar swaps live, without the screen being rebuilt for it',
        (tester) async {
      await tester.pumpWidget(_host(_screenBar()));
      final container = _containerOf(tester);

      container.read(fullscreenModeProvider.notifier).state = true;
      await tester.pump();
      expect(find.text('Spelling Bee'), findsNothing);

      container.read(fullscreenModeProvider.notifier).state = false;
      await tester.pump();
      expect(find.text('Spelling Bee'), findsOneWidget);
    });

    testWidgets('the exit button leaves the mode and restores the full bar',
        (tester) async {
      await tester.pumpWidget(_host(_screenBar()));
      final container = _containerOf(tester);
      container.read(fullscreenModeProvider.notifier).state = true;
      await tester.pump();

      await tester.tap(find.byTooltip('Exit Fullscreen'));
      await tester.pump();

      expect(container.read(fullscreenModeProvider), isFalse);
      expect(find.text('Spelling Bee'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Exit Fullscreen'), findsNothing);
    });

    // Exit sits in the same corner on every screen — a learner who has found
    // it once should not have to hunt for it on the next activity because
    // that one carries a different number of actions.
    testWidgets('appends exit after the screen\'s own actions', (tester) async {
      await tester.pumpWidget(_host(_screenBar()));
      _containerOf(tester).read(fullscreenModeProvider.notifier).state = true;
      await tester.pump();

      expect(
        tester.getCenter(find.byTooltip('Exit Fullscreen')).dx,
        greaterThan(tester.getCenter(find.byTooltip('Pause')).dx),
      );
    });

    // Smart Review hangs its progress bar off AppBar.bottom. That is the only
    // thing telling a learner how far through the deck they are, so it has to
    // survive the collapse — and be counted in the bar's height, or the
    // Scaffold lays the body out under it.
    testWidgets('keeps AppBar.bottom and its height', (tester) async {
      await tester.pumpWidget(
        _host(AppBar(
          title: const Text('Smart Review'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(4),
            child: LinearProgressIndicator(value: 0.5, minHeight: 4),
          ),
        )),
      );
      _containerOf(tester).read(fullscreenModeProvider.notifier).state = true;
      await tester.pump();

      expect(find.text('Smart Review'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Measured, not read off the widget: the Scaffold sizes its app-bar slot
      // from the *slim bar's* preferredSize, so a rendered 48 + 4 proves that
      // number counted the progress bar. Had it not, the strip would have been
      // constrained to 48 and overflowed instead.
      expect(
        tester.getSize(find.byType(AppBar)).height,
        kFullscreenToolbarHeight + 4,
      );
    });

    // A screen that passes no `leading` relies on AppBar inserting the back
    // button for it (story_reader's "story not found" bar is one). Dropping
    // the flag while collapsing would strand it with no leading control at
    // all — only the exit button, which leaves fullscreen but not the screen.
    testWidgets('carries automaticallyImplyLeading across the collapse',
        (tester) async {
      for (final imply in const [true, false]) {
        await tester.pumpWidget(
          _host(AppBar(
            automaticallyImplyLeading: imply,
            title: const Text('Story Not Found'),
          )),
        );
        _containerOf(tester).read(fullscreenModeProvider.notifier).state = true;
        await tester.pump();

        expect(
          _renderedBar(tester).automaticallyImplyLeading,
          imply,
          reason: 'slim bar must preserve automaticallyImplyLeading: $imply',
        );
      }
    });
  });

  // The slim bar is a fixed-height strip that must fit its two 48dp tap
  // targets at every viewport and font scale — it has no room to scroll.
  group('slim bar layout', () {
    for (final entry in <String, AppBar Function()>{
      'one action': _screenBar,
      // Keeping the screen's actions is only safe if they still fit once the
      // bar is 8dp shorter and the exit button has been added beside them.
      'the viewer\'s three actions': _busyScreenBar,
    }.entries) {
      testWidgets('never overflows with ${entry.key}', (tester) async {
        await expectScreenNoOverflowAcrossDevices(
          tester,
          () => Consumer(
            builder: (context, ref, _) => Scaffold(
              appBar: fullscreenBar(ref, entry.value()),
              body: const SizedBox.shrink(),
            ),
          ),
          overrides: [fullscreenModeProvider.overrideWith((ref) => true)],
        );
      });
    }

    // How the busy bar is made to fit matters, not just that it does. The
    // action cluster's text is clamped to 1.3x so the row fits outright and
    // the icon buttons keep their full 48dp; if that clamp were dropped, the
    // FittedBox backstop would take up the slack by scaling the buttons down
    // instead. Assert the mechanism, so a regression shows up here as a
    // shrunken tap target rather than silently in the field.
    testWidgets('clamps action text so the buttons never have to shrink',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [fullscreenModeProvider.overrideWith((ref) => true)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                appBar: fullscreenBar(ref, _busyScreenBar()),
                body: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The counter pill renders at its 1.3x width, not the 2.0x the rest of
      // the screen uses — that is the clamp doing its job.
      final clamped = tester.getSize(find.text('12 / 20')).width;
      expect(clamped, lessThan(150));

      // And with the row fitting, every control is still laid out at the
      // theme's full 48dp target rather than a scaled-down fraction of it.
      for (final icon in const [
        Icons.self_improvement_rounded,
        Icons.play_circle_rounded,
        Icons.fullscreen_exit_rounded,
      ]) {
        final button = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(IconButton),
        );
        expect(tester.getSize(button).height, 48.0, reason: '$icon');
      }
    });
  });

  // The other half of the mode. If the bar collapses but the tab strip stays,
  // the learner is looking at chrome the educator thought they had removed.
  group('BottomNavShell', () {
    GoRouter buildRouter() => GoRouter(
          initialLocation: '/home',
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  BottomNavShell(state: state, child: child),
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Text('home-screen'),
                ),
              ],
            ),
          ],
        );

    testWidgets('hides the tab bar while fullscreen is on', (tester) async {
      final container = ProviderContainer(overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(UserRole.student)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: buildRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // /home is a tab route, so the bar is up to begin with.
      final navBar = find.byType(ClipRect);
      expect(tester.getSize(navBar).height, greaterThan(0));
      expect(container.read(bottomNavVisibleProvider), isTrue);

      container.read(fullscreenModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(tester.getSize(navBar).height, 0);
      expect(container.read(bottomNavVisibleProvider), isFalse);

      // ...and comes back when the educator turns the mode off again.
      container.read(fullscreenModeProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(tester.getSize(navBar).height, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('educator settings toggle', () {
    Future<ProviderContainer> pumpSettings(
      WidgetTester tester,
      UserRole role,
    ) async {
      tester.view.physicalSize = const Size(800, 1280) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _StubProfileNotifier(role)),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byType(ListView)));
    }

    testWidgets('a Teacher can turn fullscreen on and off', (tester) async {
      final container = await pumpSettings(tester, UserRole.teacher);

      await tester.scrollUntilVisible(
        find.text('Fullscreen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final switchFinder = find.descendant(
        of: find.ancestor(
          of: find.text('Fullscreen'),
          matching: find.byType(Row),
        ).last,
        matching: find.byType(Switch),
      );

      expect(container.read(fullscreenModeProvider), isFalse);
      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();
      expect(container.read(fullscreenModeProvider), isTrue);

      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();
      expect(container.read(fullscreenModeProvider), isFalse);
    });

    // Presentation mode is the educator's call: a learner profile must not
    // find the switch on its own Settings screen.
    testWidgets('a Student never sees the Presentation section',
        (tester) async {
      await pumpSettings(tester, UserRole.student);

      // Walk the whole list: the section would sit between Accessibility and
      // Learning Modes, so reaching the bottom without seeing it is the proof.
      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 30; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pump();
        expect(find.text('Fullscreen'), findsNothing);
        expect(find.text('PRESENTATION'), findsNothing);
      }

      // Let the section headers' entrance animations finish before unmounting,
      // or their one-shot timers outlive the tree and trip the invariant.
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
