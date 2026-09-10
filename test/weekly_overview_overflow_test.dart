import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/parent/widgets/weekly_overview_card.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

import 'support/device_matrix.dart';

/// The "This Week" section of the Teacher and Parent dashboards.
///
/// Its mini bar chart shipped inside a hard-coded `SizedBox(height: 100)` while
/// the column inside stacked a value label, a 60 px bar, a day label and — on
/// today — a dot: 107 px at the *default* font scale, so every educator with
/// any study minutes on the roster saw "BOTTOM OVERFLOWED BY 7 PIXELS", rising
/// to ~98 px at the 2.0x accessibility scale.
///
/// ### Why this file exists next to the screen matrix
/// `feature_screens_overflow_test` already renders both dashboards across the
/// device matrix and stayed green through all of it, for two compounding
/// reasons — both worth knowing before trusting a green matrix again:
///
///   1. Its `profileProvider` stub leaves the roster **empty**, and an empty
///      roster renders the dashboard's empty state instead of its body. That
///      hole is now closed there (see `_asEducatorWithRoster`).
///   2. Flutter reports a `RenderFlex` overflow from `paint()`, not from
///      layout, and this card enters behind `flutter_animate`'s `fadeIn` — at
///      opacity 0 on the harness's single pumped frame, so the chart never
///      painted and never threw. Reverting the fix leaves that suite green.
///
/// So the checks here **measure** every flex instead of waiting for an
/// exception, and pump past the entrance animation first.
List<String> overflowingFlexes(WidgetTester tester) {
  final offenders = <String>[];
  for (final node in tester.allRenderObjects.whereType<RenderFlex>()) {
    if (!node.hasSize || node.debugNeedsLayout) continue;
    final vertical = node.direction == Axis.vertical;
    final available =
        vertical ? node.constraints.maxHeight : node.constraints.maxWidth;
    // An unbounded flex (inside a scroll view) grows instead of overflowing.
    if (!available.isFinite) continue;
    var needed = 0.0;
    for (RenderBox? child = node.firstChild;
        child != null;
        child = node.childAfter(child)) {
      needed += vertical ? child.size.height : child.size.width;
    }
    // Sub-pixel rounding is not an overflow.
    if (needed - available > 0.5) {
      offenders.add(
        '${vertical ? "Column" : "Row"} needs ${needed.toStringAsFixed(1)} px '
        'in ${available.toStringAsFixed(1)} px '
        '(over by ${(needed - available).toStringAsFixed(1)})',
      );
    }
  }
  return offenders;
}

/// Day keys for the last 7 days, in the card's own `y-mm-dd` format.
Map<String, int> _week(List<int> minutes) {
  final now = DateTime.now();
  final map = <String, int>{};
  for (int i = 0; i < 7; i++) {
    final date = now.subtract(Duration(days: 6 - i));
    map['${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}'] = minutes[i];
  }
  return map;
}

ChildSummary _child(String name, List<int> minutes) => ChildSummary(
      profileId: 'child-$name',
      name: name,
      avatarEmoji: '🐼',
      avatarIndex: 0,
      disabilityType: DisabilityType.hearing,
      wordsLearned: 128,
      totalStars: 340,
      streakDays: 12,
      gamesPlayed: 46,
      averageAccuracy: 0.72,
      studyMinutesThisWeek: minutes.fold(0, (a, b) => a + b),
      studyMinutesLastWeek: 95,
      totalSessions: 31,
      dailyStudyMinutes: _week(minutes),
      categoryProgress: const {'Animals': 0.8, 'Food': 0.45},
      categoryCoverage: const {'Animals': 0.6, 'Food': 0.3},
      wordHuntFinds: 7,
      signsWatched: 22,
      wordHuntStreak: 3,
      recentScores: const [],
      lastActivityDate: DateTime.now(),
    );

/// A roster whose names are the long end of the real one — a starved name
/// column is the other way this card breaks.
final _roster = <ChildSummary>[
  _child('Ana', const [12, 45, 0, 8, 30, 5, 22]),
  _child('Cognitive/Learning Student', const [3, 0, 60, 15, 0, 9, 40]),
  _child('Bien', const [0, 0, 0, 0, 0, 0, 7]),
];

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
        id: 'educator-1',
        name: 'Test Educator',
        role: _role,
        createdAt: DateTime(2026),
      );
}

Widget _dashboard(EducatorAudience audience, UserRole role, double scale) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(role)),
        parentDashboardProvider.overrideWithValue(
          ParentDashboardSnapshot(
            timestamp: DateTime.now(),
            children: _roster,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: EducatorDashboardScreen(audience: audience),
      ),
    );

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/weekly_overview');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'sessions',
      'mood_entries',
      'alerts',
      'active_time_logs',
      'child_time_limits',
      'child_alarms',
      'custom_cards',
      'notebook',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  // ─── The card on its own ─────────────────────────────────────────
  testWidgets('WeeklyOverviewCard throws no layout exception on the matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: WeeklyOverviewCard(
          children: _roster,
          hc: HCColor.of(context),
          learnerNoun: 'student',
        ),
      ),
      // The card grows vertically inside a scrolling dashboard, so vertical
      // growth is expected; what must not happen is a burst *inner* box.
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('WeeklyOverviewCard measures clean at every device × scale',
      (tester) async {
    final problems = <String>[];
    for (final device in kTabletMatrix) {
      for (final scale in kTextScales) {
        await pumpResponsive(
          tester,
          SingleChildScrollView(
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WeeklyOverviewCard(
                  children: _roster,
                  hc: HCColor.of(context),
                  learnerNoun: 'student',
                ),
              ),
            ),
          ),
          size: device.size,
          devicePixelRatio: device.devicePixelRatio,
          textScale: scale,
        );
        // Past the staggered bar reveal, so every flex has actually painted.
        await tester.pump(const Duration(seconds: 1));

        for (final o in overflowingFlexes(tester)) {
          problems.add('$device, ${scale}x: $o');
        }
        final e = tester.takeException();
        if (e != null) problems.add('$device, ${scale}x: $e');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(problems, isEmpty, reason: 'Problems:\n  ${problems.join('\n  ')}');
  });

  testWidgets('a one-learner roster has no per-learner breakdown to burst',
      (tester) async {
    // The breakdown rows only render for 2+ learners; the chart must still be
    // clean on the single-learner dashboard most parents actually see.
    final problems = <String>[];
    for (final scale in kTextScales) {
      await pumpResponsive(
        tester,
        SingleChildScrollView(
          child: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WeeklyOverviewCard(
                children: [_roster.first],
                hc: HCColor.of(context),
              ),
            ),
          ),
        ),
        size: const Size(360, 640),
        devicePixelRatio: 3.0,
        textScale: scale,
      );
      await tester.pump(const Duration(seconds: 1));
      for (final o in overflowingFlexes(tester)) {
        problems.add('phone portrait, ${scale}x: $o');
      }
      final e = tester.takeException();
      if (e != null) problems.add('phone portrait, ${scale}x: $e');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(problems, isEmpty, reason: 'Problems:\n  ${problems.join('\n  ')}');
  });

  testWidgets('an empty week still draws seven days and no overflow',
      (tester) async {
    // Every ratio is 0 here, so each bar falls back to its 4 px minimum — the
    // shape a brand-new roster shows on day one.
    await pumpResponsive(
      tester,
      SingleChildScrollView(
        child: Builder(
          builder: (context) => WeeklyOverviewCard(
            children: [_child('New', const [0, 0, 0, 0, 0, 0, 0])],
            hc: HCColor.of(context),
          ),
        ),
      ),
      size: const Size(360, 640),
      devicePixelRatio: 3.0,
      textScale: 2.0,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(overflowingFlexes(tester), isEmpty);
    expect(tester.takeException(), isNull);
    // Mon…Sun are still all present — the fix must not have dropped a day.
    for (final day in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(day), findsOneWidget, reason: '$day is missing');
    }
  });

  // ─── The card in its real screen ─────────────────────────────────
  // The dashboards are where the stripe was reported, and a widget can lay out
  // fine in isolation and still be squeezed by the page around it.
  //
  // The page is scrolled end to end rather than measured at the top: the
  // dashboard is a lazy `CustomScrollView`, so on a phone the chart is not
  // even *built* on the first frame — a top-of-page measurement would report
  // clean without having laid the chart out at all.
  for (final (label, audience, role) in const <(
    String,
    EducatorAudience,
    UserRole
  )>[
    ('Teacher', EducatorAudience.teacher, UserRole.teacher),
    ('Parent', EducatorAudience.parent, UserRole.parent),
  ]) {
    testWidgets('$label Dashboard measures clean end to end on the matrix',
        (tester) async {
      final problems = <String>[];
      var sawChart = false;

      for (final device in kTabletMatrix) {
        for (final scale in kTextScales) {
          tester.view.physicalSize = device.size * device.devicePixelRatio;
          tester.view.devicePixelRatio = device.devicePixelRatio;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(_dashboard(audience, role, scale));
          // Past every staggered entrance so the page actually paints; an
          // un-painted flex reports no overflow at all.
          await tester.pump(const Duration(seconds: 2));

          final position =
              tester.state<ScrollableState>(find.byType(Scrollable).first)
                  .position;
          var guard = 0;
          while (true) {
            for (final o in overflowingFlexes(tester)) {
              problems.add('$device, ${scale}x @${position.pixels.round()}px: '
                  '$o');
            }
            for (Object? e = tester.takeException();
                e != null;
                e = tester.takeException()) {
              problems.add('$device, ${scale}x: $e');
            }
            sawChart |= find.byType(WeeklyOverviewCard).evaluate().isNotEmpty;

            if (position.pixels >= position.maxScrollExtent - 0.5 ||
                ++guard > 40) {
              break;
            }
            position.jumpTo(
              (position.pixels + device.size.height * 0.6)
                  .clamp(0.0, position.maxScrollExtent),
            );
            // Long enough for the newly-revealed cards' entrance delays.
            await tester.pump(const Duration(seconds: 1));
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());

      // Guards the guard: if the roster stub ever stops populating, the sweep
      // above would pass by rendering the empty state and no chart at all.
      expect(sawChart, isTrue,
          reason: 'the $label dashboard never rendered a WeeklyOverviewCard');
      expect(problems, isEmpty,
          reason: 'Problems:\n  ${problems.join('\n  ')}');
    });
  }
}
