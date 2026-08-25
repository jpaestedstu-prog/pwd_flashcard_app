import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_presentation.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_seed_data.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';

/// The Talk Board accessibility matrix. Pure, like the policy it covers — no
/// Flutter, no Hive, so the whole thing runs in milliseconds and the rules can
/// be read off the expectations.

UserProfile _profile(UserRole role, DisabilityType type) => UserProfile(
      id: 'p',
      name: 'n',
      role: role,
      disabilityType: type,
      createdAt: DateTime(2026),
    );

void main() {
  group('BoardPresentation.forType', () {
    test('every accessibility category yields a usable board', () {
      for (final type in DisabilityType.values) {
        final p = BoardPresentation.forType(type);
        expect(p.categories, isNotEmpty,
            reason: '$type must have at least one category tab');
        expect(p.maxSentenceLength, greaterThan(0), reason: '$type');
        expect(p.phoneColumns, greaterThanOrEqualTo(2), reason: '$type');
        // Every offered category must actually have tiles behind it, or the
        // learner gets an empty grid they cannot leave except by tapping on.
        for (final cat in p.categories) {
          expect(p.tilesFor(cat), isNotEmpty, reason: '$type / $cat');
        }
      }
    });

    test('visual: speaks each tile, no banner, wide targets', () {
      final p = BoardPresentation.forType(DisabilityType.visual);
      expect(p.speakOnTap, isTrue);
      // A large-type banner is drawing for nobody here.
      expect(p.showSentenceBanner, isFalse);
      expect(p.phoneColumns, 2);
      expect(p.categories, BoardTileCategoryX.seedValues);
    });

    test('hearing: banner on, no auto-speech, full vocabulary', () {
      final p = BoardPresentation.forType(DisabilityType.hearing);
      expect(p.showSentenceBanner, isTrue);
      // Speech the learner cannot hear is feedback only to the room.
      expect(p.speakOnTap, isFalse);
      expect(p.categories, BoardTileCategoryX.seedValues);
    });

    test('motor: two columns so the gaze cursor walks fewer cells', () {
      final p = BoardPresentation.forType(DisabilityType.motor);
      expect(p.phoneColumns, 2);
      // A dwell-select should not blurt a word across the classroom.
      expect(p.speakOnTap, isFalse);
      expect(p.categories, BoardTileCategoryX.seedValues);
    });

    test('cognitive and multiple share one trimmed core vocabulary', () {
      final cog = BoardPresentation.forType(DisabilityType.cognitive);
      final multi = BoardPresentation.forType(DisabilityType.multiple);
      expect(cog.categories, multi.categories);
      expect(cog.maxTilesPerCategory, multi.maxTilesPerCategory);
      expect(cog.maxSentenceLength, multi.maxSentenceLength);

      expect(cog.categories.length,
          lessThan(BoardTileCategoryX.seedValues.length));
      // Needs leads: it is what a board is for.
      expect(cog.categories.first, BoardTileCategory.needs);
      expect(cog.speakOnTap, isTrue);
      expect(cog.maxSentenceLength, lessThan(12));
    });

    test('none keeps the full board', () {
      final p = BoardPresentation.forType(DisabilityType.none);
      expect(p.categories, BoardTileCategoryX.seedValues);
      expect(p.maxTilesPerCategory, isNull);
      expect(p.maxSentenceLength, 12);
    });
  });

  group('tilesFor', () {
    test('caps a category without reordering it', () {
      final p = BoardPresentation.forType(DisabilityType.cognitive);
      final capped = p.tilesFor(BoardTileCategory.needs);
      final all = BoardSeedData.forCategory(BoardTileCategory.needs);

      expect(all.length, greaterThan(p.maxTilesPerCategory!));
      expect(capped.length, p.maxTilesPerCategory);
      // The cap takes a prefix — the seed order is the curation.
      expect(capped.map((t) => t.id), all.take(capped.length).map((t) => t.id));
    });

    test('a category shorter than the cap is returned whole', () {
      final p = BoardPresentation.forType(DisabilityType.cognitive);
      final food = BoardSeedData.forCategory(BoardTileCategory.food);
      expect(food.length, lessThanOrEqualTo(p.maxTilesPerCategory!));
      expect(p.tilesFor(BoardTileCategory.food).length, food.length);
    });

    test('an uncapped board returns every tile', () {
      final p = BoardPresentation.forType(DisabilityType.none);
      for (final cat in BoardTileCategoryX.seedValues) {
        expect(p.tilesFor(cat).length, BoardSeedData.forCategory(cat).length);
      }
    });
  });

  group('category cycling (the gaze blink gesture)', () {
    test('wraps within the learner own set, never into a trimmed-away tab', () {
      final p = BoardPresentation.forType(DisabilityType.cognitive);
      var cat = p.categories.first;
      final seen = <BoardTileCategory>{};
      for (var i = 0; i < p.categories.length; i++) {
        seen.add(cat);
        cat = p.nextCategory(cat);
      }
      // A full cycle visits every offered tab and lands back at the start.
      expect(seen, p.categories.toSet());
      expect(cat, p.categories.first);
    });

    test('recovers from a category this learner does not have', () {
      final p = BoardPresentation.forType(DisabilityType.cognitive);
      // `greetings` is trimmed away for this learner.
      expect(p.categories, isNot(contains(BoardTileCategory.greetings)));
      expect(p.nextCategory(BoardTileCategory.greetings), p.categories.first);
      expect(p.resolveCategory(BoardTileCategory.greetings), p.categories.first);
    });

    test('resolveCategory keeps a category the learner does have', () {
      final p = BoardPresentation.forType(DisabilityType.none);
      expect(
        p.resolveCategory(BoardTileCategory.food),
        BoardTileCategory.food,
      );
      expect(p.resolveCategory(null), p.categories.first);
    });
  });

  group('columns', () {
    test('a tablet gets one more column than a phone', () {
      for (final type in DisabilityType.values) {
        final p = BoardPresentation.forType(type);
        expect(p.columns(isTablet: false), p.phoneColumns);
        expect(p.columns(isTablet: true), p.phoneColumns + 1);
      }
    });
  });

  group('forProfile', () {
    test('a learner gets their own accessibility board', () {
      for (final type in DisabilityType.values) {
        final p = BoardPresentation.forProfile(
          _profile(UserRole.student, type),
        );
        expect(p.categories, BoardPresentation.forType(type).categories,
            reason: '$type');
        expect(p.speakOnTap, BoardPresentation.forType(type).speakOnTap,
            reason: '$type');
      }
    });

    test('a Child learner is treated like a Student', () {
      final child = BoardPresentation.forProfile(
        _profile(UserRole.child, DisabilityType.cognitive),
      );
      expect(child.categories,
          BoardPresentation.forType(DisabilityType.cognitive).categories);
      expect(child.maxSentenceLength, 4);
    });

    test('a Player (With Progress) gets the full board', () {
      final player = BoardPresentation.forProfile(
        _profile(UserRole.player, DisabilityType.none),
      );
      expect(player.categories, BoardTileCategoryX.seedValues);
      expect(player.maxTilesPerCategory, isNull);
    });

    test('educators keep the full board whatever their own profile says', () {
      // A teacher modelling the board *for* a learner must not have their own
      // accessibility category trim the tabs they are demonstrating.
      for (final role in [UserRole.teacher, UserRole.parent]) {
        final p = BoardPresentation.forProfile(
          _profile(role, DisabilityType.cognitive),
        );
        expect(p.categories, BoardTileCategoryX.seedValues, reason: '$role');
        expect(p.maxTilesPerCategory, isNull, reason: '$role');
      }
    });

    test('no profile (educator preview) falls back to the full board', () {
      final p = BoardPresentation.forProfile(null);
      expect(p.categories, BoardTileCategoryX.seedValues);
    });
  });

  group('boardTileAspectRatio', () {
    test('falls as the font scale rises, so the cell grows taller', () {
      expect(boardTileAspectRatio(1.0), 0.9);
      expect(boardTileAspectRatio(1.3), lessThan(boardTileAspectRatio(1.0)));
      expect(boardTileAspectRatio(2.0), lessThan(boardTileAspectRatio(1.3)));
    });

    test('clamps at both ends so a tile is never a ribbon', () {
      // Below 1.0 (some OEMs allow it) must not make the tile taller-than-tall.
      expect(boardTileAspectRatio(0.5), 0.9);
      // Above the 2.0x OS maximum must not keep shrinking.
      expect(boardTileAspectRatio(4.0), boardTileAspectRatio(2.0));
      expect(boardTileAspectRatio(4.0), greaterThanOrEqualTo(0.55));
    });
  });

  group('BoardSeedData.byId', () {
    test('resolves every seeded tile', () {
      for (final tile in BoardSeedData.allTiles) {
        expect(BoardSeedData.byId(tile.id)?.id, tile.id);
      }
    });

    test('a retired id resolves to null rather than throwing', () {
      expect(BoardSeedData.byId('does-not-exist'), isNull);
    });

    test('tile ids are unique — the GlobalKey map depends on it', () {
      // Tiles are keyed by id so an AnimatedSwitcher holding two grids at once
      // cannot put the same GlobalKey on two live widgets.
      final ids = BoardSeedData.allTiles.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('orderAndCapPhrases', () {
    SavedPhrase phrase(String id, int day, {bool pinned = false, int uses = 1}) {
      return SavedPhrase(
        id: id,
        tileIds: [id],
        lastUsedAt: DateTime(2026, 1, day),
        useCount: uses,
        pinned: pinned,
      );
    }

    test('pinned phrases come first, then recents by recency', () {
      final out = orderAndCapPhrases([
        phrase('a', 1),
        phrase('b', 5, pinned: true),
        phrase('c', 9),
        phrase('d', 3, pinned: true),
      ]);
      expect(out.map((p) => p.id), ['b', 'd', 'c', 'a']);
    });

    test('use count breaks a recency tie', () {
      final out = orderAndCapPhrases([
        phrase('rare', 4),
        phrase('often', 4, uses: 9),
      ]);
      expect(out.first.id, 'often');
    });

    test('recents are capped but pinned phrases never are', () {
      final many = [
        for (var i = 1; i <= kMaxRecentPhrases + 6; i++) phrase('r$i', i),
        for (var i = 1; i <= 5; i++) phrase('p$i', i, pinned: true),
      ];
      final out = orderAndCapPhrases(many);

      expect(out.where((p) => p.pinned).length, 5,
          reason: 'the cap must never evict something the learner pinned');
      expect(out.where((p) => !p.pinned).length, kMaxRecentPhrases);
      // The oldest recents are the ones dropped.
      expect(out.map((p) => p.id), isNot(contains('r1')));
      expect(out.map((p) => p.id), contains('r16'));
    });

    test('an empty list stays empty', () {
      expect(orderAndCapPhrases([]), isEmpty);
    });
  });

  group('SavedPhrase', () {
    test('identity is the tile sequence, so word order matters', () {
      final hello = BoardSeedData.byId('g01')!;
      final yes = BoardSeedData.byId('r01')!;
      expect(SavedPhrase.idFor([hello, yes]),
          isNot(SavedPhrase.idFor([yes, hello])));
      expect(SavedPhrase.idFor([hello, yes]), SavedPhrase.idFor([hello, yes]));
    });

    test('round-trips through JSON', () {
      final original = SavedPhrase(
        id: 'g01+r01',
        tileIds: const ['g01', 'r01'],
        lastUsedAt: DateTime(2026, 5, 4, 3, 2, 1),
        useCount: 7,
        pinned: true,
      );
      final copy = SavedPhrase.fromJson(original.toJson());
      expect(copy.id, original.id);
      expect(copy.tileIds, original.tileIds);
      expect(copy.lastUsedAt, original.lastUsedAt);
      expect(copy.useCount, original.useCount);
      expect(copy.pinned, original.pinned);
    });

    test('resolve skips retired ids and keeps the rest in order', () {
      final p = SavedPhrase(
        id: 'x',
        tileIds: const ['g01', 'retired-id', 'r01'],
        lastUsedAt: DateTime(2026),
      );
      expect(p.resolve(BoardSeedData.byId).map((t) => t.id), ['g01', 'r01']);
    });

    test('a phrase whose every tile is gone resolves to empty', () {
      final p = SavedPhrase(
        id: 'x',
        tileIds: const ['nope', 'also-nope'],
        lastUsedAt: DateTime(2026),
      );
      expect(p.resolve(BoardSeedData.byId), isEmpty);
    });
  });
}
