import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_context.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_presentation.dart';
import 'package:pwdpwdpwd/features/notebook/models/notebook_models.dart';
import 'package:pwdpwdpwd/features/notebook/providers/notebook_provider.dart';
import 'package:pwdpwdpwd/features/notebook/screens/note_editor_screen.dart';
import 'package:pwdpwdpwd/features/notebook/screens/notebook_screen.dart';
import 'package:pwdpwdpwd/features/stickers/models/sticker_models.dart';
import 'package:pwdpwdpwd/features/stickers/models/sticker_progress.dart';
import 'package:pwdpwdpwd/features/stickers/screens/sticker_album_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/mood_provider.dart';
import 'package:pwdpwdpwd/providers/sticker_provider.dart';

/// Behaviour tests for the Personal & Wellbeing surfaces — Mood Check-In,
/// Sticker Album and My Notebook.
///
/// These three shipped with no coverage of their own beyond the overflow
/// matrix, which is why a dead search button and a never-written
/// `activityContext` survived as long as they did.

/// Stubs [profileProvider] so the mood / sticker notifiers get a stable id
/// without ProfileNotifier's Firebase stream.
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.id);
  final String id;

  @override
  UserProfile? build() => UserProfile(
        id: id,
        name: 'Test Learner',
        role: UserRole.student,
        createdAt: DateTime(2026),
      );
}

/// Fixed [AppSettings], so a screen can be rendered under a chosen
/// accessibility configuration without touching the settings box.
class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Holds the router so a test can push the editor route with an `extra`
/// payload, the way the app does.
GoRouter? _testRouter;

/// Mounts a miniature app whose `/notebook/editor` route is wired **exactly**
/// like the real one, so these tests cover the route contract (which payload
/// types it accepts) and not just the widget's constructor.
Future<void> _pumpEditorRoute(
  WidgetTester tester, {
  required String profileId,
}) async {
  Animate.defaultDuration = Duration.zero;
  addTearDown(() => Animate.defaultDuration = const Duration(milliseconds: 300));

  final router = GoRouter(
    initialLocation: '/notebook',
    routes: [
      GoRoute(
        path: '/notebook',
        builder: (_, _) => const Scaffold(body: Text('notebook list')),
      ),
      GoRoute(
        path: '/notebook/editor',
        builder: (_, state) {
          final extra = state.extra;
          return NoteEditorScreen(
            existingNote: extra is NoteEntry ? extra : null,
            draft: extra is NoteDraft ? extra : null,
          );
        },
      ),
    ],
  );
  _testRouter = router;
  addTearDown(() {
    _testRouter = null;
    router.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
        settingsProvider.overrideWith(
          () => _FixedSettings(const AppSettings(reducedMotion: true)),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Push the editor route with [extra], as a call site would.
Future<void> _open(WidgetTester tester, Object? extra) async {
  _testRouter!.push('/notebook/editor', extra: extra);
  await tester.pumpAndSettle();
}

LearningProgress _progressWith({
  int wordsLearned = 0,
  int totalStars = 0,
  int streakDays = 0,
  Map<String, double> categoryProgress = const {},
}) {
  return LearningProgress(
    profileId: 'test-profile',
    wordsLearned: wordsLearned,
    totalStars: totalStars,
    streakDays: streakDays,
    categoryProgress: categoryProgress,
    lastActivityDate: DateTime(2026, 8, 25),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./build/test_cache/personal_wellbeing');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'notebook',
      'mood_entries',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  // ─── Mood context ────────────────────────────────────────────────

  group('MoodContext', () {
    test('every context round-trips through its storage key', () {
      for (final c in MoodContext.values) {
        expect(MoodContextX.fromKey(c.storageKey), c,
            reason: '${c.name} did not round-trip');
      }
    });

    test('storage keys are unique', () {
      final keys = MoodContext.values.map((c) => c.storageKey).toSet();
      expect(keys.length, MoodContext.values.length);
    });

    test('null and unknown keys read as general, never dropped', () {
      expect(MoodContextX.fromKey(null), MoodContext.general);
      expect(MoodContextX.fromKey('start_session'), MoodContext.general);
      expect(MoodContextX.fromKey(''), MoodContext.general);
    });

    test('after_game keeps the key the model shipped documenting', () {
      // Any hand-seeded research data uses this exact string.
      expect(MoodContext.afterGame.storageKey, 'after_game');
    });

    test('both languages are filled in for every context', () {
      for (final c in MoodContext.values) {
        expect(c.label, isNotEmpty);
        expect(c.labelFilipino, isNotEmpty);
        expect(c.prompt, isNotEmpty);
        expect(c.promptFilipino, isNotEmpty);
        expect(c.labelOf(isFilipino: true), c.labelFilipino);
        expect(c.labelOf(isFilipino: false), c.label);
      }
    });
  });

  // ─── Mood presentation ───────────────────────────────────────────

  group('MoodPresentation', () {
    const settings = AppSettings();

    test('cognitive and multiple get the short, unambiguous face set', () {
      for (final type in [DisabilityType.cognitive, DisabilityType.multiple]) {
        final p = MoodPresentation.forProfile(type, settings);
        expect(p.isSimplified, isTrue, reason: type.name);
        expect(p.choices, MoodPresentation.simpleChoices);
        expect(p.showNote, isFalse);
        expect(p.showNumericAverage, isFalse);
      }
    });

    test('everyone else keeps all six moods', () {
      for (final type in [
        DisabilityType.none,
        DisabilityType.visual,
        DisabilityType.hearing,
        DisabilityType.motor,
      ]) {
        final p = MoodPresentation.forProfile(type, settings);
        expect(p.choices.length, MoodType.values.length, reason: type.name);
      }
    });

    test('typing a note is off for motor as well as the simplified set', () {
      expect(
        MoodPresentation.forProfile(DisabilityType.motor, settings).showNote,
        isFalse,
      );
      expect(
        MoodPresentation.forProfile(DisabilityType.none, settings).showNote,
        isTrue,
      );
    });

    test('the selection is spoken for visual and multiple even with TTS off',
        () {
      // `AppSettings.ttsEnabled` defaults to true, so the interesting case is
      // a learner who has turned speech OFF: visual and multiple profiles
      // still get the mood read back, because the emoji grid carries all of
      // the meaning and none of it is audible.
      const noTts = AppSettings(ttsEnabled: false);
      expect(
        MoodPresentation.forProfile(DisabilityType.visual, noTts)
            .speakSelection,
        isTrue,
      );
      expect(
        MoodPresentation.forProfile(DisabilityType.multiple, noTts)
            .speakSelection,
        isTrue,
      );
      expect(
        MoodPresentation.forProfile(DisabilityType.none, noTts).speakSelection,
        isFalse,
        reason: 'speech off means silent for a learner who does not need it',
      );
      expect(
        MoodPresentation.forProfile(DisabilityType.none, settings)
            .speakSelection,
        isTrue,
        reason: 'TTS users hear it, matching ProgressPresentation',
      );
    });

    test('reduced motion turns the entrance animations off', () {
      expect(
        MoodPresentation.forProfile(
          DisabilityType.none,
          const AppSettings(reducedMotion: true),
        ).animate,
        isFalse,
      );
    });

    test('every offered mood carries both labels and an emoji', () {
      for (final m in MoodType.values) {
        expect(m.label, isNotEmpty);
        expect(m.labelFilipino, isNotEmpty);
        expect(m.emoji, isNotEmpty);
        expect(m.labelOf(isFilipino: true), m.labelFilipino);
        expect(m.labelOf(isFilipino: false), m.label);
      }
    });
  });

  // ─── Mood notifier ───────────────────────────────────────────────

  group('MoodNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      await HiveService.saveMoodEntries('mood-test', const []);
      container = ProviderContainer(overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier('mood-test')),
      ]);
      addTearDown(container.dispose);
    });

    test('a check-in persists the context it was taken in', () async {
      final notifier = container.read(moodProvider.notifier);
      await notifier.addMood(
        mood: MoodType.happy,
        context: MoodContext.afterGame,
      );

      final entry = container.read(moodProvider).single;
      // The whole point: before this, nothing ever wrote a value here and the
      // Mood Insights "by activity" chart was one bucket.
      expect(entry.activityContext, 'after_game');
      expect(MoodContextX.fromKey(entry.activityContext),
          MoodContext.afterGame);
    });

    test('a plain check-in is filed as general', () async {
      await container.read(moodProvider.notifier).addMood(mood: MoodType.sad);
      expect(container.read(moodProvider).single.activityContext, 'general');
    });

    test('updateMood corrects in place instead of adding a second reading',
        () async {
      final notifier = container.read(moodProvider.notifier);
      final entry = await notifier.addMood(mood: MoodType.frustrated);

      await notifier.updateMood(entry.id, MoodType.happy);

      final entries = container.read(moodProvider);
      expect(entries.length, 1, reason: 'a correction is not a new entry');
      expect(entries.single.id, entry.id);
      expect(entries.single.mood, MoodType.happy);
      expect(entries.single.timestamp, entry.timestamp);
    });

    test('updateMood keeps the existing note when none is supplied', () async {
      final notifier = container.read(moodProvider.notifier);
      final entry = await notifier.addMood(
        mood: MoodType.sad,
        note: 'lost my pencil',
      );

      await notifier.updateMood(entry.id, MoodType.neutral);
      expect(container.read(moodProvider).single.note, 'lost my pencil');
    });

    test('removeMood drops exactly one entry', () async {
      final notifier = container.read(moodProvider.notifier);
      final first = await notifier.addMood(mood: MoodType.happy);
      await notifier.addMood(mood: MoodType.sad);

      await notifier.removeMood(first.id);

      final remaining = container.read(moodProvider);
      expect(remaining.length, 1);
      expect(remaining.single.mood, MoodType.sad);
    });

    test('a saved entry survives a reload from storage', () async {
      await container.read(moodProvider.notifier).addMood(
            mood: MoodType.excited,
            context: MoodContext.breakTime,
            note: 'good break',
          );

      final reloaded = HiveService.getMoodEntries('mood-test');
      expect(reloaded.single.mood, MoodType.excited);
      expect(reloaded.single.activityContext, 'break_time');
      expect(reloaded.single.note, 'good break');
    });
  });

  // ─── Sticker collection ──────────────────────────────────────────

  group('StickerCollection', () {
    final earlier = DateTime(2026, 8, 2);
    final later = DateTime(2026, 8, 20);

    test('a sticker unlocked after the last visit is new', () {
      final c = StickerCollection(
        owned: const {'stk_puppy'},
        unlockedAt: {'stk_puppy': later},
        lastSeenAt: earlier,
      );
      expect(c.isUnseen('stk_puppy'), isTrue);
      expect(c.unseenCount, 1);
    });

    test('a sticker unlocked before the last visit is not new', () {
      final c = StickerCollection(
        owned: const {'stk_puppy'},
        unlockedAt: {'stk_puppy': earlier},
        lastSeenAt: later,
      );
      expect(c.isUnseen('stk_puppy'), isFalse);
      expect(c.unseenCount, 0);
    });

    test('stickers from before dates were recorded are never announced', () {
      // Kept, not dropped — a learner keeps what they earned — but a
      // year-old sticker must not pop a "New!" card.
      const c = StickerCollection(owned: {'stk_puppy'});
      expect(c.contains('stk_puppy'), isTrue);
      expect(c.unseenCount, 0);
    });

    test('a first-ever unlock with no prior visit still counts as new', () {
      final c = StickerCollection(
        owned: const {'stk_puppy'},
        unlockedAt: {'stk_puppy': later},
      );
      expect(c.isUnseen('stk_puppy'), isTrue);
    });
  });

  group('StickerNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      await HiveService.saveOwnedStickers('sticker-test', <String>{});
      await HiveService.saveStickerUnlockDates('sticker-test', {});
      container = ProviderContainer(overrides: [
        profileProvider
            .overrideWith(() => _StubProfileNotifier('sticker-test')),
      ]);
      addTearDown(container.dispose);
    });

    test('a newly earned sticker is recorded with a date and reads as new',
        () {
      final notifier = container.read(stickerProvider.notifier);
      final unlocked =
          notifier.checkNewStickers(_progressWith(wordsLearned: 5));

      expect(unlocked.map((s) => s.id), contains('stk_puppy'));

      final collection = container.read(stickerProvider);
      expect(collection.contains('stk_puppy'), isTrue);
      expect(collection.unlockedAt['stk_puppy'], isNotNull);
      expect(collection.isUnseen('stk_puppy'), isTrue);
      expect(container.read(unseenStickerCountProvider), greaterThan(0));
    });

    test('a second check does not re-award what is already owned', () {
      final notifier = container.read(stickerProvider.notifier);
      notifier.checkNewStickers(_progressWith(wordsLearned: 5));
      final second =
          notifier.checkNewStickers(_progressWith(wordsLearned: 5));
      expect(second, isEmpty);
    });

    test('markAllSeen clears the badge without removing anything', () async {
      final notifier = container.read(stickerProvider.notifier);
      notifier.checkNewStickers(_progressWith(wordsLearned: 10));
      final ownedBefore = container.read(stickerProvider).ownedCount;
      expect(ownedBefore, greaterThan(0));

      await notifier.markAllSeen();

      final after = container.read(stickerProvider);
      expect(after.ownedCount, ownedBefore, reason: 'nothing is taken away');
      expect(after.unseenCount, 0);
      expect(container.read(unseenStickerCountProvider), 0);
    });

    test('unlock dates survive a reload from storage', () {
      container
          .read(stickerProvider.notifier)
          .checkNewStickers(_progressWith(wordsLearned: 5));

      final reloaded = HiveService.getStickerUnlockDates('sticker-test');
      expect(reloaded['stk_puppy'], isNotNull);
    });
  });

  // ─── Notebook ↔ flashcard links ──────────────────────────────────

  group('NoteEntry flashcard links', () {
    test('the notebook carries linked ids on the note it holds', () {
      // A unique profile per run. `build/test_cache/` is not cleared between
      // full-suite runs, so a fixed id inherits the previous run's notes and
      // any "exactly one note" assertion fails on the second run onward.
      final profileId = 'link-test-${DateTime.now().microsecondsSinceEpoch}';
      final container = ProviderContainer(overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
      ]);
      addTearDown(container.dispose);

      final note = NoteEntry(
        id: 'note-1',
        title: 'Keep mixing these up',
        content: 'aso vs pusa',
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
        linkedFlashcardIds: const ['card-a', 'card-b'],
      );

      // Deliberately not awaited. `addNote` updates state synchronously and
      // then persists; awaiting the Hive write makes this test hang under
      // full-suite load (see [[widget-test-hive-write-hang]]). The write path
      // itself is a plain `box.put` of the JSON asserted below, so nothing is
      // left uncovered by letting it settle on its own.
      unawaited(container.read(notebookProvider.notifier).addNote(note));

      final stored = container
          .read(notebookProvider)
          .firstWhere((n) => n.id == 'note-1');
      expect(stored.linkedFlashcardIds, ['card-a', 'card-b']);
    });

    testWidgets('a draft from a flashcard opens pre-filled and pre-linked',
        (tester) async {
      // A real seed card, because the editor resolves linked ids against
      // `allFlashcardsProvider` and deliberately drops ones it cannot find.
      final card = SeedData.allFlashcards.first;

      await _pumpEditorRoute(tester, profileId: 'draft-test');
      await _open(
        tester,
        NoteDraft(
          title: card.wordEnglish,
          category: card.category,
          linkedFlashcardIds: [card.id],
        ),
      );

      // The title arrives typed, so the learner starts on the body.
      expect(find.widgetWithText(TextField, card.wordEnglish), findsOneWidget);
      // Still a NEW note, not an edit of something that does not exist.
      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('Edit Note'), findsNothing);
      // And the word it was started from is already linked.
      expect(
        find.widgetWithText(InputChip, card.wordEnglish),
        findsOneWidget,
        reason: 'the card should arrive already linked',
      );
    });

    testWidgets('a linked id that no longer resolves is not rendered',
        (tester) async {
      // A card can be deleted after a note links it. The note keeps the id —
      // nothing is silently rewritten — but the editor shows only words that
      // still exist rather than a chip with no name.
      await _pumpEditorRoute(tester, profileId: 'draft-test-5');
      await _open(
        tester,
        const NoteDraft(title: 'Ghost', linkedFlashcardIds: ['no-such-card']),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('a draft does not trip the unsaved-changes guard',
        (tester) async {
      await _pumpEditorRoute(tester, profileId: 'draft-test-2');
      await _open(
        tester,
        const NoteDraft(title: 'Rice', linkedFlashcardIds: ['card-rice']),
      );

      // Backing straight out of a note the learner has not touched must not
      // ask them to confirm discarding the app's own pre-fill.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('notebook list'), findsOneWidget,
          reason: 'it should just leave');
    });

    testWidgets('an existing note still opens as an edit', (tester) async {
      await _pumpEditorRoute(tester, profileId: 'draft-test-3');
      await _open(
        tester,
        NoteEntry(
          id: 'n1',
          title: 'Existing',
          content: 'body',
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
        ),
      );

      expect(find.text('Edit Note'), findsOneWidget);
      expect(find.text('New Note'), findsNothing);
    });

    testWidgets('an unexpected extra type opens a blank editor, not a crash',
        (tester) async {
      // The editor route is now reachable with two different payloads. A cast
      // would throw on anything else, and a deep link or a stale push is
      // exactly where that happens — the same shape as the assessment routes'
      // dead-tap trap.
      await _pumpEditorRoute(tester, profileId: 'draft-test-4');
      await _open(tester, 'not a note at all');

      expect(tester.takeException(), isNull);
      expect(find.text('New Note'), findsOneWidget);
    });

    test('linked ids survive serialization', () {
      // `linkedFlashcardIds` was write-only until the editor grew a picker:
      // the field round-tripped fine, but nothing ever put an id in it.
      final note = NoteEntry(
        id: 'note-1',
        title: 'Keep mixing these up',
        content: 'aso vs pusa',
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
        linkedFlashcardIds: const ['card-a', 'card-b'],
      );
      final reloaded = NoteEntry.fromJson(
        Map<String, dynamic>.from(note.toJson()),
      );
      expect(reloaded.linkedFlashcardIds, ['card-a', 'card-b']);
    });

    test('a note with no links round-trips to an empty list, not null', () {
      final note = NoteEntry(
        id: 'note-2',
        title: 'Plain',
        content: '',
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );
      final reloaded = NoteEntry.fromJson(
        Map<String, dynamic>.from(note.toJson()),
      );
      expect(reloaded.linkedFlashcardIds, isEmpty);
      expect(reloaded.isVoiceNote, isFalse);
    });

    test('a voice note keeps its flag across a round-trip', () {
      final note = NoteEntry(
        id: 'note-3',
        title: 'Spoken',
        content: 'dictated words',
        isVoiceNote: true,
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
      );
      final reloaded = NoteEntry.fromJson(
        Map<String, dynamic>.from(note.toJson()),
      );
      expect(reloaded.isVoiceNote, isTrue);
    });
  });

  // ─── Sticker progress ────────────────────────────────────────────

  group('StickerProgress', () {
    test('counts toward a word goal', () {
      final p = StickerProgress.forCondition(
        'words_50',
        _progressWith(wordsLearned: 38),
      );
      expect(p.isCountable, isTrue);
      expect(p.label, '38 / 50');
      expect(p.fraction, closeTo(0.76, 0.001));
      expect(p.isComplete, isFalse);
    });

    test('one-shot conditions report no bar rather than a fake one', () {
      for (final id in const ['perfect_score', 'stories_1', 'nonsense_id']) {
        expect(StickerProgress.forCondition(id, _progressWith()).isCountable,
            isFalse,
            reason: id);
      }
    });

    test('the fraction never exceeds 1 when the learner overshoots', () {
      final p = StickerProgress.forCondition(
        'words_5',
        _progressWith(wordsLearned: 999),
      );
      expect(p.fraction, 1.0);
      expect(p.isComplete, isTrue);
    });

    // Drift guard: the album would lie if a bar could read "50 / 50" on a
    // sticker the checker still considers locked, or vice versa.
    test('completion agrees with the unlock checker for every countable goal',
        () {
      final samples = <LearningProgress>[
        _progressWith(),
        _progressWith(wordsLearned: 5, totalStars: 10, streakDays: 3),
        _progressWith(wordsLearned: 100, totalStars: 500, streakDays: 30),
        _progressWith(
          wordsLearned: 26,
          totalStars: 51,
          streakDays: 7,
          categoryProgress: {
            FlashcardCategory.animals.name: 0.9,
            FlashcardCategory.numbers.name: 0.85,
            FlashcardCategory.weather.name: 0.8,
          },
        ),
      ];

      for (final sticker in StickerData.allStickers) {
        for (final progress in samples) {
          final goal = StickerProgress.forCondition(
            sticker.unlockConditionId,
            progress,
          );
          if (!goal.isCountable) continue;
          final unlocked = StickerUnlockChecker.isUnlocked(
            sticker.unlockConditionId,
            progress,
          );
          expect(
            goal.isComplete,
            unlocked,
            reason: '${sticker.unlockConditionId}: bar says '
                '${goal.label} but checker says $unlocked',
          );
        }
      }
    });

    test('a unit is derived for every countable sticker goal', () {
      for (final sticker in StickerData.allStickers) {
        final goal = StickerProgress.forCondition(
          sticker.unlockConditionId,
          _progressWith(),
        );
        if (!goal.isCountable) continue;
        final unit =
            StickerGoalUnitX.forCondition(sticker.unlockConditionId);
        expect(unit.label, isNotEmpty);
        expect(unit.labelFilipino, isNotEmpty);
      }
    });
  });

  // ─── Sticker theming & localisation ──────────────────────────────

  group('Sticker album presentation', () {
    testWidgets('owned-tile backgrounds stay legible in every theme',
        (tester) async {
      // The real themes, not a stock ThemeData with a marker bolted on —
      // `HCColor.surface` reads the active colour scheme, so a fake pairing
      // would test a combination no learner can actually select.
      final themes = <String, ThemeData>{
        'light': AppTheme.light,
        'dark': AppTheme.dark,
        'highContrast': AppTheme.highContrast,
        'dyslexia': AppTheme.dyslexia,
      };

      for (final theme in themes.entries) {
        late HCColor hc;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.value,
            home: Builder(builder: (context) {
              hc = HCColor.of(context);
              return const SizedBox();
            }),
          ),
        );

        for (final rarity in StickerRarity.values) {
          final ratio = _contrastRatio(hc.textPrimary, rarity.surfaceOn(hc));
          // 4.5:1 is the WCAG AA floor for body text. The old hard-coded
          // pale swatches came out near 1:1 on the dark and high-contrast
          // themes — white sticker names on a near-white tile.
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${theme.key}/${rarity.name} contrast was '
                '${ratio.toStringAsFixed(2)}',
          );
        }
      }
    });

    testWidgets('a locked tile announces its goal, not a bare percentage',
        (tester) async {
      Animate.defaultDuration = Duration.zero;
      addTearDown(
          () => Animate.defaultDuration = const Duration(milliseconds: 300));
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider
                .overrideWith(() => _StubProfileNotifier('album-a11y')),
            settingsProvider.overrideWith(
              () => _FixedSettings(const AppSettings(reducedMotion: true)),
            ),
          ],
          child: const MaterialApp(home: StickerAlbumScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Read the COMPILED semantics nodes, not the Semantics widgets: the
      // defect is a merge, so it only exists once the nodes are combined.
      final locked = find.bySemanticsLabel(RegExp('Locked sticker'));
      final count = locked.evaluate().length;
      expect(count, greaterThan(0),
          reason: 'the album should have locked tiles');

      for (var i = 0; i < count; i++) {
        final label = tester.getSemantics(locked.at(i)).label;
        // The progress bar inside the tile publishes its own percentage. When
        // it is not excluded, that value merges into this node and a screen
        // reader reads "62, Locked sticker. Learn 50 words. 31 of 50" —
        // caught on a real tablet, not in a unit test.
        expect(
          label.startsWith('Locked sticker'),
          isTrue,
          reason: 'stray value merged into the label: "$label"',
        );
      }

      semantics.dispose();
    });

    test('every category tab has a Filipino label', () {
      for (final c in StickerCategory.values) {
        expect(c.labelFilipino, isNotEmpty);
        expect(c.labelOf(isFilipino: true), c.labelFilipino);
        expect(c.labelOf(isFilipino: false), c.label);
      }
    });

    test('every sticker and rarity is fully bilingual', () {
      for (final s in StickerData.allStickers) {
        expect(s.nameOf(isFilipino: true), isNotEmpty);
        expect(s.unlockDescriptionOf(isFilipino: true), isNotEmpty);
      }
      for (final r in StickerRarity.values) {
        expect(r.labelOf(isFilipino: true), isNotEmpty);
      }
    });

    test('sticker ids are unique', () {
      final ids = StickerData.allStickers.map((s) => s.id).toSet();
      expect(ids.length, StickerData.allStickers.length);
    });
  });

  // ─── Notebook ────────────────────────────────────────────────────

  group('NotebookScreen', () {
    // Reduced motion, in both the forms this app expresses it: the settings
    // flag that `Float3D` watches, and flutter_animate's global default
    // duration that `RichEmptyState` reads. With either one missed, the empty
    // state animates forever and the screen never reaches a quiet frame.
    setUp(() => Animate.defaultDuration = Duration.zero);
    tearDown(() => Animate.defaultDuration = const Duration(milliseconds: 300));

    testWidgets('the search button actually opens a search field',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider
                .overrideWith(() => _StubProfileNotifier('notebook-test')),
            settingsProvider.overrideWith(
              () => _FixedSettings(const AppSettings(reducedMotion: true)),
            ),
          ],
          child: const MaterialApp(home: NotebookScreen()),
        ),
      );
      // `pumpAndSettle` rather than `pump`: it also proves the screen can
      // reach a quiet frame at all. It could not before — the empty state's
      // decorative ring repeated forever, so this call would have timed out.
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing,
          reason: 'search starts closed');

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      // Before the fix, `_showSearchBar` set the query to ' ' and back to ''
      // inside one setState, so this field could never appear.
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'photosynthesis');
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget,
          reason: 'typing keeps the field open');

      await tester.tap(find.byIcon(Icons.search_off_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing,
          reason: 'the toggle closes it again');
    });
  });
}

/// WCAG relative-contrast ratio between two opaque colours, 1.0 (identical)
/// to 21.0 (black on white).
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
