import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_presentation.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_seed_data.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_vocabulary.dart';
import 'package:pwdpwdpwd/features/communication_board/models/custom_board.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';

/// The custom-tile model layer: authoring rules, the board's own invariants,
/// and how a learner's own tab splices into the seed tabs. Pure — no Flutter,
/// no Hive.

BoardTile _custom(String id, String label, {String? fil, String emoji = '👩'}) =>
    buildCustomTile(
      label: label,
      labelFil: fil ?? label,
      emoji: emoji,
      id: id,
    );

CustomBoard _board(
  List<String> ids, {
  List<BoardTile> custom = const [],
  String name = 'My Board',
}) =>
    CustomBoard(
      name: name,
      tileIds: ids,
      customTiles: custom,
      updatedAt: DateTime(2026, 4),
    );

void main() {
  group('the custom category is not a seed category', () {
    test('seedValues excludes it but values includes it', () {
      expect(BoardTileCategoryX.seedValues,
          isNot(contains(BoardTileCategory.custom)));
      expect(BoardTileCategory.values, contains(BoardTileCategory.custom));
      expect(BoardTileCategoryX.seedValues.length,
          BoardTileCategory.values.length - 1);
    });

    test('no seed tile claims it', () {
      // If one ever did it would appear on a tab that only exists when the
      // learner has built a board.
      expect(
        BoardSeedData.allTiles.where((t) => t.isCustom),
        isEmpty,
      );
    });

    test('no presentation offers it', () {
      for (final type in DisabilityType.values) {
        expect(
          BoardPresentation.forType(type).categories,
          isNot(contains(BoardTileCategory.custom)),
          reason: '$type',
        );
      }
    });

    test('it still has a label and an emoji to fall back on', () {
      expect(BoardTileCategory.custom.label, isNotEmpty);
      expect(BoardTileCategory.custom.labelFil, isNotEmpty);
      expect(BoardTileCategory.custom.emoji, isNotEmpty);
    });
  });

  group('custom tile ids', () {
    test('are prefixed so they can never collide with a seed id', () {
      final id = newCustomTileId();
      expect(isCustomTileId(id), isTrue);
      expect(BoardSeedData.byId(id), isNull);
      for (final tile in BoardSeedData.allTiles) {
        expect(isCustomTileId(tile.id), isFalse, reason: tile.id);
      }
    });

    test('are unique across a burst of creations', () {
      // Two tiles authored in the same microsecond must not share an id, or
      // one silently replaces the other in the board's lookup.
      final now = DateTime(2026, 4, 1, 12);
      final ids = {
        for (var i = 0; i < 200; i++)
          newCustomTileId(now: now, random: Random(i)),
      };
      expect(ids.length, 200);
    });
  });

  group('validateCustomTile', () {
    test('accepts an ordinary word', () {
      expect(
        validateCustomTile(label: 'Ate Maria', labelFil: 'Ate Maria', emoji: '👩'),
        isNull,
      );
    });

    test('a blank Filipino word is fine — it falls back to English', () {
      expect(
        validateCustomTile(label: 'Ate Maria', labelFil: '', emoji: '👩'),
        isNull,
      );
      final tile = buildCustomTile(
          label: 'Ate Maria', labelFil: '  ', emoji: '👩');
      // Blank would render an empty tile and speak nothing at the one moment
      // it mattered.
      expect(tile.labelFil, 'Ate Maria');
    });

    test('refuses an empty or whitespace English word', () {
      expect(validateCustomTile(label: '', labelFil: '', emoji: '👩'),
          isNotNull);
      expect(validateCustomTile(label: '   ', labelFil: '', emoji: '👩'),
          isNotNull);
    });

    test('refuses a word too long to render', () {
      final long = 'a' * (kMaxCustomTileLabel + 1);
      expect(validateCustomTile(label: long, labelFil: '', emoji: '👩'),
          isNotNull);
      expect(validateCustomTile(label: 'ok', labelFil: long, emoji: '👩'),
          isNotNull);
      expect(
        validateCustomTile(
            label: 'a' * kMaxCustomTileLabel, labelFil: '', emoji: '👩'),
        isNull,
      );
    });

    test('refuses a tile with no picture', () {
      expect(validateCustomTile(label: 'Ate', labelFil: '', emoji: ''),
          isNotNull);
    });

    test('every palette emoji is accepted', () {
      for (final e in kCustomTileEmoji) {
        expect(validateCustomTile(label: 'x', labelFil: '', emoji: e), isNull,
            reason: e);
      }
      expect(kCustomTileEmoji.toSet().length, kCustomTileEmoji.length,
          reason: 'a duplicated picture wastes a slot in a scannable palette');
    });

    test('buildCustomTile trims and marks the tile custom', () {
      final tile =
          buildCustomTile(label: '  Ate  ', labelFil: ' Ate ', emoji: ' 👩 ');
      expect(tile.label, 'Ate');
      expect(tile.labelFil, 'Ate');
      expect(tile.emoji, '👩');
      expect(tile.isCustom, isTrue);
      expect(tile.category, BoardTileCategory.custom);
    });
  });

  group('CustomBoard.resolvedTiles', () {
    test('mixes seed references and authored tiles, in order', () {
      final board = _board(
        ['c_a', 'n01', 'c_b'],
        custom: [_custom('c_a', 'Ate Maria'), _custom('c_b', 'Sir Kevin')],
      );
      expect(board.resolvedTiles.map((t) => t.label),
          ['Ate Maria', 'I need help', 'Sir Kevin']);
    });

    test('drops a seed id the catalogue no longer has', () {
      final board = _board(['n01', 'retired-seed-id']);
      expect(board.resolvedTiles.map((t) => t.id), ['n01']);
    });

    test('drops a custom id with no tile behind it', () {
      final board = _board(['c_gone', 'n01']);
      expect(board.resolvedTiles.map((t) => t.id), ['n01']);
    });

    test('empty and non-empty agree with resolvedTiles', () {
      expect(CustomBoard.empty().isEmpty, isTrue);
      // Ids that resolve to nothing leave the board effectively empty, which
      // is what decides whether Talk Board shows the tab at all.
      expect(_board(['c_gone']).isEmpty, isTrue);
      expect(_board(['n01']).isNotEmpty, isTrue);
    });
  });

  group('CustomBoard.normalized', () {
    test('de-duplicates ids, keeping the first position', () {
      final board = _board(['n01', 'n02', 'n01']);
      expect(board.normalized.tileIds, ['n01', 'n02']);
    });

    test('truncates to the cap', () {
      final ids = [
        for (var i = 0; i < kMaxCustomBoardTiles + 10; i++) 'c_$i',
      ];
      expect(_board(ids).normalized.tileIds.length, kMaxCustomBoardTiles);
    });

    test('prunes an authored tile no longer on the board', () {
      // Otherwise a word the adult deleted keeps resolving inside old saved
      // phrases and stays sayable.
      final board = _board(
        ['n01'],
        custom: [_custom('c_orphan', 'Deleted')],
      );
      expect(board.normalized.customTiles, isEmpty);
    });

    test('keeps an authored tile that is still on the board', () {
      final board = _board(['c_a'], custom: [_custom('c_a', 'Ate Maria')]);
      expect(board.normalized.customTiles.single.id, 'c_a');
    });

    test('a blank name falls back to the default', () {
      expect(_board(['n01'], name: '   ').normalized.name,
          CustomBoard.defaultName);
      expect(_board(['n01'], name: ' Bahay ').normalized.name, 'Bahay');
    });
  });

  group('CustomBoard JSON', () {
    test('round-trips a mixed board', () {
      final board = _board(
        ['c_a', 'n01'],
        custom: [_custom('c_a', 'Ate Maria')],
        name: 'Bahay ni Ana',
      );
      final copy = CustomBoard.fromJson(board.toJson());
      expect(copy.name, 'Bahay ni Ana');
      expect(copy.tileIds, ['c_a', 'n01']);
      expect(copy.customTiles.single.label, 'Ate Maria');
      expect(copy.customTiles.single.category, BoardTileCategory.custom);
      expect(copy.updatedAt, board.updatedAt);
      expect(copy.resolvedTiles.length, 2);
    });

    test('the category survives as a name, not an index', () {
      // An enum value appended later must not re-point every stored tile.
      final json = _custom('c_a', 'Ate').toJson();
      expect(json['category'], 'custom');
    });

    test('one corrupt custom tile does not cost the others', () {
      final good = _custom('c_a', 'Ate Maria').toJson();
      final board = CustomBoard.fromJson({
        'name': 'My Board',
        'tileIds': ['c_a', 'c_bad', 'n01'],
        'customTiles': [good, {'id': 'c_bad'}, 'not a map'],
        'updatedAt': DateTime(2026, 4).toIso8601String(),
      });
      expect(board.customTiles, hasLength(1));
      // The id pointing at the broken tile simply stops resolving.
      expect(board.resolvedTiles.map((t) => t.id), ['c_a', 'n01']);
    });

    test('missing fields read as an empty board rather than throwing', () {
      final board = CustomBoard.fromJson(const {});
      expect(board.tileIds, isEmpty);
      expect(board.customTiles, isEmpty);
      expect(board.name, CustomBoard.defaultName);
      expect(board.isEmpty, isTrue);
    });

    test('non-string ids are skipped', () {
      final board = CustomBoard.fromJson({
        'tileIds': ['n01', 7, null],
        'updatedAt': DateTime(2026, 4).toIso8601String(),
      });
      expect(board.tileIds, ['n01']);
    });
  });

  group('BoardVocabulary tabs', () {
    test('a learner with no board gets exactly the seed tabs', () {
      final v = BoardVocabulary.seedOnly(
          BoardPresentation.forType(DisabilityType.none));
      expect(v.hasCustomTab, isFalse);
      expect(v.categories, BoardTileCategoryX.seedValues);
    });

    test('the custom tab leads once the board has tiles', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['n01']),
      );
      expect(v.hasCustomTab, isTrue);
      expect(v.categories.first, BoardTileCategory.custom);
      expect(v.categories.length, BoardTileCategoryX.seedValues.length + 1);
    });

    test('a board whose every tile is gone shows no tab', () {
      // An empty tab is worse than none: the gaze cursor can still land on it.
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['c_gone', 'retired-seed']),
      );
      expect(v.hasCustomTab, isFalse);
      expect(v.categories, BoardTileCategoryX.seedValues);
    });

    test('it splices into a trimmed board too', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.cognitive),
        customBoard: _board(['n01']),
      );
      expect(v.categories, [
        BoardTileCategory.custom,
        BoardTileCategory.needs,
        BoardTileCategory.responses,
        BoardTileCategory.feelings,
        BoardTileCategory.food,
      ]);
    });
  });

  group('BoardVocabulary.tilesFor', () {
    test('returns the board in its authored order', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(
          ['c_a', 'n01'],
          custom: [_custom('c_a', 'Ate Maria')],
        ),
      );
      expect(v.tilesFor(BoardTileCategory.custom).map((t) => t.label),
          ['Ate Maria', 'I need help']);
    });

    test('the per-category cap does not apply to the learner own board', () {
      // maxTilesPerCategory trims a catalogue nobody curated; this board is
      // exactly what an adult chose, so hiding the last tiles they added would
      // look like the save had failed.
      final p = BoardPresentation.forType(DisabilityType.cognitive);
      expect(p.maxTilesPerCategory, 6);
      final ids = [for (var i = 1; i <= 8; i++) 'n0$i'];
      final v = BoardVocabulary(presentation: p, customBoard: _board(ids));
      expect(v.tilesFor(BoardTileCategory.custom).length, 8);
      // …but it still applies to the seed tabs.
      expect(v.tilesFor(BoardTileCategory.needs).length, 6);
    });

    test('seed tabs are untouched by the presence of a custom board', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['n01']),
      );
      expect(v.tilesFor(BoardTileCategory.greetings).length,
          BoardSeedData.forCategory(BoardTileCategory.greetings).length);
    });
  });

  group('BoardVocabulary.byId', () {
    test('finds seed tiles and authored tiles alike', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['c_a'], custom: [_custom('c_a', 'Ate Maria')]),
      );
      expect(v.byId('n01')?.label, 'I need help');
      expect(v.byId('c_a')?.label, 'Ate Maria');
      expect(v.byId('nope'), isNull);
    });

    test('a saved phrase keeps the learner own word', () {
      // The regression this lookup exists to prevent: with a seed-only
      // resolver the phrase still renders, just one word shorter, which is
      // exactly the kind of loss nobody notices until the child does.
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['c_a'], custom: [_custom('c_a', 'Ate Maria')]),
      );
      final phrase = SavedPhrase(
        id: 'x',
        tileIds: const ['g01', 'c_a'],
        lastUsedAt: DateTime(2026, 4),
      );
      expect(phrase.resolve(v.byId).map((t) => t.label),
          ['Hello', 'Ate Maria']);
      expect(phrase.resolve(BoardSeedData.byId).map((t) => t.label), ['Hello']);
    });
  });

  group('BoardVocabulary cycling', () {
    test('a full blink cycle visits the custom tab exactly once', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.cognitive),
        customBoard: _board(['n01']),
      );
      var cat = v.categories.first;
      final seen = <BoardTileCategory>[];
      for (var i = 0; i < v.categories.length; i++) {
        seen.add(cat);
        cat = v.nextCategory(cat);
      }
      expect(seen, v.categories);
      expect(cat, v.categories.first);
      expect(seen.where((c) => c == BoardTileCategory.custom).length, 1);
    });

    test('resolveCategory rescues a learner stranded on a deleted tab', () {
      // The adult empties the board while the learner is sitting on it.
      final v = BoardVocabulary.seedOnly(
          BoardPresentation.forType(DisabilityType.none));
      expect(v.resolveCategory(BoardTileCategory.custom), v.categories.first);
      expect(v.nextCategory(BoardTileCategory.custom), v.categories.first);
    });

    test('resolveCategory keeps the custom tab when it exists', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['n01']),
      );
      expect(v.resolveCategory(BoardTileCategory.custom),
          BoardTileCategory.custom);
    });
  });

  group('BoardVocabulary.labelFor', () {
    test('the custom tab wears the board own name in both languages', () {
      final v = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: _board(['n01'], name: 'Bahay ni Ana'),
      );
      expect(v.labelFor(BoardTileCategory.custom, useFilipino: false),
          'Bahay ni Ana');
      // The name an adult typed is not translated — it is usually a person or
      // a place.
      expect(v.labelFor(BoardTileCategory.custom, useFilipino: true),
          'Bahay ni Ana');
    });

    test('seed tabs still follow the language toggle', () {
      final v = BoardVocabulary.seedOnly(
          BoardPresentation.forType(DisabilityType.none));
      expect(v.labelFor(BoardTileCategory.needs, useFilipino: false), 'Needs');
      expect(v.labelFor(BoardTileCategory.needs, useFilipino: true),
          'Pangangailangan');
    });
  });
}
