import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/widgets/pro_surface.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/tv_cast_session.dart';
import 'package:pwdpwdpwd/features/tv_cast/providers/tv_cast_provider.dart';
import 'package:pwdpwdpwd/features/tv_cast/screens/tv_cast_screen.dart';
import 'package:pwdpwdpwd/features/tv_cast/widgets/tv_cast_remote_controls.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// Layout coverage for the **running** TV Cast screen — the state that carries
/// every control, and the one no existing suite reached.
///
/// `uncovered_screens_test` renders `TvCastScreen` too, but it can never start
/// an HTTP server in a widget test, so it only ever sees the idle Start card:
/// the mode grid, the display-style grid, the readability rows, the timer
/// presets and the playback remote were all untested. This file overrides the
/// session provider with a running session instead, so every mode's full
/// control surface is laid out across the device matrix.
///
/// It also pins the *organisation* the educator surfaces share (see
/// lib/core/widgets/pro_surface.dart): pickers are grids of [ProActionTile]s
/// with exactly one selected tile, not loose `Wrap`s of chips. That is a
/// structural promise, so a later "just make this a chip row again" shows up
/// here rather than only to the eye.

/// A stub session notifier that reports a running cast without touching the
/// network. `build()` is overridden outright — the real one registers server
/// teardown in `ref.onDispose`, which there is nothing to tear down here.
class _RunningCast extends TvCastSessionNotifier {
  _RunningCast(this.initial);

  final TvCastSession initial;

  @override
  TvCastSession build() => initial;
}

class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'tv-cast-educator',
    name: 'Test Teacher',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

TvCastSession _running({
  required CastMode mode,
  FlashcardCategory? category,
  String? storyId,
  int viewers = 2,
  bool away = false,
  int? timerTotalSeconds,
}) => TvCastSession(
  mode: mode,
  category: category,
  storyId: storyId,
  isServerRunning: true,
  listenUrl: 'http://192.168.100.123:8088/c/HVNLC',
  castCode: 'HVNLC',
  connectedViewers: viewers,
  isAway: away,
  timerEndsAt: timerTotalSeconds == null
      ? null
      : DateTime.now().add(Duration(seconds: timerTotalSeconds)),
  timerTotalSeconds: timerTotalSeconds ?? 0,
);

List<Override> _overrides(TvCastSession session) => [
  tvCastSessionProvider.overrideWith(() => _RunningCast(session)),
  profileProvider.overrideWith(_StubProfile.new),
];

/// Width of the tappable block a label sits in — its nearest [Material]
/// ancestor, which is the rectangle every segment and remote button on this
/// screen is built from.
double _cellWidth(WidgetTester tester, String label) => tester
    .getSize(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    )
    .width;

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/tv_cast_layout');
    for (final name in const <String>[
      'cast_sessions',
      'classroom_members',
      'classrooms',
      'error_logs',
      'home_group_members',
      'home_groups',
      'profiles',
      'progress',
      'settings',
      'sync_queue',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  // The tablet the app ships on plus the narrowest phone it supports — the two
  // that decide whether a grid cell still fits its label.
  const devices = <DeviceSize>[
    DeviceSize('7" portrait', Size(600, 960)),
    DeviceSize('10" landscape', Size(1280, 800)),
    DeviceSize('phone portrait', Size(360, 640), devicePixelRatio: 3.0),
  ];

  // ─── Every mode's control surface lays out ────────────

  final modes = <String, TvCastSession>{
    'idle (mode not picked yet)': _running(mode: CastMode.idle),
    'flashcards': _running(
      mode: CastMode.flashcards,
      category: FlashcardCategory.animals,
    ),
    'FSL video': _running(
      mode: CastMode.fslVideo,
      category: FlashcardCategory.animals,
    ),
    // A real seeded id: the story dropdown asserts if its value isn't in the
    // item list, which would fail the matrix on test data rather than layout.
    'story': _running(mode: CastMode.story, storyId: SeedStories.all.first.id),
    'progress': _running(mode: CastMode.progress),
    'away + running timer': _running(
      mode: CastMode.flashcards,
      category: FlashcardCategory.animals,
      away: true,
      timerTotalSeconds: 300,
    ),
    'no viewers yet': _running(mode: CastMode.flashcards, viewers: 0),
  };

  modes.forEach((label, session) {
    testWidgets('running cast lays out — $label', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const TvCastScreen(),
        devices: devices,
        overrides: _overrides(session),
      );
    });
  });

  // ─── The accessibility themes ─────────────────────────
  //
  // Dyslexia and high contrast change font size, letter spacing and line
  // height, and the pro kit takes its accents from HCColor — so a running cast
  // has to be re-measured under them, not just under Flutter's default theme.

  testWidgets('running cast survives the accessibility themes', (tester) async {
    await expectScreenSurvivesThemes(
      tester,
      () => const TvCastScreen(),
      overrides: _overrides(
        _running(
          mode: CastMode.flashcards,
          category: FlashcardCategory.animals,
        ),
      ),
    );
  });

  // ─── The pickers are grids, matching the Home ─────────

  Future<void> pumpCast(WidgetTester tester, TvCastSession session) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(session),
        // The replay bar reads its copy from AppLocalizations; without the
        // delegates it fails on a null check instead of laying out.
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvCastScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('"What to cast" is a ProActionGrid of tiles, one selected', (
    tester,
  ) async {
    await pumpCast(tester, _running(mode: CastMode.progress));

    // Five modes, laid out by the same grid the educator Home uses for Quick
    // Actions — not a Wrap of chips.
    expect(find.byType(ProActionGrid), findsWidgets);
    for (final label in const [
      'Flashcards',
      'FSL',
      'Stories',
      'Live Activity',
      'Progress',
    ]) {
      expect(
        find.widgetWithText(ProActionTile, label),
        findsOneWidget,
        reason: '$label should be a tile in the "What to cast" grid',
      );
    }

    // Exactly one mode tile reads as chosen, and it is the session's mode.
    final modeTiles = tester
        .widgetList<ProActionTile>(find.byType(ProActionTile))
        .where(
          (t) => const [
            'Flashcards',
            'FSL',
            'Stories',
            'Live Activity',
            'Progress',
          ].contains(t.label),
        );
    expect(modeTiles.where((t) => t.selected).map((t) => t.label), [
      'Progress',
    ]);
  });

  testWidgets('display styles are a compact grid with one selection', (
    tester,
  ) async {
    await pumpCast(tester, _running(mode: CastMode.idle));

    final themeTiles = tester
        .widgetList<ProActionTile>(find.byType(ProActionTile))
        .where((t) => CastTheme.values.any((c) => c.label == t.label))
        .toList();

    // All eight templates present, all compact (the Home's "More" grid), and
    // the session's own theme is the one marked.
    expect(themeTiles.length, CastTheme.values.length);
    expect(themeTiles.every((t) => t.compact), isTrue);
    expect(themeTiles.where((t) => t.selected).map((t) => t.label), [
      CastTheme.dark.label,
    ]);

    // Hidden visually on a compact tile, but still spoken — a screen-reader
    // user must keep the description the old stacked rows showed.
    expect(
      themeTiles.every((t) => (t.caption ?? '').isNotEmpty),
      isTrue,
      reason: 'compact template tiles must still carry their description '
          'for screen readers',
    );
  });

  testWidgets('progress views are tiles, and the note follows the choice', (
    tester,
  ) async {
    await pumpCast(tester, _running(mode: CastMode.progress));

    for (final v in CastProgressView.values) {
      expect(find.widgetWithText(ProActionTile, v.label), findsOneWidget);
    }
    // The explanatory note under the grid describes the *current* view.
    expect(
      find.textContaining(CastProgressView.classWins.description),
      findsWidgets,
    );
  });

  testWidgets('playback remote is three equal rectangle buttons', (
    tester,
  ) async {
    await pumpCast(
      tester,
      _running(mode: CastMode.flashcards, category: FlashcardCategory.animals),
    );

    expect(find.byType(TvCastRemoteControls), findsOneWidget);
    for (final label in const ['Previous', 'Pause', 'Next']) {
      expect(find.text(label), findsOneWidget);
    }

    // Equal widths is the whole point of the change — three circles of two
    // different diameters is what this replaced.
    final cells = const [
      'Previous',
      'Pause',
      'Next',
    ].map((l) => _cellWidth(tester, l)).toList();
    expect(
      cells.every((w) => (w - cells.first).abs() < 1),
      isTrue,
      reason: 'remote buttons should share a width, got $cells',
    );
  });

  testWidgets('each section is headed exactly once, uppercase like Home', (
    tester,
  ) async {
    await pumpCast(
      tester,
      _running(mode: CastMode.flashcards, category: FlashcardCategory.animals),
    );

    // Uppercase, letter-spaced headers — the educator Home's, via
    // ProSectionHeader — rather than the learner surfaces' sentence-case
    // titles. Each appears exactly once: the timer panel used to repeat its
    // own name under the header.
    for (final title in const [
      'WHAT TO CAST',
      'NOW SHOWING ON TV',
      'PACING',
      'PLAYBACK',
      'TV DISPLAY STYLE',
      'LESSON TIMER',
      'READABILITY ON TV',
      'SHOW ON TV',
      'AUDIO',
      'FULLSCREEN',
      'TV REMOTE',
    ]) {
      expect(
        find.text(title),
        findsOneWidget,
        reason: '"$title" should head exactly one section',
      );
    }
  });

  testWidgets('the playback remote is hidden in Live Activity mode', (
    tester,
  ) async {
    // Live has its own push controls; showing the slide remote there would
    // offer buttons that do nothing. Guards the section wrapper added around
    // the remote — an easy place to lose the mode check.
    await pumpCast(tester, _running(mode: CastMode.live));
    expect(find.byType(TvCastRemoteControls), findsNothing);
  });

  testWidgets('readability options render as equal-width segments', (
    tester,
  ) async {
    await pumpCast(tester, _running(mode: CastMode.idle));

    for (final s in CastTextSize.values) {
      expect(find.text(s.label), findsOneWidget);
    }
    for (final l in CastLanguage.values) {
      expect(find.text(l.label), findsOneWidget);
    }

    // Normal / Large / Extra large are three very different word lengths; as
    // a Wrap of chips they drew three different widths. In a ProButtonRow they
    // are one three-way choice, so they must measure the same.
    final sizeWidths = CastTextSize.values
        .map((v) => _cellWidth(tester, v.label))
        .toList();
    expect(
      sizeWidths.every((w) => (w - sizeWidths.first).abs() < 1),
      isTrue,
      reason: 'text-size segments should share a width, got $sizeWidths',
    );

    final langWidths = CastLanguage.values
        .map((v) => _cellWidth(tester, v.label))
        .toList();
    expect(
      langWidths.every((w) => (w - langWidths.first).abs() < 1),
      isTrue,
      reason: 'language segments should share a width, got $langWidths',
    );
  });
}
