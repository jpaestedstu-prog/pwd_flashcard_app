import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import 'accessibility_content_policy.dart';

/// Which games a learner's Games tab offers, and how that set is presented.
///
/// Two different shapes, decided by the active profile's role:
///
///   • **Student / Child** — learner roles that self-classify into one of the
///     six accessibility categories. Their hub shows a single headed section
///     named after *their* category holding a curated roster of exactly
///     [gamesPerCategory] games. A Visual-Impairment student and a
///     Hearing-Impairment student therefore see visibly different, clearly
///     labelled game sets.
///
///   • **Player (guest or with progress), and every non-learner role** — no
///     accessibility category to curate against, so they get every game in one
///     combined list with no category heading.
///
/// The per-category rosters are curated, not merely filtered: categories with
/// more than ten suitable games get the ten that best cover the app's learning
/// modalities. Selection rationale per category is documented on [_visual]
/// through [_none].
///
/// The rosters never contradict [AccessibilityContentPolicy] — the policy still
/// owns FSL / audio-game visibility across the *rest* of the app (the Cards FSL
/// button, Stories' "Watch in FSL", the FSL dictionary), and
/// `game_catalog_test` asserts the two stay in agreement.
class GameCatalog {
  GameCatalog._();

  /// Every accessibility category offers exactly this many games.
  static const int gamesPerCategory = 10;

  /// Games that never appear in the hub regardless of profile: Story Quiz is
  /// reached from the Stories tab, where it has its story picker.
  static const Set<GameType> _hubExcluded = {GameType.storyQuiz};

  // ─── Visual Impairment ────────────────────────────────
  // Audio / TTS carries the prompt. Out: FSL Practice (signs are visual),
  // Jigsaw Puzzle and Drag & Drop (precise visual placement), Picture-Word
  // (the prompt *is* an image, with no text to narrate).
  static const List<GameType> _visual = [
    GameType.pronunciation,
    GameType.wordMatch,
    GameType.spellingBee,
    GameType.memoryMatch,
    GameType.sentenceBuilder,
    GameType.flashcardQuiz,
    GameType.tracing,
    GameType.yesOrNo,
    GameType.oddOneOut,
    GameType.firstLetter,
  ];

  // ─── Hearing Impairment ───────────────────────────────
  // FSL leads; nothing depends on hearing. Out: Pronunciation (audio-only) and
  // the three low-barrier games, which lower an input barrier these learners
  // don't have.
  static const List<GameType> _hearing = [
    GameType.fslPractice,
    GameType.wordMatch,
    GameType.spellingBee,
    GameType.memoryMatch,
    GameType.dragAndDrop,
    GameType.flashcardQuiz,
    GameType.sentenceBuilder,
    GameType.tracing,
    GameType.jigsawPuzzle,
    GameType.pictureWord,
  ];

  // ─── Motor Impairment ─────────────────────────────────
  // Single taps on large targets only. Out: Drag & Drop, Tracing and Jigsaw
  // Puzzle (sustained drag / fine stroke control), Flashcard Quiz (swipe is
  // its primary gesture; its buttons are the fallback, not the design).
  static const List<GameType> _motor = [
    GameType.yesOrNo,
    GameType.wordMatch,
    GameType.oddOneOut,
    GameType.firstLetter,
    GameType.memoryMatch,
    GameType.spellingBee,
    GameType.pronunciation,
    GameType.pictureWord,
    GameType.sentenceBuilder,
    GameType.fslPractice,
  ];

  // ─── Cognitive / Learning Disability ──────────────────
  // Concrete and pictorial, low reading and low metacognitive load. Out: FSL
  // Practice (unrelated signing can confuse — the standing policy call),
  // Spelling Bee and Sentence Builder (highest literacy load), Flashcard Quiz
  // (self-rating "do I know this?" is the hardest judgement to make here).
  static const List<GameType> _cognitive = [
    GameType.wordMatch,
    GameType.yesOrNo,
    GameType.pictureWord,
    GameType.oddOneOut,
    GameType.firstLetter,
    GameType.memoryMatch,
    GameType.jigsawPuzzle,
    GameType.dragAndDrop,
    GameType.tracing,
    GameType.pronunciation,
  ];

  // ─── Multiple Disabilities ────────────────────────────
  // The motor input limits *and* every alternative modality kept available
  // (both FSL and audio), led by the lowest-barrier games. Out: Drag & Drop,
  // Tracing, Jigsaw Puzzle (motor), Spelling Bee (heaviest literacy load).
  static const List<GameType> _multiple = [
    GameType.yesOrNo,
    GameType.wordMatch,
    GameType.oddOneOut,
    GameType.firstLetter,
    GameType.pictureWord,
    GameType.memoryMatch,
    GameType.pronunciation,
    GameType.flashcardQuiz,
    GameType.sentenceBuilder,
    GameType.fslPractice,
  ];

  // ─── No Accessibility Needs ───────────────────────────
  // The full classic roster. Out: Picture-Word, which for a learner with no
  // perception constraint is Word Match with the prompt and answer swapped,
  // and the three low-barrier games (yesOrNo, oddOneOut, firstLetter), which
  // are aimed at the categories that need them.
  static const List<GameType> _none = [
    GameType.wordMatch,
    GameType.spellingBee,
    GameType.memoryMatch,
    GameType.dragAndDrop,
    GameType.flashcardQuiz,
    GameType.pronunciation,
    GameType.sentenceBuilder,
    GameType.tracing,
    GameType.jigsawPuzzle,
    GameType.fslPractice,
  ];

  /// The curated roster for [type] — always [gamesPerCategory] games.
  static List<GameType> forCategory(DisabilityType type) => switch (type) {
    DisabilityType.visual => _visual,
    DisabilityType.hearing => _hearing,
    DisabilityType.motor => _motor,
    DisabilityType.cognitive => _cognitive,
    DisabilityType.multiple => _multiple,
    DisabilityType.none => _none,
  };

  /// Every hub game in one list, in enum order — what Player profiles and
  /// non-learner roles see.
  static List<GameType> get combined =>
      GameType.values.where((g) => !_hubExcluded.contains(g)).toList();

  /// Whether [role] gets a category-headed roster rather than [combined].
  /// Student and Child are the roles that carry an accessibility category.
  static bool isCategorised(UserRole? role) =>
      role == UserRole.student || role == UserRole.child;
}

/// What the Games hub should render for the active profile.
class GameHubCatalog {
  /// The games to show, in display order.
  final List<GameType> games;

  /// The accessibility category heading the list, or `null` when the games are
  /// shown as one combined list (Player profiles and non-learner roles).
  final DisabilityType? category;

  const GameHubCatalog({required this.games, required this.category});

  bool get isCategorised => category != null;
}

/// Games hub contents for the active profile.
///
/// Student / Child → their accessibility category's roster of ten, under that
/// category's heading. Everyone else (Player guest, Player with progress,
/// educators previewing, no profile) → every game, uncategorised.
final gameHubCatalogProvider = Provider<GameHubCatalog>((ref) {
  final profile = ref.watch(profileProvider);
  if (!GameCatalog.isCategorised(profile?.role)) {
    return GameHubCatalog(games: GameCatalog.combined, category: null);
  }
  final type = profile!.disabilityType;
  return GameHubCatalog(games: GameCatalog.forCategory(type), category: type);
});
