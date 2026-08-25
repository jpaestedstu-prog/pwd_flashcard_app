import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/board_seed_data.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';
import 'package:pwdpwdpwd/features/communication_board/providers/board_phrases_provider.dart';

/// Talk Board phrase persistence against **real Hive**.
///
/// Deliberately plain `test()` cases in their own file: mixing `testWidgets`
/// with awaited `box.put` in one file poisons the box's write queue for every
/// later case. Widget-level behaviour lives in
/// `test/communication_board_screen_test.dart` with an in-memory store.

BoardTile _tile(String id) => BoardSeedData.byId(id)!;

List<BoardTile> _tiles(List<String> ids) => ids.map(_tile).toList();

void main() {
  late Box box;
  var clock = DateTime(2026, 3);

  setUpAll(() async {
    Hive.init('./build/test_cache/board_phrases');
    // Compaction renames the box file mid-write on Windows and throws
    // PathAccessException; this suite does hundreds of puts.
    box = await Hive.openBox(
      'progress',
      compactionStrategy: (total, deleted) => false,
    );
  });

  setUp(() async {
    await box.clear().timeout(const Duration(seconds: 5));
    clock = DateTime(2026, 3);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  BoardPhrasesNotifier notifier(String profileId) {
    final n = BoardPhrasesNotifier(HiveBoardPhraseStore(profileId));
    n.now = () => clock;
    return n;
  }

  void tick([int minutes = 1]) {
    clock = clock.add(Duration(minutes: minutes));
  }

  group('recording a spoken sentence', () {
    test('a fresh learner starts with nothing', () {
      expect(notifier('fresh').state, isEmpty);
    });

    test('a spoken sentence survives a rebuild of the notifier', () async {
      final a = notifier('kid');
      await a.record(_tiles(['n01', 'p01']));
      expect(a.state, hasLength(1));

      // A new notifier is what the learner gets after navigating away and
      // back — the whole point of the feature.
      final b = notifier('kid');
      expect(b.state, hasLength(1));
      expect(b.state.single.tileIds, ['n01', 'p01']);
      expect(b.state.single.resolve(BoardSeedData.byId).map((t) => t.label),
          ['I need help', 'Teacher']);
    });

    test('phrases are per profile', () async {
      await notifier('kid-a').record(_tiles(['n01', 'p01']));
      expect(notifier('kid-b').state, isEmpty);
      expect(notifier('kid-a').state, hasLength(1));
    });

    test('saying the same sentence again bumps it instead of duplicating',
        () async {
      final n = notifier('kid');
      await n.record(_tiles(['n01', 'p01']));
      tick();
      await n.record(_tiles(['n01', 'p01']));

      expect(n.state, hasLength(1));
      expect(n.state.single.useCount, 2);
      expect(n.state.single.lastUsedAt, clock);
    });

    test('the same words in a different order are a different phrase',
        () async {
      final n = notifier('kid');
      await n.record(_tiles(['n01', 'p01']));
      await n.record(_tiles(['p01', 'n01']));
      expect(n.state, hasLength(2));
    });

    test('a one-tile sentence is not recorded', () async {
      // It is already one tap away on the grid; recording them would flush the
      // strip of real phrases within a minute of play.
      final n = notifier('kid');
      await n.record(_tiles(['n01']));
      expect(n.state, isEmpty);
      await n.record(const []);
      expect(n.state, isEmpty);
    });

    test('the most recent sentence leads the list', () async {
      final n = notifier('kid');
      await n.record(_tiles(['n01', 'p01']));
      tick();
      await n.record(_tiles(['f01', 'r01']));
      expect(n.state.first.tileIds, ['f01', 'r01']);
    });
  });

  group('pinning', () {
    test('a pinned phrase outranks a newer recent one', () async {
      final n = notifier('kid');
      await n.record(_tiles(['n01', 'p01']));
      await n.togglePinned(SavedPhrase.idFor(_tiles(['n01', 'p01'])));
      tick(60);
      await n.record(_tiles(['f01', 'r01']));

      expect(n.state.first.pinned, isTrue);
      expect(n.state.first.tileIds, ['n01', 'p01']);
    });

    test('pinning survives a reload', () async {
      final id = SavedPhrase.idFor(_tiles(['n05', 'r04']));
      final a = notifier('kid');
      await a.record(_tiles(['n05', 'r04']));
      await a.togglePinned(id);

      expect(notifier('kid').state.single.pinned, isTrue);
    });

    test('toggling twice unpins', () async {
      final id = SavedPhrase.idFor(_tiles(['n05', 'r04']));
      final n = notifier('kid');
      await n.record(_tiles(['n05', 'r04']));
      await n.togglePinned(id);
      await n.togglePinned(id);
      expect(n.state.single.pinned, isFalse);
    });

    test('toggling an unknown id changes nothing', () async {
      final n = notifier('kid');
      await n.record(_tiles(['n05', 'r04']));
      await n.togglePinned('not-a-phrase');
      expect(n.state, hasLength(1));
      expect(n.state.single.pinned, isFalse);
    });

    test('savePinned stores a single-tile phrase that record refuses',
        () async {
      // "Bathroom" on its own is exactly the phrase a learner most wants one
      // tap away, and the star used to say "Phrase saved." while saving
      // nothing: it went through record(), which floors at two tiles.
      final n = notifier('kid');
      final one = _tiles(['n05']);
      await n.record(one);
      expect(n.state, isEmpty);

      await n.savePinned(one);
      expect(n.state, hasLength(1));
      expect(n.state.single.pinned, isTrue);
      expect(notifier('kid').state.single.tileIds, ['n05']);
    });

    test('saying a saved one-tile phrase again still counts as use', () async {
      final n = notifier('kid');
      final one = _tiles(['n05']);
      await n.savePinned(one);
      tick();
      await n.record(one);

      expect(n.state, hasLength(1));
      expect(n.state.single.useCount, 2);
      expect(n.state.single.lastUsedAt, clock);
      expect(n.state.single.pinned, isTrue, reason: 'use must not unpin it');
    });

    test('savePinned on an existing recent promotes it without duplicating',
        () async {
      final n = notifier('kid');
      final two = _tiles(['n01', 'p01']);
      await n.record(two);
      expect(n.state.single.pinned, isFalse);

      await n.savePinned(two);
      expect(n.state, hasLength(1));
      expect(n.state.single.pinned, isTrue);
    });

    test('savePinned ignores an empty sentence', () async {
      final n = notifier('kid');
      await n.savePinned(const []);
      expect(n.state, isEmpty);
    });

    test('a pinned phrase is never evicted by the recents cap', () async {
      final n = notifier('kid');
      final keep = _tiles(['n01', 'n02']);
      await n.record(keep);
      await n.togglePinned(SavedPhrase.idFor(keep));

      // Bury it under far more than the cap of newer sentences.
      final pool = BoardSeedData.forCategory(BoardTileCategory.food);
      for (var i = 0; i < kMaxRecentPhrases + 8; i++) {
        tick();
        await n.record([
          pool[i % pool.length],
          pool[(i + 1) % pool.length],
          _tile('r0${(i % 8) + 1}'),
        ]);
      }

      expect(n.state.any((p) => p.pinned), isTrue,
          reason: 'the learner pinned this; the cap must not take it away');
      expect(n.state.where((p) => !p.pinned).length, kMaxRecentPhrases);
      // And it is still there after a reload, not just in memory.
      expect(notifier('kid').state.any((p) => p.pinned), isTrue);
    });
  });

  group('removal', () {
    test('remove drops one phrase and persists the removal', () async {
      final n = notifier('kid');
      await n.record(_tiles(['n01', 'p01']));
      tick();
      await n.record(_tiles(['f01', 'r01']));

      await n.remove(SavedPhrase.idFor(_tiles(['n01', 'p01'])));
      expect(n.state, hasLength(1));
      expect(notifier('kid').state, hasLength(1));
      expect(notifier('kid').state.single.tileIds, ['f01', 'r01']);
    });

    test('removing an unknown id is a no-op', () async {
      final n = notifier('kid');
      await n.record(_tiles(['n01', 'p01']));
      await n.remove('nope');
      expect(n.state, hasLength(1));
    });
  });

  group('reading damaged storage', () {
    test('a corrupt row does not cost the learner the others', () async {
      final good = SavedPhrase(
        id: 'n01+p01',
        tileIds: const ['n01', 'p01'],
        lastUsedAt: DateTime(2026, 3),
      );
      await box.put('talk_board_phrases_kid', [
        good.toJson(),
        {'id': 'broken'}, // no tileIds / lastUsedAt
        'not even a map',
      ]);

      final n = notifier('kid');
      expect(n.state, hasLength(1));
      expect(n.state.single.id, 'n01+p01');
    });

    test('a non-list value reads as empty rather than throwing', () async {
      await box.put('talk_board_phrases_kid', 'garbage');
      expect(notifier('kid').state, isEmpty);
    });

    test('a phrase of retired tile ids stays readable but resolves empty',
        () async {
      await box.put('talk_board_phrases_kid', [
        {
          'id': 'gone',
          'tileIds': ['retired-a', 'retired-b'],
          'lastUsedAt': DateTime(2026, 3).toIso8601String(),
          'useCount': 3,
          'pinned': true,
        }
      ]);
      final n = notifier('kid');
      expect(n.state, hasLength(1));
      // The UI drops it on the strip; the store does not have to.
      expect(n.state.single.resolve(BoardSeedData.byId), isEmpty);
    });
  });
}
