import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../providers/app_providers.dart';
import '../models/board_models.dart';
import '../models/board_presentation.dart';
import '../models/board_vocabulary.dart';
import '../models/custom_board.dart';

/// Where a learner's own board lives.
///
/// An interface for the same reason [BoardPhraseStore] is one: a
/// fire-and-forget `box.put` started inside a `testWidgets` fake-async zone
/// never drains and poisons the box's write queue for the rest of the file.
/// Widget tests use the in-memory double in `test/support/board_test_doubles.dart`.
abstract class CustomBoardStore {
  CustomBoard load();
  Future<void> save(CustomBoard board);
}

/// The production store: the shared `progress` box, keyed per profile, in the
/// same shape as the phrases, notebook and goals features.
class HiveCustomBoardStore implements CustomBoardStore {
  HiveCustomBoardStore(this.profileId);

  final String profileId;

  static Box get _box => Hive.box('progress');

  String get _key => 'talk_board_custom_$profileId';

  @override
  CustomBoard load() {
    final raw = _box.get(_key);
    if (raw is! Map) return CustomBoard.empty();
    try {
      return CustomBoard.fromJson(Map<String, dynamic>.from(raw)).normalized;
    } catch (_) {
      // A board that will not parse reads as "no board yet" rather than
      // taking Talk Board down with it — the seed tabs still work, which is
      // the difference between a degraded board and no voice at all.
      return CustomBoard.empty();
    }
  }

  @override
  Future<void> save(CustomBoard board) =>
      _box.put(_key, board.normalized.toJson());
}

/// The signed-in profile's own Talk Board tab.
///
/// Always holds a [CustomBoard.normalized] value, so no consumer has to think
/// about duplicate ids, orphaned custom tiles or an over-long board.
class CustomBoardNotifier extends StateNotifier<CustomBoard> {
  CustomBoardNotifier(this._store) : super(CustomBoard.empty()) {
    state = _store.load().normalized;
  }

  final CustomBoardStore _store;

  /// Clock seam so tests can pin "now" instead of racing the real one.
  DateTime Function() now = DateTime.now;

  /// Replace the whole board — what the builder's Save button does.
  ///
  /// One atomic write rather than a stream of add/remove calls: the builder
  /// edits a working copy and commits it, so a learner's live board never
  /// passes through a half-edited state.
  Future<void> replace(CustomBoard board) async {
    state = board.copyWith(updatedAt: now()).normalized;
    await _store.save(state);
  }

  /// Throw the board away. The tab disappears from Talk Board.
  Future<void> clear() async {
    state = CustomBoard.empty(at: now());
    await _store.save(state);
  }
}

/// The signed-in profile's custom board.
final customBoardProvider =
    StateNotifierProvider<CustomBoardNotifier, CustomBoard>((ref) {
  final profile = ref.watch(profileProvider);
  return CustomBoardNotifier(HiveCustomBoardStore(profile?.id ?? 'default'));
});

/// Everything the signed-in learner can say, and the tab order that holds it.
///
/// This — not [boardPresentationProvider] — is what the board screen should
/// read: it is the only place that knows the custom tab exists.
final boardVocabularyProvider = Provider<BoardVocabulary>((ref) {
  return BoardVocabulary(
    presentation: ref.watch(boardPresentationProvider),
    customBoard: ref.watch(customBoardProvider),
  );
});

/// Resolves a tile id through the signed-in learner's full vocabulary.
///
/// Exposed on its own because saved phrases need it outside a widget build.
BoardTile? Function(String) boardTileLookupOf(Ref ref) =>
    ref.read(boardVocabularyProvider).byId;
