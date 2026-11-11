import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/local/daily_challenge.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/communication_board_screen.dart';
import 'package:pwdpwdpwd/features/daily_challenge/screens/daily_challenge_screen.dart';
import 'package:pwdpwdpwd/features/break_time/widgets/breathing_break.dart';
import 'package:pwdpwdpwd/features/break_time/screens/break_time_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/multiplayer_quiz_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_settings_screen.dart';
import 'package:pwdpwdpwd/features/goals/screens/goals_screen.dart';
import 'package:pwdpwdpwd/features/parent/models/parental_controls.dart';
import 'package:pwdpwdpwd/features/progress/screens/detailed_analytics_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/child_alarms_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/parental_controls_screen.dart';
import 'package:pwdpwdpwd/features/parent/services/parental_controls_service.dart';
import 'package:pwdpwdpwd/features/progress/theme/progress_theme_picker.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';

import 'support/all_screens.dart';
import 'support/long_content.dart';

/// What pressing every control on every screen found, on the screens
/// themselves. See `parental_controls_enforced_test.dart` for the rules.
const _me = 'sweep-profile';
final _en = AppLocalizationsEn();

class _Settings extends SettingsNotifier {
  _Settings(this.locale);
  final String locale;
  @override
  AppSettings build() => AppSettings(locale: locale);
  @override
  void update(AppSettings newSettings) => state = newSettings;
}

void main() {
  setUpAll(() async {
    await openMemoryBoxes('found_by_pressing');
    await seedLongContent(_me);
  });
  setUp(() => ParentalControlsService.resetControls());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    UserRole role = UserRole.student,
    String locale = 'en',
    Size size = const Size(800, 1280),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sweepProfileOverride(role),
        settingsProvider.overrideWith(() => _Settings(locale)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: Locale(ref.watch(settingsProvider).locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ));
    for (var t = 0; t < 15; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets('Detailed Analytics says what each chart means, in words',
      (tester) async {
    // On the tablet, with TalkBack: "10/6 / 10/13 / 10/20 ... 0 / 5 / 10 / 13",
    // no game's score, and every one of 56 days.
    final semantics = tester.ensureSemantics();
    try {
      await pump(
        tester,
        const DetailedAnalyticsScreen(),
        size: const Size(800, 4000),
      );
      expect(
        find.semantics.byLabel(RegExp(r'words learned in all, \d+ of them')),
        findsOneWidget,
      );
      expect(
        find.semantics.byLabel(RegExp(r'Active on \d+ of the last 56 days')),
        findsOneWidget,
      );
      expect(
        find.semantics.byLabel(RegExp(r'Animals: \d+ percent')),
        findsOneWidget,
      );
      // The axis's dates are no longer read, nor the title's star by name.
      expect(find.semantics.byLabel(RegExp(r'^\d+/\d+')), findsNothing);
      expect(find.semantics.byLabel(RegExp(r'Overview ⭐')), findsNothing);
      await unmount(tester);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Daily Mission does not ask for what is already done today',
      (tester) async {
    // On the tablet: "Today's mission completed!" beside "Complete the daily
    // mission to extend your streak" and "Start your streak today!".
    await pump(tester, const DailyChallengeScreen());
    expect(find.text(_en.dcStreakStart), findsOneWidget);
    expect(find.text(_en.dcStreakHint), findsOneWidget);
    await unmount(tester);

    await DailyChallenge.markCompleted(_me, false);
    await pump(tester, const DailyChallengeScreen());
    expect(find.text(_en.dcStreakTomorrow), findsOneWidget);
    expect(find.text(_en.dcStreakStart), findsNothing);
    expect(find.text(_en.dcStreakHint), findsNothing);
    await unmount(tester);
  });

  group('Parental Controls, on the screens they govern', () {
    testWidgets('a blocked category leaves a learner\'s Cards tab',
        (tester) async {
      await ParentalControlsService.saveControls(const ParentalControls(
        blockedCategories: {FlashcardCategory.animals},
      ));
      await pump(tester, const DeckListScreen());
      expect(find.text(FlashcardCategory.animals.labelOf(_en)), findsNothing);
      expect(find.text(FlashcardCategory.colorsAndShapes.labelOf(_en)),
          findsWidgets);
      await unmount(tester);
    });

    testWidgets('and stays on a Teacher\'s', (tester) async {
      await ParentalControlsService.saveControls(const ParentalControls(
        blockedCategories: {FlashcardCategory.animals},
      ));
      await pump(tester, const DeckListScreen(), role: UserRole.teacher);
      expect(find.text(FlashcardCategory.animals.labelOf(_en)), findsWidgets);
      await unmount(tester);
    });

    testWidgets('a blocked category leaves a game\'s picker', (tester) async {
      await ParentalControlsService.saveControls(const ParentalControls(
        blockedCategories: {FlashcardCategory.animals},
      ));
      late BuildContext host;
      await pump(tester, Builder(builder: (context) {
        host = context;
        return const Scaffold(body: SizedBox.shrink());
      }));
      showCategoryPicker(host).ignore();
      for (var t = 0; t < 10; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(FlashcardCategory.animals.labelOf(_en)), findsNothing);
      expect(find.text(FlashcardCategory.numbers.labelOf(_en)), findsWidgets);
      await unmount(tester);
    });

    testWidgets('a blocked game leaves the Games tab', (tester) async {
      await pump(tester, const GameHubScreen());
      final name = GameType.wordMatch.labelOf(_en);
      Future<bool> offered() async {
        final list = find.byWidgetPredicate((w) =>
            w is Scrollable &&
            axisDirectionToAxis(w.axisDirection) == Axis.vertical);
        final p = tester.state<ScrollableState>(list.first).position;
        p.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 200));
        for (var i = 0; i < 20; i++) {
          if (find.textContaining(name).evaluate().isNotEmpty) return true;
          if (p.extentAfter <= 0) break;
          p.jumpTo((p.pixels + 300).clamp(0.0, p.maxScrollExtent));
          await tester.pump(const Duration(milliseconds: 200));
        }
        return false;
      }

      expect(await offered(), isTrue, reason: 'it is offered at first');
      await ParentalControlsService.saveControls(const ParentalControls(
        blockedGames: {GameType.wordMatch},
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await offered(), isFalse, reason: 'and gone once blocked');
      await unmount(tester);
    });

    testWidgets('switching the limit on starts at an hour, in the slider\'s '
        'range: it used to fail the slider\'s check at 0', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = errors.add;
      await pump(tester, const ParentalControlsScreen(),
          role: UserRole.parent);
      await tester.tap(find.byType(Switch).first);
      for (var t = 0; t < 6; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      FlutterError.onError = old;
      expect(errors, isEmpty);
      final slider = tester.widget<Slider>(find.byType(Slider).first);
      expect(slider.value, 60);
      expect(slider.min, 15);
      expect(slider.max, 180);
      await unmount(tester);
    });

    testWidgets('the last category cannot be blocked: no game would have a '
        'word to play with', (tester) async {
      await ParentalControlsService.saveControls(ParentalControls(
        blockedCategories: FlashcardCategory.values.skip(1).toSet(),
      ));
      await pump(tester, const ParentalControlsScreen(),
          role: UserRole.parent);
      final boxes = find.byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical);
      final p = tester.state<ScrollableState>(boxes.first).position;
      p.jumpTo(p.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 300));
      final name = FlashcardCategory.values.first.labelOf(_en);
      for (var i = 0; i < 40 && find.text(name).evaluate().isEmpty; i++) {
        p.jumpTo((p.pixels - 200).clamp(0.0, p.maxScrollExtent));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final tile = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(tile.onChanged, isNull);
      await unmount(tester);
    });
  });

  testWidgets('the Talk Board follows the app\'s language while it is open',
      (tester) async {
    final container = await pump(tester, const CommunicationBoardScreen());
    expect(find.text('Greetings'), findsWidgets);
    expect(find.text('Pagbati'), findsNothing);
    container.read(settingsProvider.notifier).update(
          container.read(settingsProvider).copyWith(locale: 'fil'),
        );
    for (var t = 0; t < 10; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Pagbati'), findsWidgets);
    expect(find.text('Greetings'), findsNothing);
    await unmount(tester);
  });

  testWidgets('an alarm\'s switch has a name', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      const ChildAlarmsScreen(childProfileId: 'long-1'),
      role: UserRole.parent,
    );
    expect(find.bySemanticsLabel(_en.alThisAlarm), findsOneWidget);
    await unmount(tester);
    semantics.dispose();
  });

  testWidgets('a Showcase card with long words grows with them, on a phone at '
      'the largest text size: fixed cells ran 175 px out of the bottom',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    await pump(
      tester,
      const ShowcaseScreen(),
      size: const Size(360, 640),
      textScale: 1.5,
    );
    FlutterError.onError = old;
    expect(errors, isEmpty);
    await unmount(tester);
  });

  testWidgets('a goal\'s deadline shows which one is chosen, by name, and the '
      'sheet fits a phone at the largest text size', (tester) async {
    final semantics = tester.ensureSemantics();
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
    await pump(
      tester,
      const GoalsScreen(),
      size: const Size(360, 640),
      textScale: 1.5,
      locale: 'fil',
    );
    await tester.tap(find.text('Bagong Layunin').first);
    for (var t = 0; t < 8; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The longest category's name in a chip: it ran 19 px off the edge.
    final mastery = find.textContaining('Kahusayan sa Kategorya');
    await tester.ensureVisible(mastery);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(mastery);
    for (var t = 0; t < 4; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final deadline = find.text('Magtakda ng takdang araw');
    await tester.ensureVisible(deadline);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(deadline);
    for (var t = 0; t < 4; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    ChoiceChip chip(String label) => tester.widget<ChoiceChip>(find.ancestor(
          of: find.text(label),
          matching: find.byType(ChoiceChip),
        ));
    // On means something at once: a week, until another is chosen.
    expect(chip('7 araw').selected, isTrue);
    final thirty = find.text('30 araw');
    await tester.ensureVisible(thirty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(thirty);
    for (var t = 0; t < 4; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(chip('30 araw').selected, isTrue);
    expect(chip('7 araw').selected, isFalse);
    expect(
      tester.getSemantics(thirty),
      matchesSemantics(
        label: '30 araw',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(errors.map((e) => e.exceptionAsString().split('\n').first), isEmpty);
    await unmount(tester);
    } finally {
      // Back before the binding checks the test, whatever happened.
      FlutterError.onError = old;
      semantics.dispose();
    }
  });

  testWidgets('the two-player quiz opens its first question at the largest text '
      'size, and its answers are buttons', (tester) async {
    // A shrink-wrapped grid under an IntrinsicHeight: from Large up, the whole
    // screen failed to lay out as the first question opened.
    final semantics = tester.ensureSemantics();
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await pump(
        tester,
        const MultiplayerQuizScreen(),
        size: const Size(360, 640),
        textScale: 1.5,
      );
      final start = find.text(_en.mqStart);
      await tester.ensureVisible(start);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(start);
      for (var t = 0; t < 10; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text(_en.mqTapStart));
      for (var t = 0; t < 15; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        errors.map((e) => e.exceptionAsString().split('\n').first),
        isEmpty,
      );
      // Four of them, each a button.
      final answers = <SemanticsData>[];
      bool visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        // ignore: deprecated_member_use
        if (d.hasFlag(SemanticsFlag.isButton) &&
            d.hasAction(SemanticsAction.tap) &&
            // ignore: deprecated_member_use
            d.hasFlag(SemanticsFlag.hasSelectedState)) {
          answers.add(d);
        }
        n.visitChildren(visit);
        return true;
      }

      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode
          ?.visitChildren(visit);
      expect(answers.length, greaterThanOrEqualTo(2));
      await unmount(tester);
    } finally {
      FlutterError.onError = old;
      semantics.dispose();
    }
  });

  testWidgets('the breathing break gives way to its words in a short space',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await pump(
        tester,
        const Scaffold(
          body: SizedBox(
            height: 240,
            child: BreathingBreak(
              color: Colors.blue,
              textColor: Colors.black,
              reducedMotion: true,
            ),
          ),
        ),
        size: const Size(360, 640),
        textScale: 1.5,
      );
      expect(
        errors.map((e) => e.exceptionAsString().split('\n').first),
        isEmpty,
      );
      await unmount(tester);
    } finally {
      FlutterError.onError = old;
    }
  });

  group('What only a press reaches, as a screen reader meets it', () {
    // Every node now, with what a reader is told.
    List<SemanticsNode> nodes(WidgetTester tester) {
      final out = <SemanticsNode>[];
      bool visit(SemanticsNode n) {
        out.add(n);
        n.visitChildren(visit);
        return true;
      }

      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode
          ?.visitChildren(visit);
      return out;
    }

    SemanticsNode named(WidgetTester tester, String label) => nodes(tester)
        .firstWhere((n) => n.getSemanticsData().label.contains(label));

    // ignore: deprecated_member_use
    bool isButton(SemanticsNode n) =>
        // ignore: deprecated_member_use
        n.getSemanticsData().hasFlag(SemanticsFlag.isButton);

    Future<void> settle(WidgetTester tester) async {
      for (var t = 0; t < 8; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('the Talk Board\'s buttons beside a sentence are buttons a '
        'finger can hit: they were 32 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const CommunicationBoardScreen());
      await tester.tap(find.text('Hello').first);
      await settle(tester);
      for (final label in [_en.tbSpeakSentence, _en.tbRemoveLast, _en.tbClearAll]) {
        final node = named(tester, label);
        expect(isButton(node), isTrue, reason: label);
        expect(node.rect.width, greaterThanOrEqualTo(48), reason: label);
        expect(node.rect.height, greaterThanOrEqualTo(48), reason: label);
      }
      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('a saved sentence is said once, and whole', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const CommunicationBoardScreen());
      await tester.tap(find.text('Hello').first);
      await settle(tester);
      await tester.tap(find.bySemanticsLabel(_en.tbSave));
      await settle(tester);
      final row = named(tester, _en.tbSavedPhrase('Hello'));
      expect(row.getSemanticsData().label, _en.tbSavedPhrase('Hello'));
      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('a schedule\'s times are buttons, for a key and a controller '
        'too', (tester) async {
      final semantics = tester.ensureSemantics();
      await ParentalControlsService.saveControls(
        const ParentalControls(scheduleEnabled: true),
      );
      await pump(tester, const ParentalControlsScreen(), role: UserRole.parent);
      final start = find.text(_en.pcStart);
      await tester.ensureVisible(start);
      await settle(tester);
      expect(isButton(named(tester, _en.pcStart)), isTrue);
      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('a progress theme in its picker is a button, and says when it '
        'is the chosen one', (tester) async {
      final semantics = tester.ensureSemantics();
      late BuildContext host;
      await pump(tester, Builder(builder: (context) {
        host = context;
        return const Scaffold(body: SizedBox.shrink());
      }));
      showProgressCustomizeSheet(
        host,
        selectedThemeId: 'classic',
        selectedLayoutId: 'comfortable',
        onThemeSelected: (_) {},
        onLayoutSelected: (_) {},
      ).ignore();
      await settle(tester);
      final ocean = named(tester, 'Ocean');
      expect(isButton(ocean), isTrue);
      final d = named(tester, 'Classic').getSemanticsData();
      // ignore: deprecated_member_use
      expect(d.hasFlag(SemanticsFlag.isSelected), isTrue);
      await unmount(tester);
      semantics.dispose();
    });

    testWidgets('a break\'s choices are said once', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const BreakTimeScreen());
      final card = named(tester, _en.btBreathe);
      final label = card.getSemanticsData().label;
      expect('\n'.allMatches(label), isEmpty, reason: label);
      expect(isButton(card), isTrue);
      expect(find.text(_en.btCalmTitle), findsOneWidget);
      await unmount(tester);
      semantics.dispose();
    });
  });

  group('Words that only show with data from the cloud', () {
    testWidgets('a time limit\'s and an alarm\'s "last saved" are in the app\'s '
        'language, through the translations', (tester) async {
      // The sentences themselves: the screens need a cloud to show them, and
      // no_literal_text_guard_test keeps the literals out.
      final fil = await AppLocalizations.delegate.load(const Locale('fil'));
      expect(fil.tlLastSaved(fil.gmJustNow), 'Huling na-save: ngayon lang');
      expect(fil.alLastSynced(fil.gmMinutesAgo(5)),
          'Huling na-sync: 5 min ang nakalipas');
      expect(fil.crbRetryNow, 'Subukan ulit ngayon');
      expect(_en.tlOnlyBetween('8:00 AM', '5:00 PM'), 'Only 8:00 AM – 5:00 PM');
    });
  });

  // The pressed row keeps itself alive while its ripple runs. Scan Mode takes
  // away the row above it, so a row that has never been laid out inherits that
  // place, and it is put aside at the end of the list unbuilt: a screen
  // reader's walk of the page then fails on it, and that update of the page is
  // lost. Only a row taller than the room below the screen does it: a phone at
  // the largest text size.
  testWidgets('Scan Mode pressed with a screen reader on, at any place on the '
      'page: nothing is left unbuilt', (tester) async {
    final semantics = tester.ensureSemantics();
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    final container = await pump(
      tester,
      const GazeSettingsScreen(),
      size: const Size(360, 640),
      textScale: 1.5,
      locale: 'fil',
    );
    final gaze = container.read(gazeSettingsProvider.notifier);
    gaze.setDwellSelect(true);
    await tester.pump(const Duration(milliseconds: 200));
    final position = tester
        .state<ScrollableState>(find
            .byWidgetPredicate((w) =>
                w is Scrollable &&
                axisDirectionToAxis(w.axisDirection) == Axis.vertical)
            .first)
        .position;

    SemanticsNode? scanRow() {
      SemanticsNode? hit;
      bool visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.label.startsWith('Mode ng pag-scan') &&
            d.hasAction(SemanticsAction.tap)) {
          hit = n;
        }
        n.visitChildren(visit);
        return true;
      }

      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode
          ?.visitChildren(visit);
      return hit;
    }

    const newline = '\n';
    var pressed = 0;
    for (var at = 0.0; at < position.maxScrollExtent; at += 40) {
      position.jumpTo(at);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final row = scanRow();
      if (row == null) continue;
      pressed++;
      row.owner!.performAction(row.id, SemanticsAction.tap);
      for (var t = 0; t < 4; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      gaze.setScanMode(false);
      for (var t = 0; t < 4; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    FlutterError.onError = old;
    expect(pressed, greaterThan(0), reason: 'the row was reached');
    expect(errors.map((e) => e.exceptionAsString().split(newline).first), isEmpty);
    gaze.setDwellSelect(false);
    await unmount(tester);
    semantics.dispose();
  });
}
