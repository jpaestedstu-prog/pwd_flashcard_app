import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../providers/app_providers.dart';
import '../models/board_models.dart';
import '../models/saved_phrase.dart';

/// Where a learner's Talk Board phrases live.
///
/// An interface rather than a direct Hive call so widget tests can hold the
/// phrase list in memory. A fire-and-forget `box.put` started inside a
/// `testWidgets` fake-async zone never drains, and Hive serialises writes per
/// box — so one write poisons every later awaited box operation in the same
/// test file. See `test/support/board_test_doubles.dart`.
abstract class BoardPhraseStore {
  List<SavedPhrase> load();
  Future<void> save(List<SavedPhrase> phrases);
}

/// The production store: the shared `progress` box, keyed per profile, in the
/// same shape as the notebook and goals features.
class HiveBoardPhraseStore implements BoardPhraseStore {
  HiveBoardPhraseStore(this.profileId);

  final String profileId;

  static Box get _box => Hive.box('progress');

  String get _key => 'talk_board_phrases_$profileId';

  @override
  List<SavedPhrase> load() {
    final raw = _box.get(_key);
    if (raw is! List) return [];
    final out = <SavedPhrase>[];
    for (final e in raw) {
      try {
        out.add(SavedPhrase.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        // One corrupt row must not cost the learner the other nine.
        continue;
      }
    }
    return out;
  }

  @override
  Future<void> save(List<SavedPhrase> phrases) =>
      _box.put(_key, phrases.map((p) => p.toJson()).toList());
}

/// A learner's saved and recent Talk Board phrases, most useful first.
///
/// The list is always ordered and capped by [orderAndCapPhrases], so the UI
/// can render it straight through and the eviction rule lives in exactly one
/// pure, tested place.
class BoardPhrasesNotifier extends StateNotifier<List<SavedPhrase>> {
  BoardPhrasesNotifier(this._store) : super(const []) {
    state = orderAndCapPhrases(_store.load());
  }

  final BoardPhraseStore _store;

  /// Clock seam so tests can pin "now" instead of racing the real one.
  DateTime Function() now = DateTime.now;

  /// Record that [tiles] were just spoken.
  ///
  /// Upserts on the phrase's tile-id identity: saying the same sentence again
  /// bumps its recency and use count rather than adding a duplicate chip.
  ///
  /// A *new* single-tile sentence is not recorded — the tile itself is already
  /// one tap away on the grid, and recording them would flush the strip of
  /// real phrases within a minute of play. One the learner has deliberately
  /// saved via [savePinned] still counts as used, though.
  Future<void> record(List<BoardTile> tiles) async {
    if (tiles.isEmpty) return;
    final id = SavedPhrase.idFor(tiles);
    final existing = state.where((p) => p.id == id).firstOrNull;
    if (existing == null && tiles.length < 2) return;

    final at = now();
    final next = [
      for (final p in state)
        if (p.id != id) p,
      existing?.copyWith(lastUsedAt: at, useCount: existing.useCount + 1) ??
          SavedPhrase.fromTiles(tiles, now: at),
    ];
    await _commit(next);
  }

  /// Save [tiles] as a pinned phrase, creating it if it is new.
  ///
  /// Deliberately separate from [record] so the two-tile floor that keeps
  /// single words out of the automatic recents does not apply here: pinning is
  /// an explicit act, and "Bathroom" on its own is exactly the kind of
  /// one-word phrase a learner most wants one tap away.
  Future<void> savePinned(List<BoardTile> tiles) async {
    if (tiles.isEmpty) return;
    final id = SavedPhrase.idFor(tiles);
    final at = now();
    final existing = state.where((p) => p.id == id).firstOrNull;

    await _commit([
      for (final p in state)
        if (p.id != id) p,
      existing?.copyWith(lastUsedAt: at, pinned: true) ??
          SavedPhrase.fromTiles(tiles, now: at, pinned: true),
    ]);
  }

  /// Pin or unpin [id]. Pinning also refreshes recency so a newly pinned
  /// phrase appears at the front of the pinned run rather than buried in it.
  Future<void> togglePinned(String id) async {
    final at = now();
    await _commit([
      for (final p in state)
        if (p.id == id)
          p.copyWith(pinned: !p.pinned, lastUsedAt: at)
        else
          p,
    ]);
  }

  Future<void> remove(String id) async {
    await _commit([
      for (final p in state)
        if (p.id != id) p,
    ]);
  }

  Future<void> _commit(List<SavedPhrase> next) async {
    state = orderAndCapPhrases(next);
    await _store.save(state);
  }
}

/// Saved + recent phrases for the signed-in profile.
///
/// Overridden wholesale in widget tests with an in-memory store; see
/// [BoardPhraseStore].
final boardPhrasesProvider =
    StateNotifierProvider<BoardPhrasesNotifier, List<SavedPhrase>>((ref) {
  final profile = ref.watch(profileProvider);
  return BoardPhrasesNotifier(HiveBoardPhraseStore(profile?.id ?? 'default'));
});
