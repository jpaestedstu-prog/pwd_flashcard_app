import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Coverage contract for the hands-free D-pad: with Gaze Control on and the
/// "Bottom nav + feature tiles" reach selected, every hub screen must publish a
/// gaze cell (label + activate) for **all** of its actionable content — feature
/// tiles, banners/CTAs, utility buttons and the vocabulary category cards — so
/// the shell's D-pad (and voice) can reach everything a finger can tap.

/// Stubs [profileProvider] with a fixed profile so the hubs build without the
/// Firebase-backed remote stream.
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role, {this.guest = false});
  final UserRole _role;
  final bool guest;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: _role,
        isGuestPlayer: guest,
        createdAt: DateTime(2026),
      );
}

/// Gaze Control enabled with the combined "Bottom nav + feature tiles" scope,
/// bypassing Hive persistence.
class _GazeTilesOnNotifier extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(
        enabled: true,
        navScope: GazeNavScope.bottomNavAndHomeTiles,
      );
}

List<Override> _overrides(UserRole role, {bool guest = false}) => [
      profileProvider.overrideWith(() => _StubProfileNotifier(role, guest: guest)),
      gazeSettingsProvider.overrideWith(_GazeTilesOnNotifier.new),
    ];

/// All labels currently published to the shell's D-pad, in row-major order.
List<String> _publishedLabels() =>
    [for (final row in gazeHomeGrid.rows) ...row.map((c) => c.label)];

Future<void> _pumpHub(
  WidgetTester tester,
  Widget hub, {
  required UserRole role,
  bool guest = false,
}) async {
  // A portrait-tablet surface (the app's target form factor) — the default
  // 800×600 test window is shorter than some hub layouts are designed for.
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(role, guest: guest),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: hub,
      ),
    ),
  );
  // The registrar publishes in a post-frame callback; one extra frame makes it
  // visible to the assertions.
  await tester.pump();
}

/// Unmounts the hub and flushes the mascot's pending blink timer (a repeating
/// `Future.delayed` of up to ~5.5 s) so `testWidgets` ends with no live timers.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/gaze_hub_coverage');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  setUp(() => gazeHomeGrid.clearGrid());

  testWidgets('Student Home publishes every actionable tile to the D-pad',
      (tester) async {
    await _pumpHub(tester, const HomeScreen(), role: UserRole.student);

    final labels = _publishedLabels();
    expect(
      labels,
      containsAll(<String>[
        // App-bar utilities (topmost gaze row).
        'Star Shop', 'Settings',
        // Banner-level entries.
        'Player Profile', 'Daily Challenge',
        // Core "Play & Learn" tiles.
        'Games', 'Words', 'Stories', 'Smart Review', 'Progress',
        // Grouped "More" sections, incl. the ones this task names.
        'Learning Paths', 'Guided Practice', 'Hard Words', 'What to Study',
        'Word Hunt', 'My Goals', 'Talk Board', 'AI Tutor', 'Play Together',
        'Messages', 'Peer Collab', 'Mood Check-In', 'My Notebook',
        // Every vocabulary category card at the bottom of Home.
        ...FlashcardCategory.values.map((c) => c.label),
      ]),
    );
    // No ghost cells for banners that aren't visible (no pending assignments,
    // not a guest, no classroom/home-group membership).
    expect(labels, isNot(contains('Assignments')));
    expect(labels, isNot(contains('Join a class')));
    expect(labels, isNot(contains('Join the class')));

    await _unmount(tester);
  });

  testWidgets('Child Home publishes every actionable tile to the D-pad',
      (tester) async {
    await _pumpHub(tester, const ChildHomeScreen(), role: UserRole.child);

    expect(
      _publishedLabels(),
      containsAll(<String>[
        'Accessibility',
        'Games', 'Cards', 'Stories', 'Practice Words', 'My Progress',
        'Adventure Map', 'Practice With Me', 'Word Hunt', 'Talk Board',
        'Play Together', 'Messages',
        'Stickers', 'My Feelings', 'How was it?', 'My Notebook',
        'Switch profile',
      ]),
    );

    await _unmount(tester);
  });

  testWidgets('Games hub publishes the Play Together banner and the games',
      (tester) async {
    await _pumpHub(tester, const GameHubScreen(), role: UserRole.student);

    final labels = _publishedLabels();
    expect(labels, contains('Play Together'));
    expect(labels, contains(GameType.wordMatch.label));
    expect(labels, contains(GameType.memoryMatch.label));
    // The banner row sits above the game rows, matching the visual order.
    expect(labels.first, 'Play Together');

    await _unmount(tester);
  });

  testWidgets('Progress publishes Customize plus every action button',
      (tester) async {
    await _pumpHub(tester, const ProgressScreen(), role: UserRole.student);

    expect(
      _publishedLabels(),
      containsAll(<String>['Customize', 'Streak Calendar', 'Certificates']),
    );
    // Customize is the topmost row, matching the app bar's visual position.
    expect(_publishedLabels().first, 'Customize');

    await _unmount(tester);
  });

  testWidgets('Cards hub publishes every category deck', (tester) async {
    await _pumpHub(tester, const DeckListScreen(), role: UserRole.student);

    expect(
      _publishedLabels(),
      containsAll(FlashcardCategory.values.map((c) => c.label)),
    );

    await _unmount(tester);
  });

  testWidgets('Guest Player home publishes all buttons incl. Accessibility',
      (tester) async {
    await _pumpHub(
      tester,
      const PlayerHomeScreen(),
      role: UserRole.player,
      guest: true,
    );

    expect(
      _publishedLabels(),
      containsAll(<String>[
        'Start Learning', 'Browse flashcards', 'How was it?',
        'Join class', 'Join group', 'Switch profile', 'Accessibility',
      ]),
    );
    // The floating Accessibility button is the topmost control and registers
    // first (the scroll body's sections register at layout time, after it),
    // so the nav-less guest D-pad starts there.
    expect(_publishedLabels().first, 'Accessibility');

    await _unmount(tester);
  });
}
