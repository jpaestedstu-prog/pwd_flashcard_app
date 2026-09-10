import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/tv_cast_session.dart';
import 'package:pwdpwdpwd/features/tv_cast/providers/tv_cast_provider.dart';
import 'package:pwdpwdpwd/features/tv_cast/screens/tv_cast_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// The phone-side half of "Fullscreen picture & video".
///
/// `tv_cast_session_test.dart` proves the flag exists and serialises,
/// `tv_cast_server_test.dart` proves it reaches the TV over the real HTTP
/// server, and `tools/tv_cast_render_check.js` proves the TV acts on it. What
/// none of them touch is the control the educator actually presses: that it is
/// on the cast screen at all, that it is switched off out of the box, that
/// pressing it flips the session, and that it is disabled in the two modes where
/// filling the screen with media would hide the answer options or the roster.
class _StubProfile extends ProfileNotifier {
  _StubProfile(this.role);

  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
        id: 'cast-educator',
        name: 'Test Educator',
        role: role,
        createdAt: DateTime(2026),
      );
}

/// Starts the cast session mid-cast. The real notifier's `build()` only
/// registers dispose hooks and returns an idle session, so seeding a running
/// one keeps every real method — including `setBigPictureOnTv` — intact.
class _RunningCast extends TvCastSessionNotifier {
  _RunningCast(this.seed);

  final TvCastSession seed;

  @override
  TvCastSession build() {
    super.build();
    return seed;
  }
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/tv_cast_big_picture');
    for (final name in const <String>[
      'classroom_members', 'classrooms', 'error_logs', 'goals',
      'home_group_members', 'home_groups', 'profiles', 'progress',
      'sessions', 'settings', 'sync_queue',
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

  const label = 'Fullscreen picture & video';

  /// The tablet the app ships on: 1200x1920 at dpr 1.75 = 686x1097 logical.
  void useTabletViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.reset);
  }

  TvCastSession casting(CastMode mode) => TvCastSession(
        mode: mode,
        category: mode == CastMode.flashcards
            ? FlashcardCategory.animals
            : null,
        isServerRunning: true,
        listenUrl: 'http://192.168.1.5:8088/c/ABCDE',
        castCode: 'ABCDE',
      );

  /// Pumps the cast screen mid-cast and returns the container, so a test can
  /// read the session back after driving the UI.
  Future<ProviderContainer> pumpCast(
    WidgetTester tester,
    CastMode mode, {
    UserRole role = UserRole.teacher,
  }) async {
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith(() => _StubProfile(role)),
      tvCastSessionProvider.overrideWith(() => _RunningCast(casting(mode))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvCastScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pump();
  }

  SwitchListTile switchFor(WidgetTester tester, String text) {
    return tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text(text),
        matching: find.byType(SwitchListTile),
      ),
    );
  }

  testWidgets('the control is on the cast screen and starts off',
      (tester) async {
    useTabletViewport(tester);

    final container = await pumpCast(tester, CastMode.flashcards);
    await scrollTo(tester, find.text(label));

    expect(find.text(label), findsOneWidget);
    expect(switchFor(tester, label).value, isFalse);
    expect(container.read(tvCastSessionProvider).bigPictureOnTv, isFalse);

    // Its neighbour — the browser-chrome toggle — is a separate control that
    // defaults the other way. Both must be present and independently settable.
    expect(find.text('Fullscreen on TV'), findsOneWidget);
    expect(switchFor(tester, 'Fullscreen on TV').value, isTrue);
  });

  testWidgets('pressing it turns the mode on for connected TVs',
      (tester) async {
    useTabletViewport(tester);

    final container = await pumpCast(tester, CastMode.flashcards);
    await scrollTo(tester, find.text(label));

    final before = container.read(tvCastSessionProvider).revision;
    await tester.tap(find.text(label));
    await tester.pump();

    final after = container.read(tvCastSessionProvider);
    expect(after.bigPictureOnTv, isTrue);
    expect(switchFor(tester, label).value, isTrue);
    // The TV only repaints when the revision moves; without the bump the
    // switch would look on and the TV would never hear about it.
    expect(after.revision, greaterThan(before));
    // And it must not have disturbed what is being cast.
    expect(after.mode, CastMode.flashcards);
    expect(after.category, FlashcardCategory.animals);
    expect(after.fullscreenOnTv, isTrue);

    // Pressing again turns it off and bumps the revision again.
    await tester.tap(find.text(label));
    await tester.pump();
    final off = container.read(tvCastSessionProvider);
    expect(off.bigPictureOnTv, isFalse);
    expect(off.revision, greaterThan(after.revision));
  });

  testWidgets('it is disabled in live activity mode', (tester) async {
    useTabletViewport(tester);

    await pumpCast(tester, CastMode.live);
    await scrollTo(tester, find.text(label));

    // A live question's answer options are the content — blowing up its sign
    // clip would push them off the screen, so the control is not offered.
    expect(switchFor(tester, label).onChanged, isNull);
    // The browser-chrome toggle still applies in every mode.
    expect(switchFor(tester, 'Fullscreen on TV').onChanged, isNotNull);
  });

  testWidgets('it is disabled on the progress board', (tester) async {
    useTabletViewport(tester);

    await pumpCast(tester, CastMode.progress);
    await scrollTo(tester, find.text(label));

    expect(switchFor(tester, label).onChanged, isNull);
  });

  testWidgets('it is offered in FSL and Story modes too', (tester) async {
    useTabletViewport(tester);

    for (final mode in const [CastMode.fslVideo, CastMode.story]) {
      await pumpCast(tester, mode);
      await scrollTo(tester, find.text(label));
      expect(
        switchFor(tester, label).onChanged,
        isNotNull,
        reason: 'expected the control to be usable in $mode',
      );
    }
  });

  testWidgets('the cast screen mid-cast fits every device and text scale',
      (tester) async {
    // `uncovered_screens_test.dart` renders this screen only *before* casting
    // starts, so it stops at the Start card and has never laid out any of the
    // mid-cast controls. Adding a switch with a three-line subtitle to that
    // stack is exactly the change that overflows at 2.0x font on a 360dp phone,
    // so the new control gets its own matrix pass. The screen is one
    // SingleChildScrollView, so every control below the fold is still built and
    // laid out here even though it is off-screen.
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const TvCastScreen(),
      devices: const [
        DeviceSize('7" portrait', Size(600, 960)),
        DeviceSize('phone portrait', Size(360, 640), devicePixelRatio: 3.0),
      ],
      overrides: [
        profileProvider.overrideWith(() => _StubProfile(UserRole.teacher)),
        tvCastSessionProvider.overrideWith(
          () => _RunningCast(casting(CastMode.flashcards)),
        ),
      ],
    );
  });

  testWidgets('a Parent gets the same control as a Teacher', (tester) async {
    useTabletViewport(tester);

    final container =
        await pumpCast(tester, CastMode.story, role: UserRole.parent);
    await scrollTo(tester, find.text(label));

    await tester.tap(find.text(label));
    await tester.pump();
    expect(container.read(tvCastSessionProvider).bigPictureOnTv, isTrue);
  });
}
