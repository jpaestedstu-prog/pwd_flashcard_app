import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/game_catalog.dart';
import 'package:pwdpwdpwd/data/local/daily_challenge.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/child_time_limit.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/models/parental_controls.dart';
import 'package:pwdpwdpwd/features/parent/services/learner_restrictions.dart';
import 'package:pwdpwdpwd/features/parent/services/parental_controls_service.dart';
import 'package:pwdpwdpwd/features/word_of_day/services/word_of_day_service.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// What a parent sets in Parental Controls now happens.
///
/// A press of every control found it: the daily limit, the blocked games and
/// the blocked categories were saved and shown, and nothing in the app ever
/// read them. A parent who blocked a game saw it ticked, and the child went on
/// playing it.

class _Profile extends ProfileNotifier {
  _Profile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(
        id: 'p',
        name: 'Learner',
        role: role,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
      );
}

GameHubCatalog _hub(UserRole role) {
  final container = ProviderContainer(overrides: [
    profileProvider.overrideWith(() => _Profile(role)),
  ]);
  addTearDown(container.dispose);
  return container.read(gameHubCatalogProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./build/test_cache/parental_enforced');
    await Hive.openBox('settings', bytes: Uint8List(0));
  });
  setUp(() => ParentalControlsService.resetControls());

  group('with nothing blocked, everything is as it was', () {
    test('the same lists, the very same objects', () {
      final cards = SeedData.allFlashcards;
      expect(identical(LearnerRestrictions.visibleCards(cards), cards), isTrue);
      expect(LearnerRestrictions.categoriesFor(UserRole.student),
          FlashcardCategory.values);
      const asked = <FlashcardCategory>[];
      expect(identical(LearnerRestrictions.gameCategories(asked), asked), isTrue);
    });

    test('a closed settings box blocks nothing: it fails open', () async {
      final blocked = LearnerRestrictions.controls;
      expect(blocked.hasAnyRestriction, isFalse);
    });

    test('a category roster still has its ten games', () {
      expect(_hub(UserRole.student).games.length, GameCatalog.gamesPerCategory);
    });
  });

  group('blocked games', () {
    setUp(() => ParentalControlsService.saveControls(const ParentalControls(
          blockedGames: {GameType.wordMatch, GameType.spellingBee},
        )));

    test('leave the Games tab of a learner', () {
      for (final role in [UserRole.student, UserRole.child, UserRole.player]) {
        final games = _hub(role).games;
        expect(games, isNot(contains(GameType.wordMatch)), reason: '$role');
        expect(games, isNot(contains(GameType.spellingBee)), reason: '$role');
      }
    });

    test('stay for a Teacher or a Parent', () {
      expect(LearnerRestrictions.blockedGames(UserRole.teacher), isEmpty);
      expect(LearnerRestrictions.blockedGames(UserRole.parent), isEmpty);
      expect(_hub(UserRole.teacher).games, contains(GameType.wordMatch));
    });

    test('the Games tab shows the change at once', () async {
      final container = ProviderContainer(overrides: [
        profileProvider.overrideWith(() => _Profile(UserRole.student)),
      ]);
      addTearDown(container.dispose);
      final before = container.read(gameHubCatalogProvider).games;
      await ParentalControlsService.saveControls(const ParentalControls(
        blockedGames: {GameType.flashcardQuiz},
      ));
      final after = container.read(gameHubCatalogProvider).games;
      expect(after, isNot(contains(GameType.flashcardQuiz)));
      expect(after, contains(GameType.wordMatch));
      expect(identical(before, after), isFalse);
    });

    test('every game has a route to refuse', () {
      for (final game in GameType.values) {
        expect(gameRouteOf(game), startsWith('/'), reason: '$game');
      }
    });
  });

  group('blocked categories', () {
    setUp(() => ParentalControlsService.saveControls(const ParentalControls(
          blockedCategories: {FlashcardCategory.animals},
        )));

    bool noAnimals(Iterable<Flashcard> cards) =>
        cards.every((c) => c.category != FlashcardCategory.animals);

    test('leave what is offered to a learner', () {
      expect(LearnerRestrictions.categoriesFor(UserRole.student),
          isNot(contains(FlashcardCategory.animals)));
      expect(LearnerRestrictions.playableCategories,
          isNot(contains(FlashcardCategory.animals)));
    });

    test('stay for a Teacher or a Parent, who assign them', () {
      expect(LearnerRestrictions.categoriesFor(UserRole.teacher),
          contains(FlashcardCategory.animals));
      expect(LearnerRestrictions.categoriesFor(UserRole.parent),
          contains(FlashcardCategory.animals));
    });

    test('leave a game\'s word pool, chosen or not', () {
      // "All categories" is every one but the blocked.
      final all = LearnerRestrictions.gameCategories(const []);
      expect(all, isNot(contains(FlashcardCategory.animals)));
      expect(all, isNotEmpty);
      // A saved choice of a category blocked since does not bring it back.
      final saved = LearnerRestrictions.gameCategories(
        const [FlashcardCategory.animals, FlashcardCategory.numbers],
      );
      expect(saved, [FlashcardCategory.numbers]);
    });

    test('leave what picks words by itself', () {
      expect(noAnimals(LearnerRestrictions.visibleCards(SeedData.allFlashcards)),
          isTrue);
      expect(noAnimals(DailyChallenge.todaysWords(20)), isTrue);
      expect(DailyChallenge.todaysWord().category,
          isNot(FlashcardCategory.animals));
      expect(WordOfDayService.today().category,
          isNot(FlashcardCategory.animals.label));
    });
  });

  group('the daily limit', () {
    final none = ChildTimeLimit(
      childProfileId: 'kid',
      setterProfileId: 'mom',
      setterRole: UserRole.parent,
      updatedAt: DateTime(2026),
    );

    test('switched on with none chosen is an hour, inside the slider', () {
      const controls = ParentalControls(timeLimitEnabled: true);
      expect(controls.dailyTimeLimitMinutes, 0);
      expect(controls.effectiveDailyMinutes, 60);
    });

    test('never outside the slider\'s range', () {
      expect(
        const ParentalControls(dailyTimeLimitMinutes: 5).effectiveDailyMinutes,
        ParentalControls.minDailyMinutes,
      );
      expect(
        const ParentalControls(dailyTimeLimitMinutes: 999).effectiveDailyMinutes,
        ParentalControls.maxDailyMinutes,
      );
      expect(
        const ParentalControls(dailyTimeLimitMinutes: 90).effectiveDailyMinutes,
        90,
      );
    });

    test('becomes the limit the lock goes by, for a supervised learner',
        () async {
      await ParentalControlsService.saveControls(const ParentalControls(
        timeLimitEnabled: true,
        dailyTimeLimitMinutes: 45,
      ));
      final limit = LearnerRestrictions.limitFor(
        null,
        childProfileId: 'kid',
        supervised: true,
      );
      expect(limit, isNotNull);
      expect(limit!.dailyLimitEnabled, isTrue);
      expect(limit.dailyLimitMinutes, 45);
      expect(limit.childProfileId, 'kid');
    });

    test('keeps the rest of a learner\'s own settings', () async {
      await ParentalControlsService.saveControls(const ParentalControls(
        timeLimitEnabled: true,
        dailyTimeLimitMinutes: 45,
      ));
      final limit = LearnerRestrictions.limitFor(
        none.copyWith(scheduleEnabled: true),
        childProfileId: 'kid',
        supervised: true,
      );
      expect(limit!.dailyLimitMinutes, 45);
      expect(limit.scheduleEnabled, isTrue);
    });

    test('a learner\'s own limit wins over the device\'s', () async {
      await ParentalControlsService.saveControls(const ParentalControls(
        timeLimitEnabled: true,
        dailyTimeLimitMinutes: 45,
      ));
      final own = none.copyWith(dailyLimitEnabled: true, dailyLimitMinutes: 20);
      final limit = LearnerRestrictions.limitFor(
        own,
        childProfileId: 'kid',
        supervised: true,
      );
      expect(limit!.dailyLimitMinutes, 20);
    });

    test('a Player, who owns the device, is never held by it', () async {
      await ParentalControlsService.saveControls(const ParentalControls(
        timeLimitEnabled: true,
        dailyTimeLimitMinutes: 45,
      ));
      expect(
        LearnerRestrictions.limitFor(
          null,
          childProfileId: 'player',
          supervised: false,
        ),
        isNull,
      );
    });

    test('off, it changes nothing', () {
      expect(
        LearnerRestrictions.limitFor(
          null,
          childProfileId: 'kid',
          supervised: true,
        ),
        isNull,
      );
      expect(
        identical(
          LearnerRestrictions.limitFor(
            none,
            childProfileId: 'kid',
            supervised: true,
          ),
          none,
        ),
        isTrue,
      );
    });
  });
}
