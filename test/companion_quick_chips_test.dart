import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/widgets/tutor_chat.dart';
import 'package:pwdpwdpwd/features/companion/controllers/companion_controller.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openMemoryBoxes;
import 'support/real_fonts.dart';

/// The AI Buddy's quick chips.
///
/// A chip tapped twice before the buddy has answered asks once: a hand that
/// shakes taps twice, and the buddy answered both (on the AI Tutor screen a
/// screen reader then read "Favorites" twice in a row; the reader crawl,
/// 9 Nov). And a chip's bubble shows the chip's own words: a Filipino
/// learner tapped "Paborito" and their bubble said "favorites", in English.
class _Student extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'buddy-chips-student',
        name: 'Ana',
        role: UserRole.student,
        createdAt: DateTime(2026),
      );
}

class _Settings extends SettingsNotifier {
  _Settings(this.locale);
  final String locale;

  @override
  AppSettings build() => AppSettings(locale: locale);
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

/// `implements`, so the real `AudioPlayer()` (a platform channel) never
/// starts: the buddy plays a sound with each message.
class _SilentSound implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

GoRouter _router() => GoRouter(
      initialLocation: '/games',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              BottomNavShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/games',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Hub'))),
            ),
          ],
        ),
      ],
    );

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('companion_quick_chips');
  });

  Future<ProviderContainer> pumpOpenPanel(
    WidgetTester tester,
    String locale,
  ) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Student.new),
          settingsProvider.overrideWith(() => _Settings(locale)),
          routerProvider.overrideWithValue(router),
          ttsServiceProvider.overrideWithValue(_QuietTts()),
          soundServiceProvider.overrideWithValue(_SilentSound()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) =>
              CompanionHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    for (var t = 0; t < 10; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final container =
        ProviderScope.containerOf(tester.element(find.byType(CompanionHost)));
    container.read(companionControllerProvider.notifier).open();
    for (var t = 0; t < 20; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return container;
  }

  /// What the learner has asked, after the first [from] (the buddy keeps its
  /// conversation, so a later test opens on an earlier one's).
  List<String> asked(ProviderContainer container, [int from = 0]) => [
        for (final m in container.read(companionControllerProvider).messages)
          if (m.role == TutorMessageRole.student) m.content,
      ].sublist(from);

  Future<void> wait(WidgetTester tester, int tenths) async {
    for (var t = 0; t < tenths; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> closeUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('a double tap on a chip asks once', (tester) async {
    final container = await pumpOpenPanel(tester, 'en');
    final start = asked(container).length;
    // The chip, not the learner's bubble: that says "Favorites" too.
    final chip = find.widgetWithText(TutorQuickChip, 'Favorites');
    expect(chip, findsOneWidget, reason: 'the chip in the open panel');
    // The last chip, past the end of the row: scrolled to, as a learner does.
    await tester.ensureVisible(chip);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(chip, warnIfMissed: false);
    await wait(tester, 40);
    expect(asked(container, start), ['Favorites'],
        reason: 'the second tap came before the answer');

    // Answered, and a moment later: the same chip is a new question.
    await tester.ensureVisible(chip.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(chip.first);
    await wait(tester, 40);
    expect(asked(container, start), ['Favorites', 'Favorites'],
        reason: 'asked again after the answer, it is asked');

    await closeUp(tester);
  });

  testWidgets("a chip's bubble shows the chip's own words", (tester) async {
    final container = await pumpOpenPanel(tester, 'fil');
    final start = asked(container).length;
    final chip = find.widgetWithText(TutorQuickChip, 'Paborito');
    expect(chip, findsOneWidget, reason: 'the chip, in Filipino');
    await tester.ensureVisible(chip);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(chip);
    await wait(tester, 40);
    expect(asked(container, start), ['Paborito'],
        reason: 'the bubble says what the chip says, not "favorites"');
    final replies = [
      for (final m in container.read(companionControllerProvider).messages)
        if (m.role == TutorMessageRole.tutor) m,
    ];
    expect(
      replies.last.action?.type,
      TutorActionType.pickInterests,
      reason: 'and the buddy still understood it: the topic picker',
    );

    await closeUp(tester);
  });
}
