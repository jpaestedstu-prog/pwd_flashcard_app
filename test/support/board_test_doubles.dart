import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/communication_board/models/custom_board.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';
import 'package:pwdpwdpwd/features/communication_board/providers/board_phrases_provider.dart';
import 'package:pwdpwdpwd/features/communication_board/providers/custom_board_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// An in-memory [BoardPhraseStore] for `testWidgets`.
///
/// Talk Board writes a phrase every time a sentence is spoken. A
/// fire-and-forget `box.put` started inside the fake-async zone never drains,
/// and Hive serialises writes per box — so one such write hangs `tearDownAll`
/// *and* poisons every later awaited box operation in the same file. Widget
/// tests therefore keep persistence out entirely and assert against this;
/// the real Hive round-trip is covered by plain `test()` cases in
/// `test/board_phrases_test.dart`.
class FakeBoardPhraseStore implements BoardPhraseStore {
  FakeBoardPhraseStore([List<SavedPhrase> seed = const []])
      : _phrases = List.of(seed);

  List<SavedPhrase> _phrases;

  /// Number of saves performed — lets a test assert that a phrase was
  /// persisted, not merely held in provider state.
  int saveCount = 0;

  @override
  List<SavedPhrase> load() => List.of(_phrases);

  @override
  Future<void> save(List<SavedPhrase> phrases) async {
    _phrases = List.of(phrases);
    saveCount++;
  }
}

/// Overrides [boardPhrasesProvider] with an in-memory notifier.
///
/// [now] pins the clock so recency ordering is deterministic instead of
/// racing the real one.
Override overrideBoardPhrases(
  FakeBoardPhraseStore store, {
  DateTime Function()? now,
}) {
  return boardPhrasesProvider.overrideWith((ref) {
    final notifier = BoardPhrasesNotifier(store);
    if (now != null) notifier.now = now;
    return notifier;
  });
}

/// An in-memory [CustomBoardStore] for `testWidgets`, for the same reason
/// [FakeBoardPhraseStore] exists: the builder's Save is a `box.put`, and one
/// started inside the fake-async zone poisons the box's write queue for every
/// later case in the file. The real Hive round-trip is covered by plain
/// `test()` cases in `test/custom_board_test.dart`.
class FakeCustomBoardStore implements CustomBoardStore {
  FakeCustomBoardStore([CustomBoard? seed]) : _board = seed ?? CustomBoard.empty();

  CustomBoard _board;

  /// Number of saves performed — lets a test assert the builder persisted,
  /// not merely re-rendered.
  int saveCount = 0;

  @override
  CustomBoard load() => _board;

  @override
  Future<void> save(CustomBoard board) async {
    _board = board.normalized;
    saveCount++;
  }
}

/// Overrides [customBoardProvider] with an in-memory notifier.
Override overrideCustomBoard(
  FakeCustomBoardStore store, {
  DateTime Function()? now,
}) {
  return customBoardProvider.overrideWith((ref) {
    final notifier = CustomBoardNotifier(store);
    if (now != null) notifier.now = now;
    return notifier;
  });
}

/// A board holding one seed tile and one authored tile — the mixed case that
/// most of the interesting behaviour hangs off.
CustomBoard sampleCustomBoard({
  String name = 'My Board',
  DateTime? at,
}) {
  return CustomBoard(
    name: name,
    tileIds: const ['n01', 'c_ate'],
    customTiles: [
      buildCustomTile(label: 'Ate Maria', labelFil: 'Ate Maria', emoji: '👩',
          id: 'c_ate'),
    ],
    updatedAt: at ?? DateTime(2026, 4),
  );
}

/// Stubs [profileProvider] with a fixed learner, without dragging in
/// `ProfileNotifier.build`'s Firebase remote-changes stream.
class StubBoardProfileNotifier extends ProfileNotifier {
  StubBoardProfileNotifier({
    required this.role,
    required this.disability,
  });

  final UserRole role;
  final DisabilityType disability;

  @override
  UserProfile? build() => UserProfile(
        id: 'board-test-profile',
        name: 'Board Tester',
        role: role,
        disabilityType: disability,
        createdAt: DateTime(2026),
      );
}

/// Override list for a learner of [disability] in [role].
List<Override> boardProfileOverrides({
  UserRole role = UserRole.student,
  DisabilityType disability = DisabilityType.none,
}) =>
    [
      profileProvider.overrideWith(
        () => StubBoardProfileNotifier(role: role, disability: disability),
      ),
    ];
