import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_settings_screen.dart';
import 'package:pwdpwdpwd/features/parent/widgets/child_detail_sheet.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// A Teacher or Parent sets a learner's hands-free input up FOR them, from the
/// learner's card — their own profile runs neither Gaze Control nor the
/// controller. The Game Controller page used to have no learner mode at all:
/// a teacher "tuning the controller for a learner" changed the teacher's own
/// settings, which never reached the learner.

class _Signed extends ProfileNotifier {
  _Signed(this.profile);
  final UserProfile profile;
  @override
  UserProfile? build() => profile;
}

/// The learner's controller settings, kept in memory: a Hive write started
/// inside a widget test stalls this file's teardown. Persistence itself is
/// covered by `hands_free_input_by_profile_test.dart`.
class _MemoryLearnerGamepad extends GamepadProfileSettingsNotifier {
  @override
  GamepadSettings build(String profileId) => const GamepadSettings();
  @override
  void update(GamepadSettings settings) => state = settings;
}

final _teacher = UserProfile(
  id: 'rose',
  name: 'Teacher Rose',
  role: UserRole.teacher,
  createdAt: DateTime(2026),
);

final _ana = UserProfile(
  id: 'ana',
  name: 'Ana',
  role: UserRole.child,
  disabilityType: DisabilityType.visual,
  createdAt: DateTime(2026),
);

ChildSummary _summary(String id, String name) => ChildSummary(
      profileId: id,
      name: name,
      avatarEmoji: '🦊',
      avatarIndex: 0,
      disabilityType: DisabilityType.visual,
      wordsLearned: 12,
      totalStars: 30,
      streakDays: 2,
      gamesPlayed: 4,
      averageAccuracy: 0.8,
      studyMinutesThisWeek: 40,
      studyMinutesLastWeek: 20,
      totalSessions: 5,
      dailyStudyMinutes: const {},
      categoryProgress: const {},
      categoryCoverage: const {},
      wordHuntFinds: 0,
      signsWatched: 0,
      wordHuntStreak: 0,
      recentScores: const [],
      lastActivityDate: DateTime(2026, 8, 10),
    );

void main() {
  const storeDir = './build/test_cache/learner_input_setup';
  final t = AppLocalizationsEn();

  setUpAll(() async {
    final dir = Directory(storeDir);
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Held by a dead run; the boxes below are opened either way.
      }
    }
    Hive.init(storeDir);
    for (final name in const [
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'classrooms',
      'classroom_members',
      'home_groups',
      'home_group_members',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    await HiveService.saveProfile(_teacher);
    await HiveService.saveProfile(_ana);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('the Game Controller page, for a learner', () {
    Future<ProviderContainer> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: [
        profileProvider.overrideWith(() => _Signed(_teacher)),
        gamepadSettingsForProfileProvider.overrideWith(
          _MemoryLearnerGamepad.new,
        ),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GamepadSettingsScreen(profileId: 'ana', learnerName: 'Ana'),
        ),
      ));
      await tester.pump();
      return container;
    }

    testWidgets('says whose it is, and how they practise', (tester) async {
      await pumpPage(tester);
      expect(find.text(t.gpForLearner('Ana')), findsOneWidget);
      expect(find.text(t.gpForLearnerNote('Ana')), findsOneWidget);
      // Practising drives the pad as the person at the tablet — the teacher,
      // whose own profile has no controller input — so it is not offered.
      expect(find.text(t.gpPractiseButtons), findsNothing);
      expect(find.text(t.gpPractiseAsLearner('Ana')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('changes the learner\'s settings, not the teacher\'s',
        (tester) async {
      final container = await pumpPage(tester);
      await tester.scrollUntilVisible(
        find.text(t.gpSwap),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(t.gpSwap));
      await tester.pump();

      expect(
        container.read(gamepadSettingsForProfileProvider('ana'))
            .swapConfirmButtons,
        isTrue,
      );
      // The teacher's own (inert) settings did not move.
      expect(container.read(gamepadSettingsProvider).swapConfirmButtons,
          isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('fits a phone at the large text sizes', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const GamepadSettingsScreen(
          profileId: 'ana',
          learnerName: 'Ana Maria Dela Cruz',
        ),
        devices: kNarrowPortrait,
        textScales: kLargeTextScales,
        overrides: [profileProvider.overrideWith(() => _Signed(_teacher))],
      );
    });
  });

  group('the learner\'s card', () {
    Future<void> pumpCard(WidgetTester tester, ChildSummary child) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => ChildDetailSheet(child: child),
                ),
                child: const Text('open-card'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/gaze-settings',
          builder: (context, state) =>
              Scaffold(body: Text('gaze for ${state.uri.query}')),
        ),
        GoRoute(
          path: '/gamepad-settings',
          builder: (context, state) =>
              Scaffold(body: Text('controller for ${state.uri.query}')),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [profileProvider.overrideWith(() => _Signed(_teacher))],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ));
      await tester.tap(find.text('open-card'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> press(WidgetTester tester, String label) async {
      final button = find.widgetWithText(OutlinedButton, label);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // scrollUntilVisible stops as soon as any part of it shows; the tap
      // goes to its centre.
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('opens the learner\'s Game Controller page', (tester) async {
      await pumpCard(tester, _summary('ana', 'Ana'));
      await press(tester, t.settingGamepadTitle);
      expect(find.text('controller for profile=ana&name=Ana'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('…and the learner\'s Gaze Control page', (tester) async {
      await pumpCard(tester, _summary('ana', 'Ana'));
      await press(tester, t.cdsGazeControl);
      expect(find.text('gaze for profile=ana&name=Ana'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a learner on another tablet gets a note, not a dead page',
        (tester) async {
      await pumpCard(tester, _summary('elsewhere', 'Ben'));
      final button =
          find.widgetWithText(OutlinedButton, t.settingGamepadTitle);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(find.text(t.gpNotOnTablet('Ben')), findsOneWidget);
      expect(find.text(t.gzsNotOnTablet('Ben')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
