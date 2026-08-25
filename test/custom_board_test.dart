import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_presentation.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_vocabulary.dart';
import 'package:pwdpwdpwd/features/communication_board/models/custom_board.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';
import 'package:pwdpwdpwd/features/communication_board/providers/board_phrases_provider.dart';
import 'package:pwdpwdpwd/features/communication_board/providers/custom_board_provider.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// Custom-board persistence against **real Hive**.
///
/// Plain `test()` cases in their own file: mixing `testWidgets` with awaited
/// `box.put` poisons the box's write queue for every later case. The builder's
/// widget-level behaviour lives in `test/board_builder_screen_test.dart` with
/// an in-memory store.

BoardTile _custom(String id, String label, {String emoji = '👩'}) =>
    buildCustomTile(label: label, labelFil: label, emoji: emoji, id: id);

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
  late Box box;
  var clock = DateTime(2026, 4);

  setUpAll(() async {
    Hive.init('./build/test_cache/custom_board');
    // Compaction renames the box file mid-write on Windows and throws
    // PathAccessException; this suite does many puts.
    box = await Hive.openBox(
      'progress',
      compactionStrategy: (total, deleted) => false,
    );
  });

  setUp(() async {
    await box.clear().timeout(const Duration(seconds: 5));
    clock = DateTime(2026, 4);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  CustomBoardNotifier notifier(String profileId) {
    final n = CustomBoardNotifier(HiveCustomBoardStore(profileId));
    n.now = () => clock;
    return n;
  }

  group('a profile with no board', () {
    test('starts empty and shows no tab', () {
      final n = notifier('fresh');
      expect(n.state.isEmpty, isTrue);
      expect(n.state.name, CustomBoard.defaultName);
      expect(
        BoardVocabulary(
          presentation: BoardPresentation.forType(DisabilityType.none),
          customBoard: n.state,
        ).hasCustomTab,
        isFalse,
      );
    });
  });

  group('saving a board', () {
    test('a mixed board survives a rebuild of the notifier', () async {
      final a = notifier('kid');
      await a.replace(_board(
        ['n01', 'c_ate'],
        custom: [_custom('c_ate', 'Ate Maria')],
        name: 'Bahay ni Ana',
      ));

      // A new notifier is what the learner gets on the next app launch.
      final b = notifier('kid');
      expect(b.state.name, 'Bahay ni Ana');
      expect(b.state.tileIds, ['n01', 'c_ate']);
      expect(b.state.resolvedTiles.map((t) => t.label),
          ['I need help', 'Ate Maria']);
      // The authored tile came back whole, not as a bare id.
      expect(b.state.customTiles.single.emoji, '👩');
      expect(b.state.customTiles.single.category, BoardTileCategory.custom);
    });

    test('boards are per profile', () async {
      await notifier('kid-a').replace(_board(['n01']));
      expect(notifier('kid-b').state.isEmpty, isTrue);
      expect(notifier('kid-a').state.isNotEmpty, isTrue);
    });

    test('replace stamps updatedAt from the clock', () async {
      final n = notifier('kid');
      clock = DateTime(2026, 5, 20, 9, 30);
      await n.replace(_board(['n01']));
      expect(n.state.updatedAt, clock);
      expect(notifier('kid').state.updatedAt, clock);
    });

    test('the stored board is always normalized', () async {
      final n = notifier('kid');
      await n.replace(_board(
        ['n01', 'n01', 'n02'],
        custom: [_custom('c_orphan', 'Deleted')],
        name: '   ',
      ));

      final reloaded = notifier('kid').state;
      expect(reloaded.tileIds, ['n01', 'n02'], reason: 'duplicates dropped');
      expect(reloaded.customTiles, isEmpty, reason: 'orphan pruned');
      expect(reloaded.name, CustomBoard.defaultName);
    });

    test('the tile cap is enforced on the way to disk', () async {
      final ids = [for (var i = 0; i < kMaxCustomBoardTiles + 5; i++) 'c_$i'];
      final n = notifier('kid');
      await n.replace(_board(
        ids,
        custom: [for (final id in ids) _custom(id, id)],
      ));
      expect(notifier('kid').state.tileIds.length, kMaxCustomBoardTiles);
      expect(notifier('kid').state.customTiles.length, kMaxCustomBoardTiles);
    });

    test('editing a tile in place keeps its id, so phrases still resolve',
        () async {
      final n = notifier('kid');
      await n.replace(_board(
        ['c_ate'],
        custom: [_custom('c_ate', 'Ate Maria')],
      ));
      // The adult corrects the spelling.
      await n.replace(_board(
        ['c_ate'],
        custom: [_custom('c_ate', 'Ate Marya')],
      ));

      final reloaded = notifier('kid').state;
      expect(reloaded.customTiles.single.id, 'c_ate');
      expect(reloaded.customTiles.single.label, 'Ate Marya');

      final phrase = SavedPhrase(
        id: 'p',
        tileIds: const ['c_ate'],
        lastUsedAt: DateTime(2026, 4),
      );
      final vocab = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: reloaded,
      );
      expect(phrase.resolve(vocab.byId).single.label, 'Ate Marya');
    });
  });

  group('clearing a board', () {
    test('clear removes the tab and persists', () async {
      final n = notifier('kid');
      await n.replace(_board(['n01', 'c_a'], custom: [_custom('c_a', 'Ate')]));
      expect(notifier('kid').state.isNotEmpty, isTrue);

      await n.clear();
      expect(n.state.isEmpty, isTrue);
      expect(notifier('kid').state.isEmpty, isTrue);
      expect(notifier('kid').state.customTiles, isEmpty);
    });

    test('saving an empty board is the same as clearing', () async {
      // The builder's "Clear All" then Save takes this path.
      final n = notifier('kid');
      await n.replace(_board(['n01']));
      await n.replace(_board(const []));
      expect(notifier('kid').state.isEmpty, isTrue);
    });
  });

  group('deleting a custom tile', () {
    test('stops it resolving inside an old saved phrase', () async {
      // The point of pruning: a word an adult removed must not stay sayable.
      final n = notifier('kid');
      await n.replace(_board(['c_a'], custom: [_custom('c_a', 'Ate Maria')]));

      final phrase = SavedPhrase(
        id: 'p',
        tileIds: const ['g01', 'c_a'],
        lastUsedAt: DateTime(2026, 4),
      );
      var vocab = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: notifier('kid').state,
      );
      expect(phrase.resolve(vocab.byId), hasLength(2));

      await n.replace(_board(const []));
      vocab = BoardVocabulary(
        presentation: BoardPresentation.forType(DisabilityType.none),
        customBoard: notifier('kid').state,
      );
      expect(phrase.resolve(vocab.byId).map((t) => t.id), ['g01']);
    });
  });

  group('custom tiles and saved phrases share one store', () {
    test('both survive together under the same profile', () async {
      // They live in the same Hive box under sibling keys; a write to one must
      // not clobber the other.
      final tiles = notifier('kid');
      await tiles.replace(_board(['c_a'], custom: [_custom('c_a', 'Ate')]));

      final phrases = BoardPhrasesNotifier(HiveBoardPhraseStore('kid'))
        ..now = () => clock;
      final custom = notifier('kid').state.resolvedTiles;
      await phrases.record(custom + custom);

      expect(notifier('kid').state.isNotEmpty, isTrue);
      expect(BoardPhrasesNotifier(HiveBoardPhraseStore('kid')).state,
          hasLength(1));
    });
  });

  group('reading damaged storage', () {
    test('a non-map value reads as no board rather than throwing', () async {
      await box.put('talk_board_custom_kid', 'garbage');
      expect(notifier('kid').state.isEmpty, isTrue);
    });

    test('a partly corrupt board keeps what parsed', () async {
      await box.put('talk_board_custom_kid', {
        'name': 'My Board',
        'tileIds': ['n01', 'c_bad', 'c_ok'],
        'customTiles': [
          {'id': 'c_bad'}, // no label / emoji
          _custom('c_ok', 'Ate Maria').toJson(),
        ],
        'updatedAt': DateTime(2026, 4).toIso8601String(),
      });

      final state = notifier('kid').state;
      expect(state.customTiles, hasLength(1));
      expect(state.resolvedTiles.map((t) => t.id), ['n01', 'c_ok']);
    });

    test('a board of nothing but dead ids reads as empty', () async {
      await box.put('talk_board_custom_kid', {
        'name': 'Ghost',
        'tileIds': ['c_gone', 'retired-seed'],
        'customTiles': const [],
        'updatedAt': DateTime(2026, 4).toIso8601String(),
      });
      // Talk Board must not offer a tab with nothing behind it.
      expect(notifier('kid').state.isEmpty, isTrue);
    });

    test('an unknown category name degrades to custom, not a crash', () async {
      await box.put('talk_board_custom_kid', {
        'name': 'My Board',
        'tileIds': ['c_x'],
        'customTiles': [
          {
            'id': 'c_x',
            'label': 'Ate',
            'labelFil': 'Ate',
            'emoji': '👩',
            'category': 'a-category-from-the-future',
          }
        ],
        'updatedAt': DateTime(2026, 4).toIso8601String(),
      });
      final tile = notifier('kid').state.customTiles.single;
      expect(tile.category, BoardTileCategory.custom);
      expect(tile.isCustom, isTrue);
    });
  });
}
